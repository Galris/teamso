# TeamUp API contract – Project / Member / Task

All protected endpoints require `Authorization: Bearer <Firebase ID token>`. The Express backend verifies the token with Firebase Admin SDK and performs all writes with Admin SDK. Flutter continues to use Firestore snapshots for realtime reads.

## Projects
- `GET /api/projects` – list projects for current user.
- `POST /api/projects` – create project and leader membership. Body: `name`, `description?`, `tag?`, `coverUrl?`, `startDate?`, `endDate?`.
- `GET /api/projects/:projectId` – project detail.
- `PATCH /api/projects/:projectId` – update project (leader only).
- `DELETE /api/projects/:projectId` – recursively delete project and clean each member's `projectMemberships` index.
- `POST /api/projects/join` – body `{joinCode}`.

## Members
- `GET /api/projects/:projectId/members` – member profiles.
- `POST /api/projects/:projectId/members` – body `{username}` (leader only).
- `DELETE /api/projects/:projectId/members/:uid` – remove member (leader only; owner protected).
- `POST /api/projects/:projectId/leave` – current user leaves (owner cannot leave).

## Tasks
- `GET /api/projects/:projectId/tasks` – list project tasks.
- `POST /api/projects/:projectId/tasks` – create task (leader only).
- `PATCH /api/projects/:projectId/tasks/:taskId` – update task with role/assignee checks.
- `DELETE /api/projects/:projectId/tasks/:taskId` – delete task (leader only).

Writes update Firestore documents/subcollections. Firestore listeners on Flutter refresh Home, Project Detail, Task Board and member lists automatically. Notification endpoints and FCM are intentionally outside this scope.
