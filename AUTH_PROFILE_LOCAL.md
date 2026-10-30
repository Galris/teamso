# TeamUp Auth & Profile

Backend hiện dùng Firebase Authentication + Cloud Firestore.

- Chạy local: mở `start-teamup.cmd`, hoặc `cd server` và `npm run local`.
- Dùng Firebase cloud chung `teamup-7ae78`, mỗi thành viên chạy backend riêng: xem `FIREBASE_CLOUD.md` và `server/.env.cloud.example`.
- Chạy Emulator riêng: xem `FIREBASE_LOCAL.md`.
- Test API bằng Postman: xem `POSTMAN_GUIDE.md`; import Collection và Environment trong `server/postman/`.
- Test backend: `cd server` rồi `npm test` (emulator đang chạy).
- Test Flutter: `dart analyze lib test`, `flutter test`.
- Build web trên thư mục tiếng Việt: `flutter build web --no-pub --no-tree-shake-icons`.

Không commit/push/PR tự động. Không đưa .env, private key, token hoặc snapshot dữ liệu lên Git.
