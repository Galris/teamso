# Chat dự án / Profile / đăng nhập username

Nhánh local: feature/project-chat-username. Thay đổi cho PR Chat dự án, Profile và đăng nhập username.

## Chat
- Tab Chat mở danh sách từ TaskStore/ProjectService.watchMine của tài khoản hiện tại, không có phòng mẫu hoặc phòng chung tự mở.
- Mỗi dự án có một dòng: tên, tin mới nhất, người gửi và thời gian; tìm kiếm theo tên. Chỉ hiển thị Chưa có dự án khi tải xong và thực sự không có membership. Lỗi quyền/kết nối được hiển thị riêng.
- Chọn dòng mở projects/{projectId}/messages; mũi tên trong phòng trở lại danh sách. Tin mới nhất ở cuối; tối đa 50 tin gần nhất. Preview chỉ nghe một tin gần nhất/phòng.
- Khi membership bị xóa, hủy preview và phòng đang mở. Snapshot cũ của phòng trước không ghi đè phòng mới. Firestore rules hiện có vẫn bắt buộc là thành viên; không mở public rules.
- Không thêm số chưa đọc hoặc tin mẫu vì chưa có dữ liệu read-state.

## Profile
- Mũi tên Về trang chủ trả kết quả về MainScreen và chọn tab Home, kể cả khi mở Profile từ Chat.
- Thanh điều hướng dưới Profile dùng chung component với MainScreen, giữ badge thông báo và chọn đúng tab mà không tạo thêm shell.
- Bỏ avatar lớn, camera, avatar preview và trường URL trong form sửa. Giữ dữ liệu avatarUrl đã lưu để không xóa thông tin cũ.

## Login
- Nhận username hoặc email. Email vẫn đăng nhập Firebase Auth SDK trực tiếp.
- Username gọi POST /api/auth/signin với username/password. Backend tra UID claim, lấy email qua Admin Auth, kiểm tra profile username và xác minh mật khẩu trước khi trả profile/email.
- Flutter sau đó tạo phiên native bằng FirebaseAuth.signInWithEmailAndPassword; các stream Firestore vẫn dùng Firebase Auth hiện tại. Không có endpoint công khai tra username sang email và không ghi email vào public username claim.
- Backend chấp nhận cả dữ liệu username claim cũ và claim UID-only của signup native; dùng email chuẩn từ Auth record, không tin email trong claim.
- Cần giữ API chạy trên máy: cd server rồi npm run api; Android Emulator mặc định 10.0.2.2:3000/api. Username sẽ cần API online/local hoạt động, email không cần endpoint resolver.

## Kiểm tra
- flutter test --no-pub test/project_chat_list_test.dart test/username_login_test.dart: 8 test.
- Firebase Emulator sẵn sàng: trong server chạy node --test --test-concurrency=1 test/firebase.test.js test/messages.test.js: 9 test.
- flutter analyze --no-pub: chỉ còn warning unused_element có sẵn trong team_services_backup.dart, không có lỗi mới.
- Android build dùng JDK17 tại máy này. Không thay Firestore rules cloud hoặc thông tin xác thực của nhóm.
## Sửa tràn Task Board
- Bỏ PreferredSize ép 48px ở AppBar và dùng preferredSize của TabBar (bao gồm indicator 3px), sửa cảnh báo BOTTOM OVERFLOWED BY 1.00 PIXELS thay vì ẩn cảnh báo debug.
