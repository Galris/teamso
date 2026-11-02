import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Tokens stay on the trusted backend, never in publicly readable user profiles.
class PushService extends ChangeNotifier {
  PushService(this.api, this.auth);
  final ApiClient api;
  final FirebaseAuth auth;
  StreamSubscription<String>? _refresh;
  Future<void>? _registration;
  String? _token;
  bool enabled = false;
  bool busy = false;
  String? error;
  int _epoch = 0;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> start() async {
    if (!supported || auth.currentUser == null) return;
    try {
      if (!await FirebaseMessaging.instance.isSupported()) return;
      if (!FirebaseMessaging.instance.isAutoInitEnabled) return;
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _register();
      }
    } catch (_) {
      // Opening the app must still work when push services are unavailable.
    }
  }

  Future<void> enable() async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (!supported || !await FirebaseMessaging.instance.isSupported()) {
        throw StateError(
          'Thiết bị hoặc trình duyệt này chưa hỗ trợ thông báo đẩy.',
        );
      }
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        throw StateError(
          'Chưa được cấp quyền. Bạn có thể cho phép thông báo trong cài đặt ứng dụng/trình duyệt.',
        );
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await _register();
    } catch (e) {
      error = e is StateError
          ? e.message.toString()
          : 'Chưa bật được thông báo đẩy. Kiểm tra kết nối rồi thử lại.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _register() {
    final operation = _registerDevice();
    _registration = operation;
    return operation.whenComplete(() {
      if (identical(_registration, operation)) _registration = null;
    });
  }

  Future<void> _registerDevice() async {
    final uid = auth.currentUser?.uid;
    final epoch = ++_epoch;
    if (uid == null) return;
    // Admin SDK v13 direct sends require registration tokens, not the new FID
    // returned by register()/onRegistered. Keep this pair until server migration.
    // ignore: deprecated_member_use
    final token = await FirebaseMessaging.instance.getToken();
    if (epoch != _epoch || auth.currentUser?.uid != uid) return;
    if (token == null) {
      throw StateError('Chưa lấy được token thiết bị, vui lòng thử lại.');
    }
    await api.put('/notifications/device', body: {'token': token});
    if (epoch != _epoch || auth.currentUser?.uid != uid) return;
    _token = token;
    enabled = true;
    await _refresh?.cancel();
    // ignore: deprecated_member_use
    _refresh = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) async {
      if (auth.currentUser?.uid != uid || !enabled) return;
      try {
        await api.put('/notifications/device', body: {'token': newToken});
        if (_token != null && _token != newToken) {
          await api.delete('/notifications/device', body: {'token': _token});
        }
        _token = newToken;
      } catch (_) {
        error =
            'Chưa cập nhật được thiết bị. Bấm bật lại thông báo để thử lại.';
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> disable() async {
    if (busy) throw StateError('Vui lòng chờ thao tác thông báo hoàn tất.');
    busy = true;
    notifyListeners();
    try {
      try {
        await _registration;
      } catch (_) {
        /* Continue removing any existing registration. */
      }
      ++_epoch;
      await _refresh?.cancel();
      _refresh = null;
      // Remove registration first. If offline, keep enabled so the UI never
      // incorrectly promises notifications have been disabled.
      if (_token != null) {
        await api.delete('/notifications/device', body: {'token': _token});
      }
      if (supported && _token != null) {
        // ignore: deprecated_member_use
        await FirebaseMessaging.instance.deleteToken();
      }
      if (supported) await FirebaseMessaging.instance.setAutoInitEnabled(false);
      _token = null;
      enabled = false;
      error = null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
