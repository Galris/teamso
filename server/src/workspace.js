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
export const documentSchema = z.object({ label: text, url: url.default('') }).strict();
export const meetingSchema = z.object({ label: text, startsAt: z.iso.datetime({ offset: true }), endsAt: z.iso.datetime({ offset: true }), meetUrl: requiredUrl }).strict()
  .refine(v => Date.parse(v.endsAt) > Date.parse(v.startsAt), 'Giờ kết thúc phải sau giờ bắt đầu.')
  .refine(v => Date.parse(v.startsAt) > Date.now(), 'Vui lòng chọn giờ họp trong tương lai.');
export const voteSchema = z.object({
  question: z.string().trim().min(1, 'Vui lòng nhập nội dung bình chọn.').max(500),
  kind: z.enum(['general', 'meeting'], { error: 'Loại bình chọn không hợp lệ.' }).default('general'),
  options: z.array(z.string().trim().min(1, 'Phương án không được để trống.').max(120)).min(2, 'Cần ít nhất hai phương án.'),
}).strict()
  .refine(v => new Set(v.options.map(x => x.toLocaleLowerCase('vi'))).size === v.options.length, 'Các phương án không được trùng nhau.')
  .refine(v => v.kind === 'meeting' || v.options.length <= 20, 'Bình chọn thường có tối đa 20 phương án.')
  .refine(v => v.kind !== 'meeting' || v.options.length <= 60, 'Bình chọn lịch họp có tối đa 60 khung giờ.');
const ballotSchema = z.object({ options: z.array(z.number().int().min(0)).max(60, 'Quá nhiều lựa chọn.') }).strict();
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
export function registerWorkspace(app, { db, protectedRoute }) {
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
      await db.runTransaction(async tx => {
        await access(tx, req.params.projectId, req.uid);
        tx.create(ref, { ...data,
          ...(collection === 'meetings' ? { startsAt: new Date(data.startsAt), endsAt: new Date(data.endsAt) } : {}),
          createdBy: req.uid, createdAt: FieldValue.serverTimestamp() });
      });
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
  app.put(`${base}/votes/:id/ballot`, protectedRoute, async (req, res) => {
    const data = parse(ballotSchema, req.body);
    const ref = db.collection('projects').doc(id(req.params.projectId)).collection('votes').doc(id(req.params.id));
    await db.runTransaction(async tx => {
      await access(tx, req.params.projectId, req.uid);
      const vote = await tx.get(ref);
      if (!vote.exists || vote.data().deleting) throw fail(404, 'Bình chọn đã bị xóa.');
      const choices = [...new Set(data.options)].sort((a, b) => a - b);
      if (choices.some(i => i >= (vote.data().options?.length ?? 0))) throw fail(400, 'Phương án bình chọn không hợp lệ.');
      const ballot = ref.collection('ballots').doc(req.uid);
      if (!choices.length) tx.delete(ballot);
      else tx.set(ballot, { options: choices, updatedAt: FieldValue.serverTimestamp() });
    });
    res.json({ message: 'Đã cập nhật lựa chọn.' });
  });
}
