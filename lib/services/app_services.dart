import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'api_client.dart';
import 'auth_service.dart';
import 'team_services.dart';

/// Composition root: toàn ứng dụng dùng chung các service hiện có.
class AppServices {
  AppServices({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    ApiClient? api,
  }) : firestore = firestore ?? FirebaseFirestore.instance,
       auth = auth ?? FirebaseAuth.instance,
       api = api ?? ApiClient();

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final ApiClient api;

  late final AuthService accounts = AuthService(
    api: api,
    auth: auth,
    firestore: firestore,
  );

  // Đọc realtime từ Firestore; ghi dữ liệu qua backend API (ApiClient).
  late final ProjectService projects = ProjectService(
    firestore: firestore,
    auth: auth,
    api: api,
  );

  late final TaskService tasks = TaskService(
    firestore: firestore,
    auth: auth,
    api: api,
  );

  // Giữ các service vốn đã tồn tại; không tạo WorkspaceService mới.
  late final ChatService chat = ChatService(firestore: firestore, auth: auth);

  late final WorkspaceService workspace = WorkspaceService(
    firestore: firestore,
    auth: auth,
  );

  // Giữ nguyên service Notification hiện có, không chỉnh logic notification.
  late final NotificationService notifications = NotificationService(
    firestore: firestore,
    auth: auth,
  );

  static final AppServices instance = AppServices();
}
