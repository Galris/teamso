# Workspace

Workspace đọc realtime từ Firestore, còn mọi thao tác ghi gọi Express API với Firebase ID token. Backend phải chạy để thêm/xóa tài liệu, lịch họp và bình chọn. Không triển khai riêng Flutter mới với backend cũ.

## Chạy

Trong `server/`, dùng cấu hình Firebase cloud hiện có và chạy `npm run api` (mặc định port 3000).

Ở gốc repo, chạy `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5202 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api`.

Android Emulator dùng API `http://10.0.2.2:3000/api`. Thiết bị thật cần địa chỉ backend truy cập được từ thiết bị.

## Quyền và dữ liệu

- Thành viên xem và thêm mục trong dự án; người tạo hoặc leader được xóa.
- Document URL chỉ nhận HTTP/HTTPS; bấm tài liệu có link để mở. Hủy không tạo mục, Lưu URL trống tạo tài liệu không link.
- Meetings mới lưu `startsAt` và `endsAt` dạng timestamp, đồng thời giữ label tương thích dữ liệu cũ.
- Votes cho 2–20 phương án khác nhau, mỗi phương án tối đa 120 ký tự; hỗ trợ nhiều lựa chọn, đổi hoặc bỏ hết phiếu.
- Votes cũ có ballots.option vẫn đọc được. Phiếu mới dùng ballots.options.
- Xóa vote đánh dấu đang xóa để chặn ghi đồng thời rồi xóa cả cây bằng Admin SDK. Nếu cleanup gặp lỗi có thể gọi lại DELETE cùng ID; không cho tạo phiếu mới vào parent đã xóa.
- Client chỉ đọc Workspace qua Firestore Rules. API kiểm tra token, membership, ownership và schema; không tin createdBy từ client.
- Không tự động dọn dữ liệu cũ/orphan không liên quan.

## Kiểm thử

Trong `server/`: `npm run test:workspace:emulators` chạy bộ Auth/Firestore Emulator tách biệt dùng project demo và không ghi lên cloud. Nếu Emulator đã chạy ở 9199/8180, dùng `npm run test:workspace`.

Ở gốc repo: `flutter test test/workspace_loading_test.dart`.

Kiểm tra thủ công: thêm tài liệu/link, Hủy ở bước URL, họp tương lai và giờ sai, tạo vote, chọn/đổi/bỏ hết phiếu, đồng bộ hai phiên, xác nhận xóa và reload.

## Rules

`firestore.rules` giữ nguyên các rule ngoài Workspace theo bản cloud trước khi sửa. Phần Workspace chỉ cho member đọc; mọi mutation đi qua backend. `firebase deploy --only firestore:rules --project teamup-7ae78 --config firebase.workspace.json` chỉ cập nhật Rules, không deploy Functions/Hosting. Cần kiểm tra lại Rules nếu nhóm sửa đồng thời trên Console.

I've set up prototype Security Rules to keep the data in Firestore safe. They are designed to be secure for Workspace because direct client writes are denied and authenticated backend routes validate membership, ownership and data bounds. However, you should review and verify them before broadly sharing your app. If you'd like, I can help you harden these rules.
