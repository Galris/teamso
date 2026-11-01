import { createHash } from 'node:crypto';
import { FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';

const hash = token => createHash('sha256').update(token).digest('hex');
const invalidTokens = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token']);
export function notificationService(db, messaging = getMessaging()) {
  // Notification and source event are committed together; FCM is a best-effort
  // delivery channel. A push failure must never undo the saved notification.
  function stage(writer, recipients, data) {
    return [...new Set(recipients.filter(Boolean))].map(uid => {
      const ref = db.collection('users').doc(uid).collection('notifications').doc();
      writer.create(ref, { ...data, read: false, createdAt: FieldValue.serverTimestamp() });
      return { uid, ref, data };
    });
  }
  async function send(jobs) {
    for (const {uid, ref, data} of jobs) {
      try {
        const devices = await db.collection('_pushDevices').where('uid', '==', uid).get();
        for (let start = 0; start < devices.size; start += 500) {
          const rows = devices.docs.slice(start, start + 500);
          const result = await messaging.sendEachForMulticast({
            tokens: rows.map(d => d.data().token),
            notification: {title: data.title, body: data.body},
            data: {notificationId: ref.id, projectId: data.projectId ?? '', type: data.type, targetId: data.targetId ?? ''},
            android: {priority: 'high', notification: {tag: ref.id}},
          });
          await Promise.all(result.responses.map(async (response, i) => {
            if (!response.success && invalidTokens.has(response.error?.code)) {
              // Never remove a token which was rebound while FCM was sending.
              await db.runTransaction(async tx => {
                const current = await tx.get(rows[i].ref);
                if (current.data()?.uid === uid && current.data()?.token === rows[i].data().token) tx.delete(rows[i].ref);
              });
            } else if (!response.success) console.error('FCM delivery failed:', response.error?.code);
          }));
        }
      } catch (error) { console.error('FCM delivery unavailable:', error.code ?? error.message); }
    }
  }
  async function deliver(jobs) {
    // Persisted writes must not appear to fail just because FCM is slow.
    // The send may finish in the background after the API response.
    let timer;
    try {
      await Promise.race([send(jobs), new Promise(resolve => { timer = setTimeout(resolve, 4000); })]);
    } finally { clearTimeout(timer); }
  }
  return {stage, deliver};
}

export function registerNotificationDevices(app, {db, protectedRoute}) {
  const token = req => {
    const value = req.body?.token;
    if (typeof value !== 'string' || value.length < 20 || value.length > 4096 || /\s/.test(value)) {
      throw Object.assign(new Error('Token thiết bị không hợp lệ.'), {status: 400});
    }
    return value;
  };
  app.put('/api/notifications/device', protectedRoute, async (req, res) => {
    const value = token(req);
    await db.collection('_pushDevices').doc(hash(value)).set({uid: req.uid, token: value, updatedAt: FieldValue.serverTimestamp()});
    res.json({message: 'Đã bật thông báo trên thiết bị này.'});
  });
  app.delete('/api/notifications/device', protectedRoute, async (req, res) => {
    const ref = db.collection('_pushDevices').doc(hash(token(req)));
    await db.runTransaction(async tx => { const row = await tx.get(ref); if (row.data()?.uid === req.uid) tx.delete(ref); });
    res.json({message: 'Đã tắt thông báo trên thiết bị này.'});
  });
}
