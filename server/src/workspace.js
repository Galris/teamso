import { z } from 'zod';
import { FieldValue } from 'firebase-admin/firestore';

const fail = (status, message) => Object.assign(new Error(message), { status, code: 'WORKSPACE_ERROR' });
const text = z.string().trim().min(1).max(200);
const isHttpUrl = value => {
  try { const u = new URL(value); return ['http:', 'https:'].includes(u.protocol) && !!u.hostname && !u.username && !u.password; }
  catch { return false; }
};
const url = z.string().trim().max(2048).refine(value => !value || isHttpUrl(value), 'Đường dẫn phải là URL http:// hoặc https:// hợp lệ.');
// Cuộc họp mới luôn cần link vào phòng (Meet/Zoom/Teams); dữ liệu cũ không có vẫn đọc bình thường.
const requiredUrl = z.string({ error: 'Vui lòng nhập link vào cuộc họp.' }).trim().min(1, 'Vui lòng nhập link vào cuộc họp.').max(2048).refine(isHttpUrl, 'Link họp phải là URL http:// hoặc https:// hợp lệ.');
const questionText = z.string().trim().min(1, 'Vui lòng nhập nội dung bình chọn.').max(500);
const optionText = z.string().trim().min(1, 'Phương án không được để trống.').max(120);
// deadline: thiếu = không dùng/không đổi, null = bỏ hạn đã đặt.
const deadlineText = z.iso.datetime({ offset: true }).nullable().optional();
export const documentSchema = z.object({ label: text, url: url.default('') }).strict();
export const meetingSchema = z.object({ label: text, startsAt: z.iso.datetime({ offset: true }), endsAt: z.iso.datetime({ offset: true }), meetUrl: requiredUrl }).strict()
  .refine(v => Date.parse(v.endsAt) > Date.parse(v.startsAt), 'Giờ kết thúc phải sau giờ bắt đầu.')
  .refine(v => Date.parse(v.startsAt) > Date.now(), 'Vui lòng chọn giờ họp trong tương lai.');
export const voteSchema = z.object({
  question: questionText,
  kind: z.enum(['general', 'meeting'], { error: 'Loại bình chọn không hợp lệ.' }).default('general'),
  options: z.array(optionText).min(2, 'Cần ít nhất hai phương án.'),
  multiple: z.boolean().default(false),
  anonymous: z.boolean().default(false),
  deadline: deadlineText,
}).strict()
  .refine(v => new Set(v.options.map(x => x.toLocaleLowerCase('vi'))).size === v.options.length, 'Các phương án không được trùng nhau.')
  .refine(v => v.kind === 'meeting' || v.options.length <= 20, 'Bình chọn thường có tối đa 20 phương án.')
  .refine(v => v.kind !== 'meeting' || v.options.length <= 60, 'Bình chọn lịch họp có tối đa 60 khung giờ.');
// body PATCH sửa bình chọn: mọi trường đều tùy chọn, kiểm tra rỗng/ánh xạ ở route.
export const voteUpdateSchema = z.object({
  question: questionText.optional(),
  options: z.array(optionText).min(2, 'Cần ít nhất hai phương án.').optional(),
  indexMap: z.array(z.number().int().min(0).nullable()).optional(),
  deadline: deadlineText,
}).strict();
const ballotSchema = z.object({ options: z.array(z.number().int().min(0)).max(60, 'Quá nhiều lựa chọn.') }).strict();
// Giá trị lưu ở Firestore là Timestamp, đơn vị test dùng Date nên phải đọc được cả hai.
const timeOf = value => value instanceof Date ? value.getTime()
  : typeof value?.toDate === 'function' ? value.toDate().getTime()
  : Number.NaN;
const isExpired = value => {
  const ms = timeOf(value);
  return Number.isFinite(ms) && ms <= Date.now();
};
const parse = (schema, value) => {
  const result = schema.safeParse(value);
  if (!result.success) throw fail(400, result.error.issues[0]?.message ?? 'Dữ liệu Workspace không hợp lệ.');
  return result.data;
};
const id = value => {
  if (typeof value !== 'string' || !value || value.includes('/') || value.length > 1500) throw fail(400, 'Mã dữ liệu không hợp lệ.');
  return value;
};

