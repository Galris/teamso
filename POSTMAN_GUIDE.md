# Test API TeamUp bằng Postman

## 1. Chạy backend và Firebase local

Mở `start-teamup.cmd`, hoặc:

```powershell
cd 'C:\Lap_trinh_ung_dung\Quản lý task\server'
npm run local
```

Kiểm tra http://127.0.0.1:3000/api/health có `status: ok`, `authentication: Firebase Authentication`, `database: Cloud Firestore`.

## 2. Import vào Postman

Dùng Postman Desktop để gọi localhost. Bấm Import và chọn cả hai file:

- `server/postman/TeamUp.postman_collection.json`
- `server/postman/TeamUp.local.postman_environment.json`

Chọn environment **TeamUp Local** ở góc trên. `baseUrl` đã là `http://127.0.0.1:3000/api` (không thêm `/api` lần nữa).

## 3. Bấm Send theo thứ tự

| Request | Kết quả mong đợi |
| --- | --- |
| 00 Health | 200, backend Firebase hoạt động |
| 01 Signup | 201, tự tạo username/email test mới mỗi lần Send |
| 02 Signin | 200, tự lưu accessToken và refreshToken vào environment |
| 03 Me | 200, thông tin tài khoản vừa đăng ký |
| 04 Profile | 200, lưu tên/chuyên môn/điện thoại/bio |
| 05 Refresh | 200, tự cập nhật cặp token trong environment |
| 06 Change password | 200, tự đổi biến password và xóa token cũ |
| 07 Signin new password | 200, đăng nhập lại bằng mật khẩu mới |
| 08 Signout | 200, thu hồi phiên và xóa token khỏi environment |
| 09 Me with old token | 401: đây là kết quả ĐÚNG vì đã đăng xuất |
| 10 Invalid refresh | 401: đây là kết quả ĐÚNG vì token giả |

Mở phần Test Results/Scripts để xem các assertion xanh. Có thể chọn collection → Run để chạy toàn bộ theo thứ tự. Lần chạy Signup mới tạo tài khoản test mới, không tác động tài khoản cá nhân. Collection không tự xóa tài khoản test sau khi chạy.

Collection tự chuẩn bị Header `Content-Type: application/json`, Body raw JSON và Bearer token cho request được bảo vệ; bạn không cần copy token thủ công. File environment mẫu không chứa token thật. Đừng chia sẻ bản export environment có token đang dùng.

## 4. Hiểu cách tự tạo request

Ví dụ đăng nhập:

```http
POST http://127.0.0.1:3000/api/auth/signin
Content-Type: application/json
```

Body → raw → JSON:

```json
{"username":"username-ban-da-dang-ky","password":"mat-khau-cua-ban"}
```

Response có `accessToken`, `refreshToken`, `user`. Để xem hồ sơ:

```http
GET http://127.0.0.1:3000/api/users/me
Authorization: Bearer <accessToken>
```

Trong Postman, chọn Authorization → Bearer Token và điền `{{accessToken}}` khi dùng bộ environment này. Đăng ký xong phải đăng nhập: API signup không trả token.

Ví dụ cập nhật hồ sơ:

```http
PUT http://127.0.0.1:3000/api/users/profile
Authorization: Bearer <accessToken>
Content-Type: application/json
```

```json
{"displayName":"Nghi","major":"Flutter Developer","phone":"0912345678","bio":"Sinh viên phát triển ứng dụng TeamUp","avatarUrl":""}
```

## 5. Xem dữ liệu Firebase

- http://127.0.0.1:4000/auth: tài khoản Authentication.
- http://127.0.0.1:4000/firestore: `users/{uid}` và `usernames/{username}`.
- `npm run firebase:save` trong server để lưu snapshot ngay; app tự lưu mỗi phút khi chạy `npm run local`.

Đây là Firebase Emulator local vì chưa cấu hình project cloud thật.

## 6. Các lỗi hay gặp

- ECONNREFUSED/Could not get response: mở `npm run local`, kiểm tra cổng 3000; gọi API ở cổng 3000, không phải UI 4000 hoặc Flutter 5200.
- 400: xem message trong JSON; kiểm tra Body raw JSON, trường bắt buộc, mật khẩu >=8 ký tự.
- 401 trước khi đăng xuất: chạy request 02 hoặc 07 để nhận token, kiểm tra đã chọn TeamUp Local.
- 409: username/email đã có; dùng request 01 để tạo dữ liệu test mới.
- 429: quá nhiều lần gọi auth; chờ cửa sổ giới hạn hoặc chạy lại backend local.
- Sau khi đã đổi mật khẩu, đăng nhập bằng biến password đã cập nhật. Bộ collection tự xử lý việc này.
- Tài khoản nhập từ hệ thống cũ chưa hoàn tất chuyển mật khẩu cần đặt mật khẩu mới trong Auth Emulator UI trước khi đăng nhập; bộ Postman dùng tài khoản Firebase mới nên không vướng trường hợp này.
