import 'dotenv/config';

// Read-only connectivity check: never creates accounts or writes Firestore data.
let db;
try {
  if (process.env.USE_FIREBASE_EMULATORS !== 'false') {
    throw new Error('Đặt USE_FIREBASE_EMULATORS=false trong server/.env để kiểm tra cloud.');
  }
  if (!process.env.FIREBASE_WEB_API_KEY || process.env.FIREBASE_WEB_API_KEY.startsWith('replace-')) {
    throw new Error('Điền FIREBASE_WEB_API_KEY của project vào server/.env.');
  }
  const firebase = await import('../src/firebase/client.js');
  db = firebase.db;
  await db.collection('users').limit(1).get();
  console.log(`Firestore cloud OK: ${firebase.firebaseProjectId}`);
  await firebase.auth.listUsers(1);
  console.log('Firebase Authentication cloud OK');
  const response = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(process.env.FIREBASE_WEB_API_KEY)}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({}),
    signal: AbortSignal.timeout(12000),
  });
  const result = await response.json();
  // Missing email is expected: validates Auth REST configuration without an account or password.
  if (response.status !== 400 || result.error?.message !== 'MISSING_EMAIL') {
    throw new Error('Kiểm tra Web API key và bật Email/Password trong Firebase Console.');
  }
  console.log('Auth REST API key OK (không tạo hoặc đăng nhập tài khoản)');
} catch (error) {
  // Admin SDK error objects can contain authorization headers. Never log the full object.
  const code = error.code;
  console.error(code ? `Cloud check failed (${code}). Kiểm tra quyền Firebase và thông tin xác thực; xem FIREBASE_CLOUD.md.` : error.message);
  process.exitCode = 1;
} finally {
  await db?.terminate();
}