// All writes use Admin SDK after identity, membership and schema validation.
// Readers continue to subscribe to Firestore for realtime updates.
export function registerWorkspace(app, { db, protectedRoute, notifications }) {
  async function access(tx, projectId, uid) {
    const project = db.collection('projects').doc(id(projectId));
    const [p, m] = await Promise.all([tx.get(project), tx.get(project.collection('members').doc(uid))]);
    if (!p.exists) throw fail(404, 'Không tìm thấy dự án.');
    const data = p.data();
    const leader = data.ownerId === uid || m.data()?.role === 'leader';
    if (!leader && !m.exists && !(Array.isArray(data.memberIds) && data.memberIds.includes(uid))) throw fail(403, 'Bạn không phải thành viên dự án.');
    return { project, leader };
  }
  const base = '/api/projects/:projectId/workspace';
  for (const [collection, schema] of [['documents', documentSchema], ['meetings', meetingSchema], ['votes', voteSchema]]) {
    app.post(`${base}/${collection}`, protectedRoute, async (req, res) => {
      const data = parse(schema, req.body);
      const ref = db.collection('projects').doc(id(req.params.projectId)).collection(collection).doc();
      const jobs = await db.runTransaction(async tx => {
        const {project} = await access(tx, req.params.projectId, req.uid);
        const members = await tx.get(project.collection('members'));
        const projectData = (await tx.get(project)).data();
        const recipients = [...new Set([...(members?.docs.map(d => d.id) ?? []), ...(projectData.memberIds ?? []), projectData.ownerId])].filter(uid => uid && uid !== req.uid);
        tx.create(ref, { ...data,
          ...(collection === 'meetings' ? { startsAt: new Date(data.startsAt), endsAt: new Date(data.endsAt) } : {}),
          ...(collection === 'votes' ? { deadline: data.deadline ? new Date(data.deadline) : null } : {}),
          createdBy: req.uid, createdAt: FieldValue.serverTimestamp() });
        return !notifications ? [] : notifications.stage(tx, recipients, {
          type: {documents:'document', meetings:'meeting', votes:'vote'}[collection],
          title: {documents:'Tài liệu mới', meetings:'Lịch họp mới', votes:'Bình chọn mới'}[collection],
          projectName: projectData.name || 'Dự án', body: data.question ?? data.label, projectId: req.params.projectId, targetId: ref.id,
        });
      });
      if (notifications) await notifications.deliver(jobs);
      res.status(201).json({ id: ref.id });
    });
    app.delete(`${base}/${collection}/:id`, protectedRoute, async (req, res) => {
      const ref = db.collection('projects').doc(id(req.params.projectId)).collection(collection).doc(id(req.params.id));
      await db.runTransaction(async tx => {
        const { leader } = await access(tx, req.params.projectId, req.uid);
        const row = await tx.get(ref);
        if (!row.exists) throw fail(404, 'Mục này đã bị xóa.');
        if (!leader && row.data().createdBy !== req.uid) throw fail(403, 'Chỉ người tạo hoặc leader mới được xóa mục này.');
        // Tombstone serializes concurrent voting/deletion; retries can resume cleanup.
        if (collection === 'votes') tx.update(ref, { deleting: true });
        else tx.delete(ref);
      });
      if (collection === 'votes') await db.recursiveDelete(ref);
      res.json({ message: 'Đã xóa.' });
    });
  }
  // Append only: existing ballot indices remain stable, including concurrent requests.
  app.post(`${base}/votes/:id/options`, protectedRoute, async (req, res) => {
    const data = parse(z.object({ option: z.string().trim().min(1).max(120) }).strict(), req.body);
    const ref = db.collection('projects').doc(id(req.params.projectId)).collection('votes').doc(id(req.params.id));
    await db.runTransaction(async tx => {
      await access(tx, req.params.projectId, req.uid);
      const vote = await tx.get(ref);
      if (!vote.exists || vote.data().deleting) throw fail(404, 'Bình chọn đã bị xóa.');
      const options = vote.data().options ?? [];
      if (options.length >= 20) throw fail(400, 'Mỗi bình chọn tối đa 20 đáp án.');
      if (options.some(x => x.toLocaleLowerCase('vi') === data.option.toLocaleLowerCase('vi'))) throw fail(400, 'Đáp án này đã tồn tại.');
      tx.update(ref, { options: [...options, data.option], updatedAt: FieldValue.serverTimestamp() });
    });
    res.status(201).json({ message: 'Đã thêm đáp án.' });
  });
  app.put(`${base}/votes/:id/ballot`, protectedRoute, async (req, res) => {
    const data = parse(ballotSchema, req.body);
    const ref = db.collection('projects').doc(id(req.params.projectId)).collection('votes').doc(id(req.params.id));
    await db.runTransaction(async tx => {
      await access(tx, req.params.projectId, req.uid);
      const vote = await tx.get(ref);
      if (!vote.exists || vote.data().deleting) throw fail(404, 'Bình chọn đã bị xóa.');
      if (isExpired(vote.data().deadline)) throw fail(400, 'Bình chọn đã hết hạn, không nhận thêm phiếu.');
      const choices = [...new Set(data.options)].sort((a, b) => a - b);
      if (choices.some(i => i >= (vote.data().options?.length ?? 0))) throw fail(400, 'Phương án bình chọn không hợp lệ.');
      const ballot = ref.collection('ballots').doc(req.uid);
      if (!choices.length) tx.delete(ballot);
      else tx.set(ballot, { options: choices, updatedAt: FieldValue.serverTimestamp() });
    });
    res.json({ message: 'Đã cập nhật lựa chọn.' });
  });
  // Sửa bình chọn. indexMap[i] = chỉ số cũ của đáp án mới thứ i, null nếu là đáp án mới.
  app.patch(`${base}/votes/:id`, protectedRoute, async (req, res) => {
    const data = parse(voteUpdateSchema, req.body);
    const ref = db.collection('projects').doc(id(req.params.projectId)).collection('votes').doc(id(req.params.id));
    await db.runTransaction(async tx => {
      const { leader } = await access(tx, req.params.projectId, req.uid);
      const current = await tx.get(ref);
      if (!current.exists || current.data().deleting) throw fail(404, 'Bình chọn đã bị xóa.');
      const vote = current.data();
      if (!leader && vote.createdBy !== req.uid) throw fail(403, 'Chỉ người tạo hoặc leader mới được sửa bình chọn này.');
      const oldCount = (vote.options ?? []).length;
      const changes = {};
      if (data.question !== undefined) changes.question = data.question;
      if (data.deadline !== undefined) changes.deadline = data.deadline ? new Date(data.deadline) : null;
      let indexMap;
      if (data.options) {
        if (data.options.length > (vote.kind === 'meeting' ? 60 : 20)) throw fail(400, vote.kind === 'meeting' ? 'Bình chọn lịch họp có tối đa 60 khung giờ.' : 'Bình chọn thường có tối đa 20 phương án.');
        if (new Set(data.options.map(x => x.toLocaleLowerCase('vi'))).size !== data.options.length) throw fail(400, 'Các phương án không được trùng nhau.');
        indexMap = data.indexMap ?? data.options.map((_, i) => i < oldCount ? i : null);
        if (indexMap.length !== data.options.length) throw fail(400, 'Ánh xạ đáp án không khớp số phương án mới.');
        const kept = new Set();
        for (const old of indexMap) {
          if (old === null) continue;
          if (old >= oldCount || kept.has(old)) throw fail(400, 'Ánh xạ đáp án không hợp lệ.');
          kept.add(old);
        }
        changes.options = data.options;
      } else if (data.indexMap) throw fail(400, 'Chỉ gửi ánh xạ khi có danh sách đáp án mới.');
      if (!Object.keys(changes).length) throw fail(400, 'Không có thông tin cần cập nhật.');
      if (indexMap) {
        const oldToNew = new Map();
        indexMap.forEach((old, index) => { if (old !== null) oldToNew.set(old, index); });
        const ballots = await tx.get(ref.collection('ballots'));
        for (const doc of ballots.docs) {
          const row = doc.data();
          const previous = Array.isArray(row?.options) ? row.options : typeof row?.option === 'number' ? [row.option] : [];
          const moved = [...new Set(previous.map(i => oldToNew.get(i)).filter(i => i !== undefined))].sort((a, b) => a - b);
          if (!moved.length) tx.delete(doc.ref);
          else tx.set(doc.ref, { options: moved, updatedAt: FieldValue.serverTimestamp() });
        }
      }
      tx.update(ref, { ...changes, updatedAt: FieldValue.serverTimestamp() });
    });
    res.json({ message: 'Đã cập nhật bình chọn.' });
  });
}
