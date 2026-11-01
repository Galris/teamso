const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { document } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

const inbox = (uid) => db.collection('users').doc(uid).collection('notifications');

/// Ghi một thông báo vào hộp thư của người nhận; lỗi chỉ ghi log, không làm hỏng luồng chính.
async function notify(uid, { type, title, body, projectId = null }) {
  if (!uid) return;
  try {
    await inbox(uid).add({
      type,
      title,
      body,
      projectId,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(`Không tạo được thông báo cho ${uid}:`, error);
  }
}

async function ownerOf(projectId) {
  const project = await db.collection('projects').doc(projectId).get();
  return project.exists ? project.data().ownerId : null;
}

const asText = (value) => String(value ?? '').trim();

exports.joinProjectByCode = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập.');
  const joinCode = String(request.data?.joinCode || '').trim().toUpperCase();
  if (!joinCode || joinCode.length > 32) throw new HttpsError('invalid-argument', 'Mã tham gia không hợp lệ.');

  const matches = await db.collection('projects').where('joinCode', '==', joinCode).limit(2).get();
  if (matches.size !== 1) throw new HttpsError('not-found', 'Mã tham gia không hợp lệ.');
  const project = matches.docs[0];
  const uid = request.auth.uid;
  const memberRef = project.ref.collection('members').doc(uid);
  const indexRef = db.collection('users').doc(uid).collection('projectMemberships').doc(project.id);

  await db.runTransaction(async (tx) => {
    const [member, user] = await Promise.all([tx.get(memberRef), tx.get(db.collection('users').doc(uid))]);
    if (!user.exists) throw new HttpsError('failed-precondition', 'Không tìm thấy hồ sơ người dùng.');
    if (member.exists) throw new HttpsError('already-exists', 'Bạn đã tham gia dự án này.');
    tx.create(memberRef, { role: 'member', joinedAt: FieldValue.serverTimestamp() });
    tx.set(indexRef, { role: 'member', joinedAt: FieldValue.serverTimestamp() });
    tx.create(project.ref.collection('activities').doc(), {
      actorId: uid, action: 'member_joined', targetId: uid,
      targetType: 'member', createdAt: FieldValue.serverTimestamp(),
    });
  });
  return { projectId: project.id };
});

exports.deleteProject = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập.');
  const projectId = String(request.data?.projectId || '').trim();
  if (!projectId) throw new HttpsError('invalid-argument', 'Thiếu projectId.');
  const projectRef = db.collection('projects').doc(projectId);
  const projectSnap = await projectRef.get();
  if (!projectSnap.exists) throw new HttpsError('not-found', 'Không tìm thấy dự án.');
  if (projectSnap.data().ownerId !== request.auth.uid) throw new HttpsError('permission-denied', 'Chỉ người tạo dự án mới được xóa.');

  const members = await projectRef.collection('members').get();
  const subcollections = ['tasks', 'activities', 'messages', 'documents', 'meetings', 'votes'];
  const refs = [...members.docs.map((d) => d.ref), projectRef];
  for (const name of subcollections) {
    const snap = await projectRef.collection(name).get();
    for (const doc of snap.docs) {
      refs.push(doc.ref);
      if (name === 'votes') {
        const ballots = await doc.ref.collection('ballots').get();
        for (const ballot of ballots.docs) refs.push(ballot.ref);
      }
    }
  }
  for (let i = 0; i < refs.length; i += 400) {
    const batch = db.batch();
    refs.slice(i, i + 400).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }
  for (const member of members.docs) {
    await db.collection('users').doc(member.id).collection('projectMemberships').doc(projectId).delete().catch(() => {});
  }
  return { success: true };
});

exports.getProjectMembers = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Bạn cần đăng nhập.');
  const projectId = String(request.data?.projectId || '').trim();
  if (!projectId) throw new HttpsError('invalid-argument', 'Thiếu projectId.');
  const projectRef = db.collection('projects').doc(projectId);
  const caller = await projectRef.collection('members').doc(request.auth.uid).get();
  if (!caller.exists) throw new HttpsError('permission-denied', 'Bạn không phải thành viên dự án.');
  const members = await projectRef.collection('members').get();
  const profiles = await Promise.all(members.docs.map(async (member) => {
    const profile = await db.collection('users').doc(member.id).get();
    const user = profile.data() || {};
    return {
      uid: member.id,
      id: member.id,
      role: member.get('role') || 'member',
      joinedAt: member.get('joinedAt') || null,
      username: user.username || '',
      displayName: user.displayName || user.username || 'Thành viên',
      avatarUrl: user.avatarUrl || '',
      major: user.major || '',
      bio: user.bio || '',
    };
  }));
  return { members: profiles };
});

// ----- Thông báo realtime (Admin ghi đè Security Rules phía client) -----

exports.onTaskCreated = document('projects/{projectId}/tasks/{taskId}').onCreate(async (event) => {
  const task = event.data.data() || {};
  const projectId = event.params.projectId;
  const title = asText(task.title) || 'công việc';
  const createdBy = asText(task.createdBy);
  const assignees = Array.isArray(task.assigneeIds) ? task.assigneeIds.map(String) : [];
  const target = await ownerOf(projectId);
  // Người được giao (không gồm người tạo) nhận thông báo giao việc.
  for (const uid of assignees) {
    if (uid && uid !== createdBy) {
      await notify(uid, { type: 'assigned', projectId, title: 'Bạn được giao việc mới', body: `“${title}” vừa được giao cho bạn.` });
    }
  }
  // Leader tự giao cho chính mình thì cũng ghi nhận vào hộp thư.
  if (target && createdBy === target && assignees.includes(target)) {
    await notify(target, { type: 'assigned', projectId, title: 'Công việc của bạn', body: `“${title}” đã được giao.` });
  }
});

exports.onTaskUpdated = document('projects/{projectId}/tasks/{taskId}').onUpdate(async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const projectId = event.params.projectId;
  const title = asText(after.title) || 'công việc';
  const prevStatus = asText(before.status);
  const status = asText(after.status);
  if (!status || status === prevStatus) return;

  const assignees = Array.isArray(after.assigneeIds) ? after.assigneeIds.map(String) : [];
  const owner = await ownerOf(projectId);

  if (status === 'pending_review') {
    await notify(owner, { type: 'updated', projectId, title: 'Công việc chờ duyệt', body: `“${title}” đang chờ bạn duyệt.` });
  } else if (status === 'completed') {
    for (const uid of assignees) {
      if (uid && uid !== owner) await notify(uid, { type: 'completed', projectId, title: 'Công việc đã hoàn thành', body: `“${title}” đã được duyệt.` });
    }
  } else if (status === 'revision_required') {
    for (const uid of assignees) {
      if (uid) await notify(uid, { type: 'updated', projectId, title: 'Cần chỉnh sửa công việc', body: `“${title}” cần sửa: ${asText(after.reviewComment) || 'xem nhận xét'}.` });
    }
  }
});

exports.onMemberAdded = document('projects/{projectId}/members/{memberUid}').onCreate(async (event) => {
  const member = event.data.data() || {};
  if (asText(member.role) !== 'member') return; // bỏ qua leader tự tạo khi khởi tạo dự án
  const projectId = event.params.projectId;
  const project = await db.collection('projects').doc(projectId).get();
  const name = project.exists ? asText(project.data().name) : 'dự án';
  await notify(event.params.memberUid, { type: 'updated', projectId, title: 'Bạn đã tham gia dự án', body: `Bạn đã được thêm vào “${name}”.` });
});
