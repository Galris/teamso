import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../services/service_errors.dart';
import '../services/team_services.dart';
import '../screens/tasks/task_store.dart';

/// Trạng thái phiên làm việc: đồng bộ với FirebaseAuth, giữ hồ sơ `users/{uid}`
/// và khởi động/dừng TaskStore theo người dùng hiện tại.
class SessionController extends ChangeNotifier {
  SessionController({AppServices? services})
    : _services = services ?? AppServices.instance {
    _authSubscription = auth.authStateChanges.listen(_handleAuthState);
  }

  final AppServices _services;

  AuthService get auth => _services.accounts;
  ProjectService get projects => _services.projects;
  TaskService get tasks => _services.tasks;
  ChatService get chat => _services.chat;
  WorkspaceService get workspace => _services.workspace;
  NotificationService get notifications => _services.notifications;

  StreamSubscription<User?>? _authSubscription;
  int _authEpoch = 0;

  UserProfile? user;
  bool initializing = true;
  String? startupError;

  Future<void> _handleAuthState(User? firebaseUser) async {
    // Chỉ kết quả của sự kiện mới nhất được áp dụng, tránh ghi đè trạng thái
    // khi đăng nhập/đăng xuất liên tiếp.
    final epoch = ++_authEpoch;
    try {
      UserProfile? profile;
      if (firebaseUser == null) {
        await TaskStore.instance.stop();
      } else {
        profile = await auth.getProfile(firebaseUser.uid);
      }
      if (epoch != _authEpoch) return;
      user = profile;
      if (firebaseUser != null) TaskStore.instance.start();
      startupError = null;
    } catch (error) {
      if (epoch != _authEpoch) return;
      startupError = errorText(error);
    }
    initializing = false;
    notifyListeners();
  }

  Future<void> restore() async {
    initializing = true;
    startupError = null;
    notifyListeners();
    try {
      user = await auth.restoreUser();
      if (user != null) TaskStore.instance.start();
      initializing = false;
    } catch (error) {
      startupError = errorText(error);
      initializing = false;
    }
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    user = await auth.signIn(email, password);
    TaskStore.instance.start();
    startupError = null;
    notifyListeners();
  }

  Future<void> signUp(Map<String, dynamic> fields) async {
    user = await auth.signUp(fields);
    TaskStore.instance.start();
    startupError = null;
    notifyListeners();
  }

  Future<void> update(UserProfile profile) async {
    user = await auth.updateProfile(profile);
    notifyListeners();
  }

  Future<void> signOut() async {
    await auth.signOut();
    await TaskStore.instance.stop();
    user = null;
    startupError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
