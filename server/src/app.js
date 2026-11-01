import { sendMessage, listenToMessages } from './firebase/messages.js';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import { randomUUID } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { auth, db, firebaseRest, profileFor, FirebaseRequestError } from './firebase/client.js';
import { validate, signupSchema, signinSchema, refreshSchema, profileSchema, changePasswordSchema } from './validation.js';

const fail = (status, message, code) => Object.assign(new Error(message), { status, code });
export function createApp() {
  const app = express();
  app.disable('x-powered-by'); app.use(helmet());
  app.use(cors({ origin(origin, cb) { cb(null, !origin || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin)); } }));
  app.use(express.json({ limit: '16kb' }));
  app.use('/api', (_req, res, next) => { res.set('Cache-Control', 'no-store'); next(); });
  app.use('/api/auth', rateLimit({ windowMs: 15 * 60 * 1000, limit: 100, standardHeaders: 'draft-8', legacyHeaders: false, handler: (_req, res) => res.status(429).json({ code: 'RATE_LIMIT', message: 'Quá nhiều yêu cầu. Vui lòng thử lại sau.' }) }));

  async function protectedRoute(req, _res, next) {
    const token = /^Bearer (\S+)$/.exec(req.get('Authorization') ?? '')?.[1];
    if (!token) throw fail(401, 'Vui lòng đăng nhập.', 'AUTH_REQUIRED');
    let decoded;
    try { decoded = await auth.verifyIdToken(token, true); }
    catch { throw fail(401, 'Phiên hết hạn. Vui lòng đăng nhập lại.', 'INVALID_ACCESS_TOKEN'); }
    req.uid = decoded.uid;
    req.user = await profileFor(decoded.uid);
    next();
  }
  const messageLimit = rateLimit({ windowMs: 60000, limit: 30, standardHeaders: 'draft-8', legacyHeaders: false,
    handler: (_req, res) => res.status(429).json({ code: 'RATE_LIMIT', message: 'Bạn gửi quá nhanh. Vui lòng chờ một chút.' }) });
  app.post('/api/messages', protectedRoute, messageLimit, async (req, res) => {
    const result = await sendMessage(req.body?.text, req.uid, req.user.displayName || req.user.username, req.user.avatarUrl);
    res.status(201).json(result);
  });
  app.get('/api/messages/stream', protectedRoute, (req, res) => {
    res.set({ 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache, no-transform', 'X-Accel-Buffering': 'no' });
    res.flushHeaders();
    let unsubscribe = () => {};
    let closed = false;
    let heartbeat, renewal;
    function close() {
      if (closed) return;
      closed = true;
      clearInterval(heartbeat); clearTimeout(renewal); unsubscribe(); res.end();
    }
    res.on('close', close);
    const write = data => {
      if (!closed && !res.write(`data: ${JSON.stringify(data)}\n\n`)) close();
    };
    unsubscribe = listenToMessages(messages => write({ messages }), () => {
      write({ error: 'CHAT_UNAVAILABLE' }); close();
    });
    if (closed) { unsubscribe(); return; }
    heartbeat = setInterval(() => { if (!closed && !res.write(': heartbeat\n\n')) close(); }, 15000);
    // Reconnect with bearer verification, so revoked/expired sessions lose access.
    renewal = setTimeout(close, 60000);
  });


  // Project / member / task REST API. All writes are performed with Admin SDK
  // after verifying the Firebase ID token and project membership.
  const projectRef = id => db.collection('projects').doc(id);
  const memberRef = (projectId, uid) => projectRef(projectId).collection('members').doc(uid);
  const membershipRef = (uid, projectId) => db.collection('users').doc(uid).collection('projectMemberships').doc(projectId);
  const taskRef = (projectId, taskId) => projectRef(projectId).collection('tasks').doc(taskId);
  const asIso = value => value?.toDate?.()?.toISOString?.() ?? value ?? null;
  const clean = value => {
    if (Array.isArray(value)) return value.map(clean);
    if (value && typeof value === 'object' && typeof value.toDate === 'function') return value.toDate().toISOString();
    if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k,v]) => [k, clean(v)]));
    return value;
  };
  async function requireProject(req, projectId) {
    const ref = projectRef(projectId), snap = await ref.get();
    if (!snap.exists) throw fail(404, 'Không tìm thấy dự án.', 'PROJECT_NOT_FOUND');
    const member = await memberRef(projectId, req.uid).get();
    if (!member.exists) throw fail(403, 'Bạn không phải thành viên của dự án.', 'PROJECT_FORBIDDEN');
    return { ref, data: snap.data(), role: member.data()?.role ?? 'member' };
  }
  async function requireLeader(req, projectId) {
    const project = await requireProject(req, projectId);
    if (project.role !== 'leader') throw fail(403, 'Chỉ leader mới được thực hiện thao tác này.', 'LEADER_REQUIRED');
    return project;
  }
  function addActivity(batch, projectId, uid, action, targetId, targetName = '') {
    batch.set(projectRef(projectId).collection('activities').doc(), {
      actorId: uid, action, targetId: targetId ?? projectId, targetName,
      targetType: action.startsWith('task') ? 'task' : action.startsWith('member') ? 'member' : 'project',
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  app.get('/api/projects', protectedRoute, async (req, res) => {
    const memberships = await db.collection('users').doc(req.uid).collection('projectMemberships').get();
    const rows = await Promise.all(memberships.docs.map(async m => {
      const snap = await projectRef(m.id).get();
      return snap.exists ? { id: snap.id, ...clean(snap.data()), myRole: m.data()?.role ?? 'member' } : null;
    }));
    res.json({ projects: rows.filter(Boolean) });
  });
  app.post('/api/projects', protectedRoute, async (req, res) => {
    const name = String(req.body?.name ?? '').trim();
    if (!name) throw fail(400, 'Tên dự án không được để trống.', 'VALIDATION_ERROR');
    const ref = projectRef(db.collection('projects').doc().id), batch = db.batch();
    const joinCode = ref.id.slice(0, 8).toUpperCase();
    const date = value => value ? new Date(value) : null;
    batch.create(ref, { name, description: String(req.body?.description ?? '').trim(), tag: String(req.body?.tag ?? '').trim(),
      coverUrl: String(req.body?.coverUrl ?? ''), ownerId: req.uid, memberIds: [req.uid], joinCode, status: 'active',
      totalTasks: 0, completedTasks: 0, progress: 0, startDate: date(req.body?.startDate), endDate: date(req.body?.endDate),
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
    batch.set(memberRef(ref.id, req.uid), { uid: req.uid, role: 'leader', JoinAt: FieldValue.serverTimestamp(), joinedAt: FieldValue.serverTimestamp(), taskCount: 0, completedTaskCount: 0 });
    batch.set(membershipRef(req.uid, ref.id), { role: 'leader', joinedAt: FieldValue.serverTimestamp() });
    addActivity(batch, ref.id, req.uid, 'project_created', ref.id, name);
    await batch.commit();
    res.status(201).json({ project: { id: ref.id, name, description: String(req.body?.description ?? ''), tag: String(req.body?.tag ?? ''), coverUrl: String(req.body?.coverUrl ?? ''), ownerId: req.uid, memberIds: [req.uid], joinCode, status: 'active', myRole: 'leader' } });
  });
  app.get('/api/projects/:projectId', protectedRoute, async (req, res) => {
    const p = await requireProject(req, req.params.projectId);
    res.json({ project: { id: req.params.projectId, ...clean(p.data), myRole: p.role } });
  });
  app.patch('/api/projects/:projectId', protectedRoute, async (req, res) => {
    const p = await requireLeader(req, req.params.projectId);
    const allowed = ['name','description','tag','coverUrl','status','startDate','endDate'];
    const changes = Object.fromEntries(Object.entries(req.body ?? {}).filter(([k]) => allowed.includes(k)));
    if ('name' in changes && !String(changes.name).trim()) throw fail(400, 'Tên dự án không được để trống.', 'VALIDATION_ERROR');
    for (const k of ['startDate','endDate']) if (changes[k]) changes[k] = new Date(changes[k]);
    if (changes.name) changes.name = String(changes.name).trim();
    if (!Object.keys(changes).length) throw fail(400, 'Không có nội dung cần cập nhật.', 'VALIDATION_ERROR');
    changes.updatedAt = FieldValue.serverTimestamp(); await p.ref.update(changes);
    res.json({ message: 'Đã cập nhật dự án.' });
  });
  app.delete('/api/projects/:projectId', protectedRoute, async (req, res) => {
    const p = await requireLeader(req, req.params.projectId);
    const projectId = req.params.projectId;
    const memberDocs = await p.ref.collection('members').get();
    const batch = db.batch();
    for (const m of memberDocs.docs) batch.delete(membershipRef(m.id, projectId));
    await batch.commit();
    await db.recursiveDelete(p.ref);
    res.json({ message: 'Đã xóa dự án và dữ liệu liên quan.' });
  });
  app.post('/api/projects/join', protectedRoute, async (req, res) => {
    const code = String(req.body?.joinCode ?? req.body?.inviteCode ?? '').trim().toUpperCase();
    if (!code) throw fail(400, 'Vui lòng nhập mã tham gia.', 'VALIDATION_ERROR');
    const found = await db.collection('projects').where('joinCode', '==', code).limit(1).get();
    if (found.empty) throw fail(404, 'Mã tham gia không hợp lệ.', 'INVALID_JOIN_CODE');
    const projectId = found.docs[0].id, pRef = projectRef(projectId), mRef = memberRef(projectId, req.uid);
    await db.runTransaction(async tx => {
      const existing = await tx.get(mRef);
      if (existing.exists) throw fail(409, 'Bạn đã tham gia dự án này.', 'ALREADY_MEMBER');
      tx.set(mRef, { uid: req.uid, role: 'member', JoinAt: FieldValue.serverTimestamp(), joinedAt: FieldValue.serverTimestamp(), taskCount: 0, completedTaskCount: 0 });
      tx.set(membershipRef(req.uid, projectId), { role: 'member', joinedAt: FieldValue.serverTimestamp() });
      tx.update(pRef, { memberIds: FieldValue.arrayUnion(req.uid), updatedAt: FieldValue.serverTimestamp() });
    });
    res.status(201).json({ projectId });
  });
  app.post('/api/projects/:projectId/members', protectedRoute, async (req, res) => {
    await requireLeader(req, req.params.projectId);
    const username = String(req.body?.username ?? '').trim().toLowerCase();
    if (!username) throw fail(400, 'Vui lòng nhập username.', 'VALIDATION_ERROR');
    const claim = await db.collection('usernames').doc(username).get();
    const targetUid = claim.data()?.uid;
    if (!targetUid) throw fail(404, 'Không tìm thấy username.', 'USER_NOT_FOUND');
    const mRef = memberRef(req.params.projectId, targetUid);
    await db.runTransaction(async tx => {
      if ((await tx.get(mRef)).exists) throw fail(409, 'Người dùng đã tham gia dự án này.', 'ALREADY_MEMBER');
      tx.set(mRef, { uid: targetUid, role: 'member', JoinAt: FieldValue.serverTimestamp(), joinedAt: FieldValue.serverTimestamp(), taskCount: 0, completedTaskCount: 0 });
      tx.set(membershipRef(targetUid, req.params.projectId), { role: 'member', joinedAt: FieldValue.serverTimestamp() });
      tx.update(projectRef(req.params.projectId), { memberIds: FieldValue.arrayUnion(targetUid), updatedAt: FieldValue.serverTimestamp() });
    });
    res.status(201).json({ uid: targetUid });
  });
  app.get('/api/projects/:projectId/members', protectedRoute, async (req, res) => {
    await requireProject(req, req.params.projectId);
    const members = await projectRef(req.params.projectId).collection('members').get();
    const rows = await Promise.all(members.docs.map(async m => {
      const u = await db.collection('users').doc(m.id).get();
      return { uid: m.id, id: m.id, role: m.data()?.role ?? 'member', joinedAt: clean(m.data()?.JoinAt ?? m.data()?.joinedAt), ...(u.exists ? { username: u.data().username ?? '', displayName: u.data().displayName ?? '', avatarUrl: u.data().avatarUrl ?? '' } : {}) };
    }));
    res.json({ members: rows });
  });
  app.delete('/api/projects/:projectId/members/:uid', protectedRoute, async (req, res) => {
    const p = await requireLeader(req, req.params.projectId), target = req.params.uid;
    if (target === p.data.ownerId) throw fail(400, 'Không thể xóa leader duy nhất của dự án.', 'OWNER_PROTECTED');
    const batch = db.batch(); batch.delete(memberRef(req.params.projectId, target)); batch.delete(membershipRef(target, req.params.projectId));
    batch.update(p.ref, { memberIds: FieldValue.arrayRemove(target), updatedAt: FieldValue.serverTimestamp() }); await batch.commit();
    res.json({ message: 'Đã xóa thành viên.' });
  });
  app.post('/api/projects/:projectId/leave', protectedRoute, async (req, res) => {
    const p = await requireProject(req, req.params.projectId);
    if (p.data.ownerId === req.uid) throw fail(400, 'Leader cần chuyển giao dự án trước khi rời nhóm.', 'OWNER_CANNOT_LEAVE');
    const batch = db.batch(); batch.delete(memberRef(req.params.projectId, req.uid)); batch.delete(membershipRef(req.uid, req.params.projectId));
    batch.update(p.ref, { memberIds: FieldValue.arrayRemove(req.uid), updatedAt: FieldValue.serverTimestamp() }); await batch.commit();
    res.json({ message: 'Đã rời dự án.' });
  });
  app.get('/api/projects/:projectId/tasks', protectedRoute, async (req, res) => {
    await requireProject(req, req.params.projectId);
    const snap = await projectRef(req.params.projectId).collection('tasks').get();
    res.json({ tasks: snap.docs.map(d => ({ id: d.id, projectId: req.params.projectId, ...clean(d.data()) })) });
  });
  app.post('/api/projects/:projectId/tasks', protectedRoute, async (req, res) => {
    const p = await requireLeader(req, req.params.projectId), body = req.body ?? {};
    const title = String(body.title ?? '').trim(), assigneeIds = [...new Set((body.assigneeIds ?? (body.assigneeId ? [body.assigneeId] : [])).map(String))];
    if (!title || !assigneeIds.length) throw fail(400, 'Cần có tên công việc và ít nhất một người thực hiện.', 'VALIDATION_ERROR');
    const memberChecks = await Promise.all(assigneeIds.map(uid => memberRef(req.params.projectId, uid).get()));
    if (memberChecks.some(x => !x.exists)) throw fail(400, 'Người được giao phải là thành viên dự án.', 'INVALID_ASSIGNEE');
    const ref = p.ref.collection('tasks').doc(), data = { title, description: String(body.description ?? ''), status: 'todo', priority: body.priority ?? 'medium', assigneeIds,
      createdBy: req.uid, startDate: body.startDate ? new Date(body.startDate) : null, dueDate: body.dueDate ? new Date(body.dueDate) : null,
      attachmentUrls: Array.isArray(body.attachmentUrls) ? body.attachmentUrls : [], outputType: body.outputType ?? 'none', outputRequired: body.outputRequired ?? false, checklist: Array.isArray(body.checklist) ? body.checklist : [], createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() };
    const batch = db.batch(); batch.create(ref, data); batch.update(p.ref, { totalTasks: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }); addActivity(batch, req.params.projectId, req.uid, 'task_created', ref.id, title); await batch.commit();
    res.status(201).json({ task: { id: ref.id, projectId: req.params.projectId, ...clean(data) } });
  });
  app.patch('/api/projects/:projectId/tasks/:taskId', protectedRoute, async (req, res) => {
    const p = await requireProject(req, req.params.projectId), ref = taskRef(req.params.projectId, req.params.taskId), snap = await ref.get();
    if (!snap.exists) throw fail(404, 'Không tìm thấy công việc.', 'TASK_NOT_FOUND');
    const old = snap.data(), body = req.body ?? {}, leader = p.role === 'leader';
    const allowed = leader ? ['title','description','priority','assigneeIds','status','dueDate','startDate','attachmentUrls','outputLink','reviewComment','outputType','outputRequired','checklist'] : ['status','outputLink','reviewComment'];
    if (Object.keys(body).some(k => !allowed.includes(k))) throw fail(403, 'Bạn không có quyền sửa trường dữ liệu này.', 'TASK_FIELD_FORBIDDEN');
    if (!leader && !(old.assigneeIds ?? []).includes(req.uid)) throw fail(403, 'Bạn không được giao công việc này.', 'TASK_NOT_ASSIGNED');
    const changes = Object.fromEntries(Object.entries(body).filter(([k]) => allowed.includes(k)));
    if (changes.title !== undefined && !String(changes.title).trim()) throw fail(400, 'Tên công việc không được để trống.', 'VALIDATION_ERROR');
    if (changes.assigneeIds) {
      const ids = [...new Set(changes.assigneeIds.map(String))];
      const checks = await Promise.all(ids.map(uid => memberRef(req.params.projectId, uid).get()));
      if (!ids.length || checks.some(x => !x.exists)) throw fail(400, 'Người được giao phải là thành viên dự án.', 'INVALID_ASSIGNEE');
      changes.assigneeIds = ids;
    }
    for (const k of ['dueDate','startDate']) if (changes[k]) changes[k] = new Date(changes[k]);
    if (changes.status && !['todo','in_progress','pending_review','revision_required','completed'].includes(changes.status)) throw fail(400, 'Trạng thái công việc không hợp lệ.', 'INVALID_TASK_STATUS');
    if (changes.status && changes.status !== old.status) {
      const memberTransitions = { todo: ['in_progress'], in_progress: ['pending_review'], revision_required: ['in_progress'] };
      if (!leader && !(memberTransitions[old.status] ?? []).includes(changes.status)) throw fail(403, 'Không thể chuyển sang trạng thái này.', 'INVALID_TASK_TRANSITION');
      if (leader) {
        const review = ['completed','revision_required'].includes(changes.status) && old.status === 'pending_review';
        const leaderOwns = (old.assigneeIds ?? []).includes(req.uid);
        const selfStart = changes.status === 'in_progress' && ['todo','revision_required'].includes(old.status);
        if (!review && !selfStart && !leaderOwns) throw fail(403, 'Bạn không được chuyển trạng thái công việc này.', 'INVALID_TASK_TRANSITION');
      }
    }
    if (changes.assigneeIds) {
      const ids = [...new Set(changes.assigneeIds.map(String))];
      const checks = await Promise.all(ids.map(uid => memberRef(req.params.projectId, uid).get()));
      if (!ids.length || checks.some(x => !x.exists)) throw fail(400, 'Người được giao phải là thành viên dự án.', 'INVALID_ASSIGNEE');
      changes.assigneeIds = ids;
    }
    if (changes.status === 'completed') changes.completedAt = FieldValue.serverTimestamp();
    changes.updatedAt = FieldValue.serverTimestamp();
    const wasCompleted = old.status === 'completed', willBeCompleted = (changes.status ?? old.status) === 'completed';
    const batch = db.batch(); batch.update(ref, changes);
    if (wasCompleted !== willBeCompleted) batch.update(p.ref, { completedTasks: FieldValue.increment(willBeCompleted ? 1 : -1), updatedAt: FieldValue.serverTimestamp() });
    await batch.commit();
    res.json({ message: 'Đã cập nhật công việc.' });
  });
  app.delete('/api/projects/:projectId/tasks/:taskId', protectedRoute, async (req, res) => {
    const p = await requireLeader(req, req.params.projectId), ref = taskRef(req.params.projectId, req.params.taskId), snap = await ref.get();
    if (!snap.exists) throw fail(404, 'Không tìm thấy công việc.', 'TASK_NOT_FOUND');
    const batch = db.batch(); batch.delete(ref); batch.update(p.ref, { totalTasks: FieldValue.increment(-1), ...(snap.data()?.status === 'completed' ? { completedTasks: FieldValue.increment(-1) } : {}), updatedAt: FieldValue.serverTimestamp() }); await batch.commit();
    res.json({ message: 'Đã xóa công việc.' });
  });

  app.get('/api/health', async (_req, res) => {
    await db.collection('_health').limit(1).get();
    res.json({ status: 'ok', authentication: 'Firebase Authentication', database: 'Cloud Firestore' });
  });
  app.post('/api/auth/signup', async (req, res) => {
    const data = validate(signupSchema, req);
    const reservation = db.collection('usernames').doc(data.username);
    const operationId = randomUUID();
    await db.runTransaction(async transaction => {
      if ((await transaction.get(reservation)).exists) throw fail(409, 'Tên đăng nhập đã được sử dụng.', 'DUPLICATE_USER');
      transaction.create(reservation, { operationId, createdAt: FieldValue.serverTimestamp() });
    });
    let uid;
    try {
      const record = await auth.createUser({ email: data.email, password: data.password, displayName: data.displayName });
      uid = record.uid;
      const batch = db.batch();
      batch.create(db.collection('users').doc(uid), { username: data.username, email: data.email, displayName: data.displayName,
        major: data.major ?? '', phone: data.phone ?? '', bio: '', avatarUrl: '',
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      batch.set(reservation, { uid, email: data.email, createdAt: FieldValue.serverTimestamp() });
      await batch.commit();
    } catch (error) {
      if (uid) await auth.deleteUser(uid);
      await db.runTransaction(async transaction => {
        const claim = await transaction.get(reservation);
        if (claim.data()?.operationId === operationId) transaction.delete(reservation);
      });
      throw error;
    }
    res.status(201).json({ message: 'Đăng ký thành công. Bạn có thể đăng nhập.' });
  });
  app.post('/api/auth/signin', async (req, res) => {
    const data = validate(signinSchema, req);
    const mapping = (await db.collection('usernames').doc(data.username).get()).data();
    if (!mapping?.email) throw fail(401, 'Tên đăng nhập hoặc mật khẩu không đúng.', 'INVALID_CREDENTIALS');
    const tokens = await firebaseRest('accounts:signInWithPassword', { email: mapping.email, password: data.password, returnSecureToken: true });
    if (tokens.localId !== mapping.uid) throw fail(401, 'Thông tin tài khoản không hợp lệ.', 'INVALID_CREDENTIALS');
    await auth.verifyIdToken(tokens.idToken, true);
    res.json({ accessToken: tokens.idToken, refreshToken: tokens.refreshToken, user: await profileFor(tokens.localId) });
  });
  app.post('/api/auth/refresh', async (req, res) => {
    const data = validate(refreshSchema, req);
    const tokens = await firebaseRest('token', { grant_type: 'refresh_token', refresh_token: data.refreshToken }, { secureToken: true });
    await auth.verifyIdToken(tokens.id_token, true);
    await profileFor(tokens.user_id);
    res.json({ accessToken: tokens.id_token, refreshToken: tokens.refresh_token });
  });
  app.post('/api/auth/signout', async (req, res) => {
    const data = validate(refreshSchema, req);
    try {
      const tokens = await firebaseRest('token', { grant_type: 'refresh_token', refresh_token: data.refreshToken }, { secureToken: true });
      await auth.revokeRefreshTokens(tokens.user_id);
    } catch (error) { if (!(error instanceof FirebaseRequestError) || error.status !== 401) throw error; }
    res.json({ message: 'Đã đăng xuất và thu hồi phiên đăng nhập trên tất cả thiết bị.' });
  });
  app.get('/api/users/me', protectedRoute, (req, res) => res.json({ user: req.user }));
  app.put('/api/users/profile', protectedRoute, async (req, res) => {
    const fields = validate(profileSchema, req);
    // Profile is authoritative in Firestore. Never accept roles/username/email here.
    await db.collection('users').doc(req.uid).update({ ...fields, updatedAt: FieldValue.serverTimestamp() });
    res.json({ message: 'Đã lưu hồ sơ.', user: await profileFor(req.uid) });
  });
  app.put('/api/users/change-password', protectedRoute, async (req, res) => {
    const data = validate(changePasswordSchema, req);
    let verified;
    try { verified = await firebaseRest('accounts:signInWithPassword', { email: req.user.email, password: data.currentPassword, returnSecureToken: true }); }
    catch (error) { if (error.status === 401) throw fail(400, 'Mật khẩu hiện tại không đúng.', 'WRONG_PASSWORD'); throw error; }
    if (verified.localId !== req.uid) throw fail(401, 'Thông tin tài khoản không hợp lệ.', 'INVALID_CREDENTIALS');
    await auth.updateUser(req.uid, { password: data.newPassword });
    await auth.revokeRefreshTokens(req.uid);
    res.json({ message: 'Đã đổi mật khẩu. Vui lòng đăng nhập lại.' });
  });
  app.use((_req, res) => res.status(404).json({ code: 'NOT_FOUND', message: 'API không tồn tại.' }));
  app.use((error, _req, res, _next) => {
    if (['auth/email-already-exists', 'auth/uid-already-exists'].includes(error.code)) return res.status(409).json({ code: 'DUPLICATE_USER', message: 'Email đã được sử dụng.' });
    const tokenErrors = ['auth/id-token-revoked', 'auth/id-token-expired', 'auth/invalid-id-token', 'auth/user-disabled', 'auth/user-not-found'];
    const status = error.status || (tokenErrors.includes(error.code) ? 401 : error.code?.startsWith?.('auth/invalid-') ? 400 : 500);
    if (status >= 500) console.error('Firebase API error:', error.code ?? error.name);
    res.status(status).json({ code: typeof error.code === 'string' ? error.code : 'REQUEST_FAILED', message: status >= 500 ? 'Không kết nối được Firebase hoặc cấu hình Firebase chưa sẵn sàng.' : error.message });
  });
  return app;
}
