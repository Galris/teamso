# TeamUp — Firebase Authentication + Cloud Firestore

## Kiến trúc

Flutter → Express REST API → Firebase Authentication (tài khoản, mật khẩu, ID/refresh token) và Cloud Firestore (hồ sơ, mapping username).

Flutter giữ `http` và `flutter_secure_storage`. API giữ các endpoint đăng ký, đăng nhập, refresh, đăng xuất, xem/sửa hồ sơ, đổi mật khẩu. Firestore không lưu password/hash.

Nhóm đã có Firebase cloud **`teamup-7ae78`** cho Auth/Profile. Mỗi thành viên chạy API local với database online: xem **[FIREBASE_CLOUD.md](FIREBASE_CLOUD.md)**. Tài liệu dưới đây dành cho chế độ Emulator riêng với project giả `demo-teamup-local`; dữ liệu hai chế độ tách biệt.

## Chạy

Mở `start-teamup.cmd`, hoặc:

```powershell
cd 'C:\Lap_trinh_ung_dung\Quản lý task\server'
npm run local
```

- App: http://127.0.0.1:5200
- API: http://127.0.0.1:3000/api/health
- Auth Emulator: http://127.0.0.1:4000/auth
- Firestore Emulator: http://127.0.0.1:4000/firestore

Script tự mở emulator nếu cần. Máy đã có Firebase CLI; script dùng Java đi kèm Android Studio và đường dẫn DOS ngắn của cùng thư mục dự án để tránh lỗi tên thư mục tiếng Việt.

Chạy riêng: terminal 1 `npm run emulators`; terminal 2 `npm run api`. Test backend: `npm test` khi emulator đang chạy. Test tạo/xóa đúng tài khoản test riêng, không xóa hồ sơ người dùng.

## Lưu dữ liệu local

Snapshot nằm ở `server/.local/firebase-data/`. `npm run local` tự lưu mỗi 60 giây. Trước khi đóng hoặc tắt máy, chạy `npm run firebase:save` để lưu ngay. Emulator sẽ import snapshot khi mở lại. Nếu tắt đột ngột, các thay đổi sau snapshot gần nhất có thể mất.

`.env`, `.local/` và private key đều được Git bỏ qua. Tài khoản cũ có cờ `passwordResetRequired` cần đặt mật khẩu mới trong Authentication Emulator UI trước khi đăng nhập. Không tự đổi mật khẩu của người dùng.

## Cơ chế API

- Access token là Firebase ID token (~1 giờ); refresh token do Firebase quản lý.
- Bearer token được xác minh bằng `verifyIdToken(token, true)`.
- Signout của backend thu hồi phiên trên tất cả thiết bị; dialog đã ghi rõ.
- Đổi mật khẩu kiểm tra mật khẩu cũ, cập nhật trong Firebase và thu hồi phiên.
- Hồ sơ ở `users/{uid}`; username unique được đặt chỗ/ánh xạ ở `usernames/{username}`.
- UI vẫn có dự án minh họa khi API chưa trả trường projects; dữ liệu mẫu không cấp quyền dự án.
- Flutter gọi Firestore thông qua Express/Admin SDK. Rules chặn client truy cập trực tiếp; API thực hiện kiểm tra token và whitelist field vì Admin SDK bypass rules.

## Firebase cloud dùng chung

Xem [FIREBASE_CLOUD.md](FIREBASE_CLOUD.md) để cấu hình tài khoản Google riêng, mẫu cloud và chạy API trên từng máy. Không cần tạo lại project; không tự chuyển dữ liệu Emulator lên cloud.

## Postman

Import hai file trong `server/postman/`, chọn environment TeamUp Local, chạy từ request 00 đến 10. Xem `POSTMAN_GUIDE.md` ở thư mục dự án để biết request/body/token và lỗi thường gặp.
