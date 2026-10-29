import { before, after, test } from 'node:test';
import assert from 'node:assert/strict';
import request from 'supertest';
// Tests use unique records in the LOCAL emulator and clean up only those records. No cloud calls.
process.env.USE_FIREBASE_EMULATORS = 'true';
process.env.FIREBASE_PROJECT_ID = 'demo-teamup-local';
process.env.FIREBASE_WEB_API_KEY = 'demo-test-key';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
const { createApp } = await import('../src/app.js');
const { db, auth } = await import('../src/firebase/client.js');
const app = createApp();
const username = `test_${Date.now()}`;
const account = { username, email: `${username}@example.com`, password: 'Test-pass-123', displayName: 'Firebase Nghi', major: 'Flutter', phone: '0912345678' };
let credentials;
before(async () => { await db.collection('_test').limit(1).get(); });
after(async () => {
  const mapping = await db.collection('usernames').doc(username).get();
  if (mapping.data()?.uid) { const uid = mapping.data().uid; await auth.deleteUser(uid); await db.collection('users').doc(uid).delete(); }
  await mapping.ref.delete();
  await db.terminate();
});
const bearer = token => `Bearer ${token}`;
test('signup uses Firebase Auth and writes profile without hashPassword; duplicates and injection are rejected', async () => {
  await request(app).post('/api/auth/signup').send({ ...account, password: 'short' }).expect(400);
  await request(app).post('/api/auth/signup').send({ ...account, username: { $ne: null } }).expect(400);
  await request(app).post('/api/auth/signup').send(account).expect(201);
  await request(app).post('/api/auth/signup').send(account).expect(409);
  const mapping = (await db.collection('usernames').doc(username).get()).data();
  const profile = (await db.collection('users').doc(mapping.uid).get()).data();
  assert.equal(profile.hashPassword, undefined);
  assert.equal((await auth.getUser(mapping.uid)).email, account.email);
});
test('signin returns Firebase tokens and protected profile updates preserve whitelist', async () => {
  await request(app).post('/api/auth/signin').send({ username, password: 'wrong-pass-123' }).expect(401);
  credentials = (await request(app).post('/api/auth/signin').send({ username, password: account.password }).expect(200)).body;
  const claims = await auth.verifyIdToken(credentials.accessToken);
  assert.equal(claims.aud, 'demo-teamup-local'); assert.equal(claims.uid, credentials.user.id);
  assert.equal(claims.exp - claims.iat, 3600);
  await request(app).get('/api/users/me').expect(401);
  await request(app).put('/api/users/profile').set('Authorization', bearer(credentials.accessToken)).send({ username: 'hacked' }).expect(400);
  await request(app).put('/api/users/profile').set('Authorization', bearer(credentials.accessToken)).send({ bio: 'x'.repeat(501) }).expect(400);
  const saved = await request(app).put('/api/users/profile').set('Authorization', bearer(credentials.accessToken)).send({ displayName: 'Updated Firebase', bio: 'Firestore profile' }).expect(200);
  assert.equal(saved.body.user.displayName, 'Updated Firebase');
});
test('Firebase refresh returns token pair; signout revokes refresh and invalid tokens do not authenticate', async () => {
  const refresh = (await request(app).post('/api/auth/refresh').send({ refreshToken: credentials.refreshToken }).expect(200)).body;
  assert.ok(refresh.accessToken && refresh.refreshToken);
  await request(app).post('/api/auth/refresh').send({ refreshToken: 'invalid' }).expect(401);
  // Firebase revocation timestamps have one-second precision.
  await new Promise(resolve => setTimeout(resolve, 1100));
  await request(app).post('/api/auth/signout').send({ refreshToken: refresh.refreshToken }).expect(200);
  await request(app).post('/api/auth/refresh').send({ refreshToken: refresh.refreshToken }).expect(401);
  await request(app).get('/api/users/me').set('Authorization', bearer(refresh.accessToken)).expect(401);
});
test('change password verifies old password and requires a fresh login', async () => {
  const signed = (await request(app).post('/api/auth/signin').send({ username, password: account.password }).expect(200)).body;
  await request(app).put('/api/users/change-password').set('Authorization', bearer(signed.accessToken)).send({ currentPassword: 'wrong-pass-123', newPassword: 'New-pass-456' }).expect(400);
  await new Promise(resolve => setTimeout(resolve, 1100));
  await request(app).put('/api/users/change-password').set('Authorization', bearer(signed.accessToken)).send({ currentPassword: account.password, newPassword: 'New-pass-456' }).expect(200);
  await request(app).post('/api/auth/signin').send({ username, password: account.password }).expect(401);
  await request(app).post('/api/auth/signin').send({ username, password: 'New-pass-456' }).expect(200);
});
