# TeamUp

Ứng dụng Flutter quản lý dự án nhóm: công việc và duyệt bài, Workspace (tài liệu, bình chọn, lịch họp), chat nhóm/chat riêng, thông báo và tài khoản.

## Cập nhật code mới

Trong thư mục đã clone, lưu thay đổi cá nhân bằng commit hoặc stash trước khi chuyển nhánh. Không cần xóa thư mục cũ.

```powershell
git switch main
git pull --ff-only origin main
flutter pub get
cd server
npm ci
```

## Công cụ

- Flutter kèm Dart **>=3.13.2**. Bản kiểm thử giao diện dùng Flutter 3.47.8 / Dart 3.13.7.
- Node.js **>=22** và npm (Firebase Admin SDK 14 yêu cầu Node 22 trở lên).
- Android SDK, Android Emulator có Google Play Services; JDK **21** để build Android. Dùng `flutter devices` lấy ID máy giả lập của bạn.
- Firebase chung: **teamup-7ae78**, Firestore `(default)`. Người chạy API cần credential riêng được cấp quyền; việc pull code không tự cấp quyền Firebase.

## Chạy backend trên máy của mỗi thành viên

Tại `server/`, lần đầu sao chép `.env.cloud.example` thành `.env` và điền cấu hình theo [FIREBASE_CLOUD.md](FIREBASE_CLOUD.md). Nếu đã có `.env`, giữ cấu hình riêng của bạn. Không commit `.env`, ADC hoặc private key.

```powershell
cd server
npm ci
npm run firebase:check-cloud
npm run api
```

Giữ terminal API mở trong khi dùng app. API chạy ở `http://127.0.0.1:3000/api`. Mỗi thành viên có thể chạy backend riêng, cùng trỏ Firebase nhóm. Không dùng mẫu `.env.example` (Firebase Emulator) nếu muốn thấy dữ liệu cloud của nhóm.

## Chạy app

Mở terminal khác ở gốc repo. Thay đường dẫn JDK và device ID theo máy của bạn:

```powershell
$env:JAVA_HOME='C:\Program Files\Java\jdk-21'
flutter pub get
flutter devices
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Web trên cùng máy:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

Android Emulator dùng `10.0.2.2` để truy cập API của máy tính; không dùng `localhost` của emulator. Điện thoại thật cần backend HTTPS truy cập được từ thiết bị. Backend hiện bind loopback, không tự công khai lên Internet chỉ bằng cách đổi URL.

## Những chức năng cần backend mới

- Tạo/sửa/xóa dự án, task; giao việc, nộp bài và duyệt bài.
- Thêm/xóa tài liệu, lịch họp, bình chọn; thêm đáp án sau khi tạo vẫn giữ phiếu cũ.
- Gửi chat nhóm và chat riêng; thông báo tin nhắn và trạng thái đã xem.
- Thông báo trong app tự lưu trên Firebase qua các sự kiện API. Không cần nhập thông báo tay trên Console.

Để nhận **push Android**, vào **Tài khoản → Tài khoản & cài đặt → Thông báo đẩy**, bật và cấp quyền hệ điều hành. Web chỉ có thông báo trong app; chưa bật Web Push. Quyền là riêng trên từng thiết bị. Không deploy các trigger thông báo cũ trong `functions/index.js` cùng luồng API mới vì có thể gửi trùng.

## Chat mới

Ở tab Chat, bấm **Trò chuyện mới**:

- **Chat nhóm theo dự án:** chọn dự án đang tham gia, hoặc tạo dự án mới. Thành viên cùng dự án dùng chung phòng chat.
- **Nhắn riêng:** nhập username chính xác của người nhận. Cùng cặp tài khoản dùng lại một cuộc trò chuyện, không tạo trùng. Tin nhắn chỉ hai người được truy cập qua API.
- Chat riêng lưu tại `directChats` trên Firestore bằng backend Admin SDK; không cần mở quyền client hoặc tạo dữ liệu tay. Cập nhật danh sách/tin nhắn qua API mỗi 3 giây khi màn hình hoạt động; không phải Firestore realtime listener. Có tải tin cũ hơn.
- Chỉ khi gửi tin mới thì người nhận có thông báo. Mở/tạo phòng trống không gửi thông báo.

## Kiểm thử

```powershell
flutter analyze
flutter test
cd server
npm run test:unit
npm run test:workspace:emulators
```

Bộ integration chạy project demo `demo-teamup-workspace`, Auth 9199, Firestore 8180, tách khỏi dữ liệu thật. Cần Firebase CLI và Java 21. Xem thêm [WORKSPACE.md](WORKSPACE.md) và [NOTIFICATIONS.md](NOTIFICATIONS.md).

Push code lên GitHub chỉ cập nhật mã nguồn. Thành viên cần pull code, cài dependencies và chạy **cả backend mới lẫn app mới** theo hướng dẫn trên để dùng cùng chức năng. Firebase Rules, backend hosting và khóa ký phát hành không được tự deploy bằng `git push`.
