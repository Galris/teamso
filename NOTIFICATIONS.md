# Thông báo TeamUp

## Phạm vi

- Trong app (Android và web): hộp thư realtime `users/{uid}/notifications`, huy hiệu chưa đọc, xem chi tiết, đọc một/tất cả, lọc Công việc và Workspace.
- Android: Firebase Cloud Messaging, nút Bật/Tắt trong Tài khoản & cài đặt, cấp quyền Android 13+, token refresh, thu hồi token khi tắt/đăng xuất. Bấm push mở tab Thông báo; khi app đang mở hiện SnackBar có nút Xem.
- Không bật Web Push, không tạo VAPID key, chưa hỗ trợ APNs/iOS.

## Sự kiện tạo thông báo

- Leader thêm thành viên bằng username: chỉ thành viên mới nhận “Bạn đã được thêm vào dự án”, kèm tên dự án. Membership, chỉ mục và inbox được ghi cùng transaction; thêm trùng/đồng thời không gửi lặp. Push gửi sau commit qua FCM nếu thành viên đã đăng ký thiết bị.
- Tự tham gia bằng mã: người vừa tham gia nhận thông báo xác nhận. Không gửi bù cho các thành viên đã có trước khi tính năng được thêm.
- Tạo task hoặc giao thêm người thực hiện: người mới được giao nhận thông báo (kể cả tự giao).
- Sửa task/trạng thái: người thực hiện hiện còn là thành viên và owner, bỏ người vừa thao tác và tránh gửi trùng với thông báo giao việc.
- Tạo tài liệu/lịch họp/bình chọn: mọi thành viên hiện tại của dự án, gồm thành viên vừa được thêm/tham gia, nhận thông báo; bỏ người tạo. Danh sách lấy từ members, memberIds và owner, khử trùng UID. Người ngoài dự án hoặc đã bị xóa/rời nhóm không nhận sự kiện mới. Thông báo tài liệu có biểu tượng và nhãn Tài liệu riêng, nằm trong bộ lọc Workspace.
- Chưa có bộ lập lịch nhắc deadline tự động. Bộ lọc Deadline vẫn đọc được dữ liệu loại deadline/reminder có sẵn.

Thông báo ghi trong cùng batch/transaction với task/Workspace; FCM gửi sau commit và lỗi gửi không hủy dữ liệu. Push hiện là best effort, chưa có hàng đợi retry bền vững nếu backend dừng đúng lúc gửi. Backend phải đang chạy để nhận sự kiện API và gửi FCM. Các thay đổi trực tiếp từ Firebase Console không tự sinh thông báo.

Không deploy các trigger thông báo cũ trong `functions/index.js` đồng thời với luồng mới để tránh trùng thông báo. Backend Express là nguồn sự kiện của bản này.

## Thiết bị và quyền truy cập

`PUT /api/notifications/device` và `DELETE /api/notifications/device` yêu cầu Firebase ID token. Body `{token}`; UID lấy từ token xác thực, không nhận từ client. Token lưu tại `_pushDevices/{sha256(token)}`, chỉ Admin SDK truy cập (Firestore Rules hiện tại không cho client đọc/ghi collection này). Không đặt token trong hồ sơ users vốn có quyền đọc rộng.

Người dùng chỉ đọc được inbox của mình và chỉ cập nhật trường `read`. Không sửa hoặc deploy Rules trong đợt Thông báo này.

Android khai báo POST_NOTIFICATIONS và tắt FCM auto-init mặc định. Người dùng bật Thông báo đẩy trong Tài khoản & cài đặt để cấp quyền/đăng ký. Tắt sẽ gỡ đăng ký backend, hủy token và tắt auto-init; không tự bật lại khi mở app. SDK hiện dùng registration token tương thích Admin SDK v13; có ignore deprecation có chủ đích cho getToken/onTokenRefresh/deleteToken thay vì FID API mới.

## Chạy và kiểm tra

```powershell
cd C:\Users\admin\Documents\teamup\server
npm run api
```

