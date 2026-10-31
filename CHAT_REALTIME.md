# Chat thời gian thực — Firestore qua Express

## Hàm Firestore

`server/src/firebase/messages.js` xuất:

- `await sendMessage(text, userId, userName, userPhoto)`: tạo document tự sinh ID trong `messages`, lưu `text`, `uid`, `name`, `profilePicUrl`, `timestamp: FieldValue.serverTimestamp()`. Bỏ khoảng trắng đầu/cuối, giới hạn 1–2000 ký tự.
- `const unsubscribe = listenToMessages(callback, onError)`: dùng `orderBy('timestamp', 'asc').limitToLast(50).onSnapshot(...)`; callback nhận mảng có `id`, nội dung và timestamp ISO để truyền JSON. Gọi `unsubscribe()` khi không dùng nữa.

Đây là phòng chat CHUNG cho tất cả tài khoản TeamUp đã đăng nhập. Chưa phân quyền thành viên/tách phòng theo dự án. Không dùng cho nội dung riêng của dự án nếu chưa bổ sung thiết kế phòng và kiểm tra membership.

## API và Flutter

- `POST /api/messages`, Bearer token, JSON `{ "text": "Xin chào" }` → 201 `{ "id": "..." }`. Người gửi được lấy từ token và hồ sơ trong DB; client không quyết định uid/name.
- `GET /api/messages/stream`, Bearer token → Server-Sent Events, mỗi frame `data: {"messages":[...]}\n\n` là một snapshot đầy đủ tối đa 50 tin. Heartbeat 15s, đóng sau 60s để client kết nối lại và kiểm tra phiên. Khi rớt mạng client thử lại sau 2s, giữ nội dung chưa gửi khi lỗi.
- `lib/services/chat_service.dart` dùng HTTP stream của API để nhận realtime. `onSnapshot` thực sự chạy trên Node.js Admin SDK, không cần thêm Firebase Auth SDK vào Flutter. Stream hủy khi Chat dispose, đăng xuất reset navigator và epoch ngăn dùng dữ liệu phiên cũ.
- Giao diện Chat bỏ tin mẫu, phân biệt tin của mình theo UID; có loading, lỗi kết nối và trạng thái đang gửi. Chưa có push notification, trạng thái online hay bot tự động.
- Giữ Firestore rules chặn truy cập client trực tiếp. Backend chịu trách nhiệm kiểm tra auth vì Admin SDK bypass rules. Giới hạn gửi 30 tin/phút/IP. Không cần mở public rules hoặc thêm composite index cho query một trường hiện tại.

## Chạy và test

Trong `server`: `npm run api` (dừng API cũ cùng port trước). Flutter: `flutter run -d <device-id>`; Android Emulator mặc định gọi `http://10.0.2.2:3000/api`.

Đăng nhập 2 tài khoản trên 2 app đang chạy API tương ứng hoặc sửa endpoint tới server chung; mở tab Chat, gửi từ một phía và kiểm tra phía còn lại cập nhật mà không reload. Tin xuất hiện trong Firestore Console → messages. API vẫn chạy local: điện thoại thật/máy khác không gọi được loopback của máy bạn nếu chưa cấu hình mạng.

Test tự động dùng Emulator, không dùng cloud: khởi động Firebase Emulator rồi chạy `node --test --test-concurrency=1 test/messages.test.js` trong server. Test tự dọn collection/account riêng, không xóa tin thật. Kiểm tra validation/server timestamp, cửa sổ 50 tin đúng thứ tự, 2 listeners, API SSE có auth và chống giả mạo.

Firestore online tính lượt đọc/ghi theo usage; listener mỗi client và reconnect có thể tăng lượt đọc. Không tự tạo tin mẫu trên cloud.