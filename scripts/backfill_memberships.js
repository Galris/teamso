// Run once with Firebase Admin credentials after reviewing the target project.
// node scripts/backfill_memberships.js
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

const normalizeStatus = (status) => ({
  'Cần làm': 'todo', 'Đang làm': 'in_progress', 'Chờ duyệt': 'pending_review',
  'Hoàn thành': 'completed', 'Cần sửa': 'revision_required',
}[status] || status || 'todo');

async function run() {
  const members = await db.collectionGroup('members').get();
  let batch = db.batch();
  let writes = 0;
  const commitIfNeeded = async () => {
    if (writes >= 400) { await batch.commit(); batch = db.batch(); writes = 0; }
  };
  for (const member of members.docs) {
    const projectRef = member.ref.parent.parent;
    if (!projectRef) continue;
    const uid = member.id; // The existing membership document ID is the Firebase UID.
    const project = await projectRef.get();
    const ownerId = project.get('ownerId');
    const role = (uid === ownerId || member.get('role') === 'leader') ? 'leader' : 'member';
    const joinedAt = member.get('joinedAt') || admin.firestore.FieldValue.serverTimestamp();
    batch.set(member.ref, { role, joinedAt }, { merge: false });
    batch.set(db.doc(`users/${uid}/projectMemberships/${projectRef.id}`), { role, joinedAt }, { merge: true });
    writes += 2;
    await commitIfNeeded();
  }
  if (writes) await batch.commit();

  // Strip email from username claims; only uid is needed by the app.
  const claims = await db.collection('usernames').get();
  batch = db.batch(); writes = 0;
  for (const claim of claims.docs) {
    const uid = claim.get('uid');
    if (typeof uid !== 'string' || !uid) continue;
    batch.set(claim.ref, { uid, createdAt: claim.get('createdAt') || admin.firestore.FieldValue.serverTimestamp() }, { merge: false });
    writes++;
    await commitIfNeeded();
  }
  if (writes) await batch.commit();

  const projects = await db.collection('projects').get();
  for (const project of projects.docs) {
    const tasks = await project.ref.collection('tasks').get();
    batch = db.batch(); writes = 0;
    for (const task of tasks.docs) {
      const data = task.data();
      const assigneeIds = Array.isArray(data.assigneeIds)
        ? data.assigneeIds
        : (typeof data.assigneeId === 'string' && data.assigneeId ? [data.assigneeId] : []);
      const updated = { ...data, assigneeIds, status: normalizeStatus(data.status), createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(), updatedAt: data.updatedAt || admin.firestore.FieldValue.serverTimestamp() };
      delete updated.assigneeId;
      batch.set(task.ref, updated, { merge: false });
      writes++;
      await commitIfNeeded();
    }
    if (writes) await batch.commit();
  }
  console.log(`Backfill complete: ${members.size} memberships, ${claims.size} username claims, ${projects.size} projects scanned.`);
}

run().catch((error) => { console.error(error); process.exit(1); });
