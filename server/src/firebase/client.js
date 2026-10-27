import 'dotenv/config';
import { initializeApp, getApps, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

export const firebaseProjectId = process.env.FIREBASE_PROJECT_ID;
export const usingEmulators = process.env.USE_FIREBASE_EMULATORS === 'true';
if (!firebaseProjectId) throw new Error('Thiếu FIREBASE_PROJECT_ID trong server/.env.');
if (usingEmulators) {
  if (!firebaseProjectId.startsWith('demo-')) throw new Error('Local emulator phải dùng project demo- để tránh gọi nhầm cloud.');
  for (const key of ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST']) {
    if (!/^(127\.0\.0\.1|localhost):\d+$/.test(process.env[key] ?? '')) throw new Error(`${key} phải là localhost:port.`);
  }
} else {
  if (firebaseProjectId.startsWith('demo-') || process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST) throw new Error('Cấu hình Firebase cloud/emulator đang bị trộn.');
}
const app = getApps()[0] ?? initializeApp({ projectId: firebaseProjectId, ...(!usingEmulators ? { credential: applicationDefault() } : {}) });
export const auth = getAuth(app);
export const db = getFirestore(app);

export class FirebaseRequestError extends Error {
  constructor(message, status = 401, code = 'FIREBASE_AUTH_ERROR') { super(message); this.status = status; this.code = code; }
}

export async function firebaseRest(path, body, { secureToken = false } = {}) {
  const key = process.env.FIREBASE_WEB_API_KEY;
  if (!key) throw new Error('Thiếu FIREBASE_WEB_API_KEY.');
  const service = secureToken ? 'securetoken.googleapis.com' : 'identitytoolkit.googleapis.com';
  const base = usingEmulators ? `http://${process.env.FIREBASE_AUTH_EMULATOR_HOST}/${service}` : `https://${service}`;
  let response;
  try {
    response = await fetch(`${base}/v1/${path}?key=${encodeURIComponent(key)}`, {
      method: 'POST', headers: { 'Content-Type': secureToken ? 'application/x-www-form-urlencoded' : 'application/json' },
      body: secureToken ? new URLSearchParams(body).toString() : JSON.stringify(body), signal: AbortSignal.timeout(12000),
    });
  } catch { throw new FirebaseRequestError('Không kết nối được Firebase. Vui lòng thử lại.', 503, 'FIREBASE_UNAVAILABLE'); }
  const data = await response.json();
  if (!response.ok) {
    const reason = data.error?.message ?? 'INVALID_CREDENTIALS';
    if (/TOO_MANY_ATTEMPTS/.test(reason)) throw new FirebaseRequestError('Quá nhiều lần thử. Vui lòng thử lại sau.', 429, 'RATE_LIMIT');
    if (/OPERATION_NOT_ALLOWED|CONFIGURATION_NOT_FOUND|API_KEY_INVALID/.test(reason)) throw new FirebaseRequestError('Firebase chưa cấu hình Email/Password hoặc API key chưa đúng.', 503, 'FIREBASE_CONFIGURATION');
    throw new FirebaseRequestError('Thông tin đăng nhập không đúng hoặc phiên đã hết hạn.');
  }
  return data;
}

export async function profileFor(uid) {
  const snapshot = await db.collection('users').doc(uid).get();
  if (!snapshot.exists) throw new FirebaseRequestError('Không tìm thấy hồ sơ tài khoản.', 401, 'PROFILE_NOT_FOUND');
  return publicProfile(uid, snapshot.data());
}
export function publicProfile(uid, data) {
  const result = { id: uid, username: data.username, email: data.email, displayName: data.displayName,
    avatarUrl: data.avatarUrl ?? '', major: data.major ?? '', phone: data.phone ?? '', bio: data.bio ?? '',
    createdAt: data.createdAt?.toDate?.().toISOString() ?? data.createdAt ?? null,
    updatedAt: data.updatedAt?.toDate?.().toISOString() ?? data.updatedAt ?? null };
  for (const key of ['studentId', 'className', 'projects']) if (data[key] !== undefined) result[key] = data[key];
  return result;
}
