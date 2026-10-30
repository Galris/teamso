# Auth & Profile — mỗi thành viên chạy API riêng, dùng Firebase chung

Project Firebase của nhóm: **teamup-7ae78**. Luồng: Flutter → Express trên máy mỗi thành viên → Firebase Authentication + Firestore online chung.

Phạm vi phần Nghi: đăng ký, đăng nhập, phiên/token, xem/sửa Profile, đổi mật khẩu và đăng xuất. Tài liệu này không triển khai API Home, Task Board, Workspace, Chat hoặc Notify.

## 1. Chuẩn bị quyền và công cụ

- Node.js >=20.19, npm; Flutter để chạy ứng dụng.
- Được người quản lý thêm tài khoản Google vào project Firebase. Người chạy backend cần quyền thao tác Auth và Firestore (Firebase Admin cho thành viên phát triển được tin cậy); Firebase Viewer chỉ để xem, không đủ chạy API ghi dữ liệu.
- Authentication đã bật Email/Password; Firestore `(default)` đã tạo. Giữ rules chặn client trực tiếp trong `server/firestore.rules`: backend Admin SDK kiểm tra Bearer token và các trường được phép sửa.
- Mỗi người dùng thông tin xác thực riêng; không gửi file credential của Nghi cho cả nhóm.

## 2. Cài dependencies và tạo cấu hình

Mở terminal ở thư mục project vừa clone:

```powershell
cd server
npm ci
Copy-Item .env.cloud.example .env
```

Nếu `.env` đã tồn tại, sao lưu cấu hình của bạn trước khi thay. Mở `.env`, giữ `FIREBASE_PROJECT_ID=teamup-7ae78`, điền `FIREBASE_WEB_API_KEY` từ Firebase Console → Project settings → General → Your apps → TeamUp Backend → apiKey.

Không dùng `demo-api-key` trên cloud. Xóa hai biến `FIREBASE_AUTH_EMULATOR_HOST` và `FIRESTORE_EMULATOR_HOST` khỏi `.env` và môi trường terminal nếu đã thiết lập trước đó. Không đổi `.env.example` (mẫu Emulator) thành cấu hình cá nhân rồi commit.

## 3. Xác thực backend bằng tài khoản Google của mỗi người

Cách ưu tiên cho phát triển local là OAuth Application Default Credentials (ADC), không cần tạo private key service account dài hạn.

1. Cài Google Cloud CLI (`gcloud`) từ https://cloud.google.com/sdk/docs/install.
2. Trong Google Cloud Console của project `teamup-7ae78`, người quản lý cấu hình Google Auth Platform/OAuth consent nếu chưa có; ứng dụng External đang Testing phải thêm email thành viên vào Test users.
3. Tạo OAuth Client ID loại **Desktop app**, tải file client JSON, giữ ngoài repository.
4. Đăng nhập bằng chính tài khoản Google đã được cấp quyền:

```powershell
gcloud auth application-default login --client-id-file="C:/Users/YOUR_NAME/firebase-local/desktop-client.json" --scopes="https://www.googleapis.com/auth/cloud-platform,https://www.googleapis.com/auth/userinfo.email"
gcloud auth application-default set-quota-project teamup-7ae78
```

5. Trong `.env`, đặt `GOOGLE_APPLICATION_CREDENTIALS` thành đường dẫn tuyệt đối tới ADC mà lệnh login thông báo (Windows thường là `C:/Users/YOUR_NAME/AppData/Roaming/gcloud/application_default_credentials.json`). Đường dẫn trên macOS/Linux khác; dùng đường dẫn thực của máy đó.

Lưu ý Firebase Auth không chấp nhận user credentials từ OAuth client mặc định của gcloud; cần `--client-id-file` loại Desktop như trên. Chỉ `firebase login` cũng chưa tự thiết lập ADC cho Express.

Nếu nhóm đã có phương án service account được người quản lý cấp, có thể trỏ `GOOGLE_APPLICATION_CREDENTIALS` tới file JSON riêng ngoài repository thay cho ADC. Không commit hoặc chia sẻ private key qua GitHub/chat. Backend cần quyền Auth/Firestore; rules không giới hạn quyền của Admin SDK.

Tham khảo chính thức: https://firebase.google.com/docs/admin/setup#test_with_gcloud_end_user_credentials

## 4. Kiểm tra và chạy API

Trong `server/`:

```powershell
npm run firebase:check-cloud
npm run api
```

Lệnh check chỉ đọc, không tạo tài khoản hay ghi dữ liệu. Nó kiểm tra Firestore, quyền Admin Auth và Web API key; đăng nhập thực tế cần kiểm tra thêm bằng app/Postman. `npm run api` kiểm tra kết nối Firestore trước khi mở API `http://127.0.0.1:3000/api` và phục vụ web ở port 5200 nếu đã có `build/web`.

Không cần chạy Firebase Emulator khi dùng cloud. Không chạy hai API cùng port 3000. `EADDRINUSE` nghĩa là cần dừng phiên API cũ của chính bạn trước khi mở lại.

## 5. Chạy Flutter trên cùng máy

Mở terminal khác tại gốc project:

```powershell
flutter pub get
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Thay device ID bằng thiết bị của bạn từ `flutter devices`. Android Emulator dùng `10.0.2.2` để gọi API trên máy tính. Với Flutter web, có thể chạy:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

API hiện chỉ bind loopback, phù hợp emulator/web trên cùng máy. Điện thoại thật cần cấu hình mạng riêng; localhost của điện thoại không phải máy tính. Nếu chuyển từ Emulator sang cloud, đăng xuất và đăng ký tài khoản cloud mới; tài khoản Emulator không tự chuyển sang cloud.

## 6. Test Auth/Profile

- Đăng ký username chưa dùng → Firebase Authentication xuất hiện tài khoản; Firestore có `users/{uid}` và `usernames/{username}`.
- Đăng nhập → xem hồ sơ → sửa tên, ngành, phone, bio → tải lại để kiểm tra lưu dữ liệu.
- Đổi mật khẩu → đăng nhập lại bằng mật khẩu mới; đăng xuất.
- Postman: dùng collection/environment trong `server/postman/`; baseUrl vẫn là `http://127.0.0.1:3000/api`. Collection tạo tài khoản test và thay mật khẩu, nên chỉ dùng tài khoản test riêng, không dùng tài khoản thật.
- `npm test` luôn dùng project Emulator `demo-teamup-local`, không chạy test tự động lên cloud; cần khởi động Emulator riêng để chạy bộ test này.

Dữ liệu cloud dùng chung: không sửa/xóa hồ sơ của thành viên khác trong Console. API Home/Task/Chat của các thành viên khác không tự có chỉ vì Auth/Profile đã nối cloud.

## Git và bảo mật

Được commit: source, `.env.cloud.example` với placeholder, tài liệu. Không commit `.env`, ADC/OAuth client JSON, refresh/access token, private key, dữ liệu Firebase export, `node_modules` hoặc build output. Mẫu không chứa credential của bất kỳ thành viên nào. Việc đưa code lên GitHub không deploy API lên Internet hay cấp quyền Firebase tự động.
