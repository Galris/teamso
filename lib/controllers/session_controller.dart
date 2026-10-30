import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';

class SessionController extends ChangeNotifier {
  SessionController({ApiClient? client}) : api = client ?? ApiClient() {
    auth = AuthService(api);
    users = UserService(api);
    api.onUnauthorized = () {
      user = null;
      notifyListeners();
    };
  }
  final ApiClient api;
  late final AuthService auth;
  late final UserService users;
  UserProfile? user;
  bool initializing = true;
  String? startupError;

  /// Thông báo một lần hiển thị ở màn đăng nhập (vd. sau khi đổi mật khẩu).
  String? notice;
  Future<void> restore() async {
    initializing = true;
    startupError = null;
    notifyListeners();
    try {
      if (await api.store.read() != null) user = await users.me();
    } catch (e) {
      if (e is! ApiException || e.status != 401) startupError = e.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> signIn(String username, String password) async {
    user = await auth.signIn(username, password);
    startupError = null;
    notice = null;
    notifyListeners();
  }

  Future<void> update(UserProfile profile) async {
    final generation = api.epoch;
    final updated = await users.update(profile);
    if (generation == api.epoch) {
      user = updated;
      notifyListeners();
    }
  }

  /// Đổi mật khẩu xong server thu hồi mọi phiên nên app quay về đăng nhập.
  Future<void> changePassword(String current, String next) async {
    notice = 'Đổi mật khẩu thành công. Hãy đăng nhập lại bằng mật khẩu mới.';
    try {
      await users.changePassword(current, next);
    } catch (_) {
      notice = null;
      rethrow;
    }
  }

  Future<void> signOut() => auth.signOut();
  @override
  void dispose() {
    api.onUnauthorized = null;
    api.close();
    super.dispose();
  }
}
