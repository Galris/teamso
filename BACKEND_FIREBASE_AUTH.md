# REST backend compatibility with Firebase Authentication

The Flutter client now sends `Authorization: Bearer <Firebase ID token>` for protected REST calls whenever a Firebase user is signed in. This preserves the existing Chat and Notification REST endpoints, but the backend must stop treating that token as the old custom access token.

For a Node.js backend, verify the token with Firebase Admin SDK before handling a protected request:

```js
const admin = require('firebase-admin');

async function requireFirebaseUser(req, res, next) {
  const header = req.headers.authorization || '';
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) return res.status(401).json({ message: 'Unauthenticated' });
  try {
    req.firebaseUser = await admin.auth().verifyIdToken(match[1]);
    req.userId = req.firebaseUser.uid;
    return next();
  } catch (_) {
    return res.status(401).json({ message: 'Invalid Firebase ID token' });
  }
}
```

Use `req.userId` as the canonical Firebase UID. Do not trust a UID supplied in the request body. Chat and notification authorization must verify that this UID belongs to the requested project. Remove the old refresh-token dependency for Firebase-authenticated requests. The Flutter `ApiClient` retains the old refresh mechanism only as a fallback when there is no Firebase user.

The backend must not return other users' email addresses as part of project member cards. The callable `getProjectMembers` function returns only `uid`, `username`, `displayName`, `avatarUrl`, `major`, `bio`, `role` and `joinedAt`.
