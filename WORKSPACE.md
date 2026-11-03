# Workspace

Workspace đọc realtime từ Firestore, còn mọi thao tác ghi gọi Express API với Firebase ID token. Backend phải chạy để thêm/xóa tài liệu, lịch họp và bình chọn. Không triển khai riêng Flutter mới với backend cũ.

## Chạy

Trong `server/`, dùng cấu hình Firebase cloud hiện có và chạy `npm run api` (mặc định port 3000).

Ở gốc repo, chạy `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5202 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api`.

Android Emulator dùng API `http://10.0.2.2:3000/api`. Thiết bị thật cần địa chỉ backend truy cập được từ thiết bị.

## Quyền và dữ liệu

- Thành viên xem và thêm mục trong dự án; người tạo hoặc leader được xóa.
- Document URL chỉ nhận HTTP/HTTPS; bấm tài liệu có link để mở. Hủy không tạo mục, Lưu URL trống tạo tài liệu không link.
- `lib/utils/doc_kind.dart` nhận diện loại link (Docs/Sheet/Slides/Form/Drive/PDF, Meet/Zoom/Teams, Notion/Figma/Canva/Miro/GitHub) để hiển thị icon, nhãn và nút Mở. Link không phân loại được hiện là Liên kết.
- Meetings mới bắt buộc có `meetUrl` HTTP/HTTPS (bước "Link vào cuộc họp"); thiếu link thì backend trả 400 và client không tạo lịch họp. `label` chỉ còn tên cuộc họp, ngày giờ lấy từ `startsAt`/`endsAt`; `TaskStore.meetingTitle` cắt hậu tố ngày giờ của dữ liệu cũ. Cuộc họp cũ chưa có link vẫn đọc và hiển thị bình thường.
- Votes có hai loại, gửi kèm `kind`: `general` (2–20 phương án, mỗi phương án tối đa 120 ký tự) và `meeting` (tối đa 60 khung giờ tự sinh từ dải ngày + giờ bắt đầu/ kết thúc + độ dài ô 30/60/90 phút). Dữ liệu cũ không có `kind` được coi là `general`. Một form tạo bình chọn dùng `showVoteCreateDialog`, kết quả meeting hiển thị bằng lưới `MeetingVoteGrid` (dòng = khung giờ, cột = thành viên).
- Votes cũ có ballots.option vẫn đọc được. Phiếu mới dùng ballots.options.
- Xóa vote đánh dấu đang xóa để chặn ghi đồng thời rồi xóa cả cây bằng Admin SDK. Nếu cleanup gặp lỗi có thể gọi lại DELETE cùng ID; không cho tạo phiếu mới vào parent đã xóa.
- Client chỉ đọc Workspace qua Firestore Rules. API kiểm tra token, membership, ownership và schema; không tin createdBy từ client.
- Không tự động dọn dữ liệu cũ/orphan không liên quan.
- Màn hình Lịch trình (`task_calendar.dart`) chỉ đánh dấu hạn dự án (`endDate`) và ngày có lịch họp; lịch họp lấy qua `TaskStore.meetings` (stream `watchMeetings` cho từng dự án).

## Kiểm thử

Trong `server/`: `npm run test:workspace:emulators` chạy bộ Auth/Firestore Emulator tách biệt dùng project demo và không ghi lên cloud. Nếu Emulator đã chạy ở 9199/8180, dùng `npm run test:workspace`.

Ở gốc repo: `flutter test test/workspace_loading_test.dart test/workspace_vote_slots_test.dart` (bài sau kiểm tra sinh khung giờ họp và phân loại link).

Kiểm tra thủ công: thêm tài liệu/link, Hủy ở bước URL, họp tương lai và giờ sai, bắt buộc nhập link Meet/Zoom/Teams, tạo vote thường thêm/xóa phương án, tạo vote khung giờ họp, tích/bỏ tích và đổi phiếu, đồng bộ hai phiên, xác nhận xóa và reload.

## Rules

`firestore.rules` giữ nguyên các rule ngoài Workspace theo bản cloud trước khi sửa. Phần Workspace chỉ cho member đọc; mọi mutation đi qua backend. `firebase deploy --only firestore:rules --project teamup-7ae78 --config firebase.workspace.json` chỉ cập nhật Rules, không deploy Functions/Hosting. Cần kiểm tra lại Rules nếu nhóm sửa đồng thời trên Console.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for Workspace because direct client writes are denied and authenticated backend routes validate membership, ownership and data bounds. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.
