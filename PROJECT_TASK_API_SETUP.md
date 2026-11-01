# Project / Member / Task API setup

Phạm vi bản này: Project, Project Detail, thành viên và Tasks. Notification/FCM không được chỉnh sửa.

## Kiến trúc
- Flutter dùng Firebase Auth để đăng nhập và lấy Firebase ID token.
- Các thao tác ghi Project/Member/Task gọi REST API trong `server/`.
- Express xác thực token bằng Firebase Admin SDK, kiểm tra membership/role và ghi Firestore bằng Admin SDK.
- Flutter vẫn dùng Firestore snapshots để nhận cập nhật realtime. Các client đang mở cùng project sẽ nhận thay đổi mà không cần refresh.

## Chạy backend với Firebase cloud
1. Mở terminal tại thư mục `server`.
2. Tạo file `.env` từ `.env.cloud.example`, điền API key của Firebase Web App.
3. Cài Firebase Admin credentials bằng Application Default Credentials:
   `gcloud auth application-default login`
   Hoặc đặt `GOOGLE_APPLICATION_CREDENTIALS` trỏ tới service-account JSON nằm ngoài repository.
4. Đảm bảo `.env` có `USE_FIREBASE_EMULATORS=false`, `FIREBASE_PROJECT_ID=teamup-7ae78`, `PORT=3000`; không khai báo biến emulator trong cloud mode.
5. Chạy `npm ci`, sau đó `npm start`.
6. Với Android Emulator, Flutter mặc định gọi `http://10.0.2.2:3000/api`. Với web/desktop local, mặc định là `http://127.0.0.1:3000/api`.

Không commit `.env`, service-account JSON hoặc thông tin bí mật lên Git/ZIP chia sẻ.

## Kiểm tra nhanh
- Mở `http://127.0.0.1:3000/api/health`; phải trả `status: ok`.
- Đăng nhập TeamUp, tạo project, thêm member, tạo task.
- Mở Firebase Console > Firestore và xác nhận document được tạo dưới `projects/{projectId}` và các subcollection.
- Mở cùng project ở một phiên đăng nhập khác; Project/Member/Task phải tự cập nhật qua Firestore Listener.

## API routes
Xem `lib/API_CONTRACT.md`. Các thao tác ghi Project/Member/Task không còn ghi trực tiếp từ Flutter. Các thao tác chat/workspace và Notification không thuộc phạm vi thay đổi lần này.

## Lưu ý dữ liệu
- Xóa project gọi `recursiveDelete` ở backend và dọn `users/{uid}/projectMemberships/{projectId}` của từng thành viên.
- Không cần tạo collection mới thủ công; Firestore tạo document/subcollection khi backend ghi lần đầu.
- Realtime yêu cầu Firestore Rules cho phép thành viên đọc project/member/task và `projectMemberships`; không mở quyền ghi trực tiếp từ client.