```powershell
cd C:\Users\admin\Documents\teamup
$env:JAVA_HOME='C:\Program Files\Java\jdk-21'
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Điện thoại thật cần trỏ API_BASE_URL đến backend mà điện thoại truy cập được (bản phát hành dùng HTTPS); localhost/10.0.2.2 là cấu hình máy/emulator. Vào Tài khoản → Tài khoản & cài đặt → Thông báo đẩy, cấp quyền, đưa app xuống nền rồi dùng tài khoản khác giao việc hoặc tạo lịch họp/bình chọn.

Kiểm thử emulator Firebase hiện dùng demo-teamup-workspace, Auth 9199, Firestore 8180. Khi emulator đã chạy:

```powershell
cd C:\Users\admin\Documents\teamup\server
npm run test:notifications
npm run test:workspace
```

Đã kiểm tra 8 nhóm notification integration tests (FCM mock, Firestore/Auth thật trên emulator), gồm thêm thành viên/kiểm tra quyền/thêm đồng thời/tham gia bằng mã/FCM lỗi và phát tài liệu/vote/lịch họp cho toàn bộ thành viên hiện tại; 5 nhóm Workspace, Flutter analyzer và regression widget test. Đã thử UI web bằng fixture trong chính inbox tài khoản đang kiểm thử: realtime, badge, mở chi tiết, trạng thái đọc bền vững, lọc Workspace, đọc tất cả, chưa đọc; fixture đã dọn. Thông báo thành viên có loại và bộ lọc Dự án riêng.

API FCM cloud V1 đã bật và dry-run xác nhận gọi được dịch vụ (bị từ chối đúng với token giả). Chưa xác nhận giao push lên một thiết bị Android thật. Đã xác định nguyên nhân lỗi build ban đầu: Java 25/JBR trả File.canWrite=false với các thư mục SDK/project, còn Java 21 trả đúng true. Dùng JAVA_HOME trỏ JDK 21 như lệnh trên; không cần hạ Gradle hay sửa quyền thư mục. Java shim mặc định trên PATH của máy cũng bị treo, nên cần đặt JAVA_HOME rõ ràng khi chạy từ terminal.

## Cập nhật chạy Android giả lập

Đã build thành công bằng JDK 21, cài cập nhật APK bằng `adb install -r` và khởi chạy `com.example.teamup_app/.MainActivity` trên emulator-5554 (Android 17/API 37). Bản build dùng API_BASE_URL=http://10.0.2.2:3000/api. Emulator có Google Play Services. Không cần tạo Web Push key.

## Chi tiết dự án và duyệt công việc

- Thông báo mới lưu projectName, taskTitle, actorName và trạng thái công việc; push Android kèm tên dự án.
- Danh sách và chi tiết hiển thị tên dự án. Thông báo cũ tra tên từ danh sách dự án hiện có; nếu dự án không còn truy cập được thì hiển thị tên đã lưu hoặc mã dự án.
- Khi gửi bài sang pending_review: các leader hiện tại và owner (trừ người gửi) nhận loại review_required / Cần bạn duyệt. Người được giao nhận pending_review / Chờ duyệt, gồm người vừa gửi để xác nhận đã nộp; reviewer không nhận hai loại trùng nhau.
- Duyệt hoàn thành gửi completed; yêu cầu sửa gửi revision_required kèm nhận xét cho người được giao hiện còn trong dự án, trừ người thao tác.
- Không gửi bù thông báo trạng thái cho sự kiện cũ. Kiểm thử dùng Firebase Emulator, không tạo thông báo trong dữ liệu cloud thật.

## Tin nhắn dự án

- ChatService gửi qua POST /api/projects/:projectId/messages với Firebase ID token; backend xác minh membership và lấy danh tính người gửi từ token/hồ sơ.
- Tin nhắn và inbox loại chat được ghi cùng transaction. Mọi thành viên trong members và owner nhận thông báo, trừ người gửi; không lấy UID bên ngoài từ client.
- Thông báo có người gửi, tên dự án và tối đa 160 ký tự nội dung xem trước. Tin nhắn gốc vẫn lưu đầy đủ tối đa 2000 ký tự. Có bộ lọc Tin nhắn trong app và push Android qua FCM.
- App vẫn đọc tin nhắn realtime từ Firestore. Cần chạy backend mới và cập nhật app của người gửi; app cũ ghi trực tiếp Firestore không đi qua luồng thông báo này.

## Số tin nhắn chưa đọc

- Huy hiệu tab Chat là tổng số tin nhắn chưa đọc trong các dự án hiện còn tham gia; mỗi nhóm có số riêng. Không tính tin do chính mình gửi.
- Dùng chatRead riêng trên thông báo chat, độc lập với read của hộp thư thông báo. Đọc tất cả thông báo không đánh dấu đã xem cuộc trò chuyện.
- Khi nhóm đang mở, app ở foreground và tab Chat đang hiển thị, API đánh dấu đã đọc đến tin mới nhất đã tải. Tin mới hơn mốc đó vẫn chưa đọc; không tự đánh dấu khi đang ở tab khác hoặc app ở nền.
- Trạng thái lưu trên Firestore qua API, có hiệu lực sau khi mở lại app/đăng nhập thiết bị khác. Các tin cũ trước khi bật luồng tạo thông báo chat không được đếm bù.

## Nhắn riêng

- Tin nhắn riêng có `conversationId`, lưu tại `directChats/{id}/messages`; mọi thao tác đọc/ghi kiểm tra hai thành viên qua API.
- Inbox dùng type `chat`, `chatRead` riêng để đếm huy hiệu Chat; không cần `projectId`. Mở cuộc trò chuyện đánh dấu đọc đến mốc tin đã tải, không xóa thông báo mới hơn.
- Quyền bật push nằm trong Tài khoản & cài đặt; trang Thông báo không còn hàng bật/tắt.
