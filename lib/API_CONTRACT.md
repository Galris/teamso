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
  - Backend phải, sau khi xóa `projects/{id}/members/{uid}` và chỉ mục `projectMemberships`, gỡ người rời khỏi `assigneeIds` của các task trong dự án và **tạo thông báo cho leader (`ownerId`)** tại `users/{ownerId}/notifications`:
    `{type: 'member_left', title: 'Thành viên đã rời dự án', body: '<tên> đã rời khỏi dự án <tên dự án>', projectId, projectName, actorName: '<tên>', read: false, createdAt: serverTimestamp()}`.
    Ví dụ (Express + Admin SDK):
    ```js
    router.post('/projects/:projectId/leave', async (req, res) => {
      const { projectId } = req.params; const uid = req.user.uid;
      const projectRef = db.doc(`projects/${projectId}`);
      const project = (await projectRef.get()).data();
      if (!project) return res.status(404).json({ message: 'Không tìm thấy dự án.' });
      if (project.ownerId === uid) return res.status(400).json({ message: 'Leader không thể rời dự án.' });
      const me = (await db.doc(`users/${uid}`).get()).data() || {};
      const name = me.displayName || me.username || 'Một thành viên';
      const batch = db.batch();
      batch.delete(projectRef.collection('members').doc(uid));
      batch.delete(db.doc(`users/${uid}/projectMemberships/${projectId}`));
      const tasks = await projectRef.collection('tasks').where('assigneeIds', 'array-contains', uid).get();
      tasks.forEach((t) => batch.update(t.ref, { assigneeIds: FieldValue.arrayRemove(uid) }));
      batch.set(db.collection(`users/${project.ownerId}/notifications`).doc(), {
        type: 'member_left', title: 'Thành viên đã rời dự án',
        body: `${name} đã rời khỏi dự án ${project.name}`,
        projectId, projectName: project.name, actorName: name,
        read: false, createdAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
      res.json({ ok: true });
    });
    ```

## Tasks
- `GET /api/projects/:projectId/tasks` – list project tasks.
- `POST /api/projects/:projectId/tasks` – create task (leader only).
- `PATCH /api/projects/:projectId/tasks/:taskId` – update task with role/assignee checks.
- `DELETE /api/projects/:projectId/tasks/:taskId` – delete task (leader only).

## Auth (public – không cần Bearer token)
- `POST /api/auth/signin` – body `{username, password}`; backend xác minh mật khẩu rồi trả `{user: {id, email, ...}}`. App dùng `user.email` để đăng nhập Firebase Auth (đăng nhập bằng **email** không qua API).
- `POST /api/auth/refresh` – body `{refreshToken}` → `{accessToken, refreshToken}` (chỉ dùng cho phiên không-Firebase, legacy).
- `POST /api/auth/signout` – body `{refreshToken}` (legacy).

## Workspace (collection = `documents` | `meetings` | `votes`)
- `POST /api/projects/:projectId/workspace/documents` – body `{label, url?}` (url rỗng hoặc http/https).
- `POST /api/projects/:projectId/workspace/meetings` – body `{label, meetUrl, startsAt, endsAt}` (`meetUrl` = link họp, bắt buộc, http/https) (ISO‑8601 UTC).
- `POST /api/projects/:projectId/workspace/votes` – body `{question, options: string[2..20 (hoặc tới 60 khung giờ khi kind=meeting)], kind?}`. `kind` = `general` (mặc định, **không gửi**) hoặc `meeting` (chọn khung giờ rảnh kiểu When2meet; backend cần lưu `kind` vào document vote).
- `PUT /api/projects/:projectId/workspace/votes/:voteId/ballot` – body `{options: number[]}` (chỉ số phương án/khung giờ; mảng rỗng = bỏ phiếu).
- `DELETE /api/projects/:projectId/workspace/:collection/:id`.

Phiếu bầu lưu ở `projects/{id}/workspace…/votes/{voteId}/ballots/{uid}` (`options: number[]`). App tự tổng hợp `counts`, `totalVotes`, `myVotes`, `voters` từ các ballot qua Firestore snapshot.

## Users (hiện chưa có màn hình nào gọi – `user_service.dart` là code dự phòng)
- `GET /api/users/me`, `PATCH /api/users/profile`, `POST /api/users/change-password`, `POST /api/users/avatar` (multipart), `DELETE /api/users/me`.

## Tìm tài khoản để mời thành viên
Không qua API: `ProjectService.searchAccounts` truy vấn Firestore `users` theo tiền tố `username` (hoặc `email` khi có `@`). Firestore rules phải cho phép người dùng đã đăng nhập đọc collection này; nếu không, chuyển sang một endpoint `GET /api/users/search?q=`.

## Cấu hình địa chỉ API ở client
Mặc định: Android emulator `http://10.0.2.2:3000/api`, nền tảng khác `http://127.0.0.1:3000/api`. **Máy thật** phải truyền địa chỉ LAN/HTTPS:
`flutter run --dart-define=API_BASE_URL=http://<IP-LAN>:3000/api`. Backend phải listen `0.0.0.0`; Android 9+ cần `usesCleartextTraffic` cho HTTP (hoặc dùng HTTPS).

Writes update Firestore documents/subcollections. Firestore listeners on Flutter refresh Home, Project Detail, Task Board and member lists automatically. Notification endpoints and FCM are intentionally outside this scope.


## Ẩn dự án khỏi Home
Lưu ở Firestore `users/{uid}.hiddenProjectIds` (mảng id dự án), Flutter ghi trực tiếp bằng `set(..., merge)` + `arrayUnion/arrayRemove`. Firestore rules phải cho chủ tài khoản ghi trường này, ví dụ: `allow update: if request.auth.uid == uid && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['hiddenProjectIds']);` (gộp với rule hiện có của `users/{uid}`).
