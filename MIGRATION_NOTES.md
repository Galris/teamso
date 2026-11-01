# TeamUp Firebase migration – updated patch

Firebase project: `teamup-7ae78`

## Implemented in this patch
- Firebase Authentication sign-up, email sign-in, session restoration, sign-out, password reset email and password change.
- Canonical profile document remains `users/{firebaseUid}`. Profile updates write to Firestore.
- Username claims at `usernames/{usernameLower}` contain only `uid` and `createdAt`; email is not exposed through the lookup document. Sign-in is email-based; username sign-in requires a trusted server resolver and is deliberately not performed by the client.
- Project and task data are stored in Firestore. `ProjectDetailScreen` uses Firestore streams and service methods, not REST project/task endpoints.
- `HomeScreen` and `TaskBoardScreen` consume a realtime `TaskStore` cache populated from Firestore streams; the demo projects and demo tasks were removed from this cache.
- Project membership uses `projects/{projectId}/members/{uid}` with exactly `role` and `joinedAt`; roles are `leader` and `member`.
- User-scoped membership index: `users/{uid}/projectMemberships/{projectId}`. This replaces the invalid collection-group query based on a `uid` field.
- Project creation writes the project, creator's leader membership, membership index and activity in one batch.
- Join-by-code, member-card profile lookup and project deletion use callable Cloud Functions.
- Adding members by username and removing members are implemented in `ProjectService` and exposed in project detail UI.
- Chat and Notifications remain on the existing REST API. `ApiClient` now sends Firebase ID tokens for authenticated REST calls when a Firebase user is signed in. The backend must verify those tokens using Firebase Admin SDK.
- Firestore Security Rules and composite-index configuration are included.
- `scripts/backfill_memberships.js` migrates existing member document IDs into user membership indexes, removes duplicate membership fields, strips email from username claims, and normalizes task assignees/statuses.

## Required setup
1. Add `cloud_functions` with `flutter pub add cloud_functions`.
2. Deploy `firestore.rules` and `firestore.indexes.json`.
3. Install and deploy the Node 20 functions in `functions/`.
4. Run the one-time Admin SDK backfill script if existing project member documents have not yet been indexed.
5. Configure the existing REST backend to verify Firebase ID tokens. Until that backend change is deployed, Chat and Notifications may return 401 even though Firebase sign-in and Firestore work.

## Important remaining limitations
- The uploaded ZIP contained only `lib/` source files plus notes. It did not include `pubspec.yaml`, `android/`, `ios/`, assets, tests or the Firebase CLI project configuration. Dependency compatibility, platform configuration, and a full APK build could not be validated.
- QR code rendering and camera scanning are not implemented in this patch because the archive did not include `pubspec.yaml` or establish QR/scanner dependencies. Join-by-code is implemented; QR can carry the same join code once the project's selected QR packages are added.
- Project update/delete methods exist in the service layer, but the uploaded UI did not expose all corresponding management controls.
- Username lookup is privacy-preserving (UID only), but claims are readable by signed-in users to support add-by-username. Do not add email or phone to username claim documents.
- The project owner is kept as a leader; role transfer is not implemented. A transfer workflow would need a trusted transaction/function that promotes the successor before changing ownerId.
- Workspace documents, votes, meetings, notifications and chat are outside this Project/Task migration scope; Workspace remains local UI state.
