import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import 'service_errors.dart';
import 'api_client.dart' show ApiClient, ApiException;

/// Firebase Authentication và hồ sơ gốc ở `users/{uid}`.
/// Tài liệu claim username chỉ chứa UID, không lộ email.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ApiClient? api,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _db = firestore ?? FirebaseFirestore.instance,
       _api = api ?? ApiClient();

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final ApiClient _api;

  User? get currentUser => _auth.currentUser;
  String get currentUserId => _auth.currentUser?.uid ?? '';
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  /// Hồ sơ được ghi ngay sau khi tạo tài khoản, nên nếu document chưa tồn tại
  /// (auth state fires trước khi transaction hoàn tất) ta chờ nó xuất hiện.
  Future<UserProfile> getProfile(
    String uid, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final ref = _users.doc(uid);
    final initial = await _wrap(() => ref.get());
    if (initial.exists) return _parse(initial, uid);
    try {
      final doc = await _wrap(
        () => ref.snapshots().firstWhere((snapshot) => snapshot.exists),
      ).timeout(timeout);
      return _parse(doc, uid);
    } on TimeoutException {
      throw const ServiceException(
        'Không tìm thấy hồ sơ người dùng. Vui lòng đăng nhập lại.',
      );
    }
  }

  /// Username được xác minh mật khẩu tại backend trước khi nhận email.
  /// Firebase Auth vẫn quản lý phiên native cho Firestore và các màn hình khác.
  Future<UserProfile> signIn(String identifier, String password) async {
    var email = identifier.trim().toLowerCase();
    String? expectedUid;
    if (!email.contains('@')) {
      final response = await _wrap(
        () => _api.request(
          'POST',
          '/auth/signin',
          body: {'username': email, 'password': password},
        ),
      );
      final profile = response['user'];
      if (profile is! Map<String, dynamic> ||
          profile['email'] is! String ||
          profile['id'] is! String) {
        throw const ServiceException(
          'Máy chủ trả thông tin đăng nhập không hợp lệ.',
        );
      }
      email = profile['email'] as String;
      expectedUid = profile['id'] as String;
    }
    final credential = await _wrap(
      () => _auth.signInWithEmailAndPassword(email: email, password: password),
    );
    final user = credential.user;
    if (user == null || (expectedUid != null && user.uid != expectedUid)) {
      await _auth.signOut();
      throw const ServiceException('Không thể đăng nhập. Vui lòng thử lại.');
    }
    return getProfile(user.uid);
  }

  /// Trả về null khi chưa có phiên đăng nhập — người gọi xử lý trạng thái
  /// chưa xác thực, không ném lỗi.
  Future<UserProfile?> restoreUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    await _wrap(user.reload);
    final refreshed = _auth.currentUser;
    if (refreshed == null) return null;
    return getProfile(refreshed.uid);
  }

  Future<UserProfile> signUp(Map<String, dynamic> fields) async {
    final username = (fields['username'] ?? '').toString().trim().toLowerCase();
    final email = (fields['email'] ?? '').toString().trim().toLowerCase();
    final password = (fields['password'] ?? '').toString();
    final displayName = (fields['displayName'] ?? '').toString().trim();
    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        displayName.isEmpty) {
      throw const ServiceException('Vui lòng nhập đầy đủ thông tin bắt buộc.');
    }
    // Kiểm tra sớm để tránh tạo rồi phải xóa một tài khoản Firebase thừa.
    final claimRef = _usernames.doc(username);
    if ((await _wrap(() => claimRef.get())).exists) {
      throw const ServiceException('Tên đăng nhập đã được sử dụng.');
    }
    final credential = await _wrap(
      () => _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      ),
    );
    final user = credential.user;
    if (user == null) throw const ServiceException('Không thể tạo tài khoản.');
    try {
      await _wrap(() => user.updateDisplayName(displayName));
      final userRef = _users.doc(user.uid);
      // Giao dịch đảm bảo hai tài khoản không cùng claim một username.
      await _wrap(
        () => _db.runTransaction((tx) async {
          if ((await tx.get(claimRef)).exists) {
            throw const ServiceException('Tên đăng nhập đã được sử dụng.');
          }
          tx.set(userRef, {
            'username': username,
            'displayName': displayName,
            'email': email,
            'avatarUrl': '',
            'major': (fields['major'] ?? '').toString().trim(),
            'phone': (fields['phone'] ?? '').toString().trim(),
            'bio': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(claimRef, {
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }),
      );
    } catch (error) {
      // Roll back tài khoản Firebase nếu không ghi được hồ sơ.
      try {
        await _users.doc(user.uid).delete();
        await claimRef.delete();
        await user.delete();
      } catch (_) {
        // Không che lỗi gốc bằng lỗi dọn dẹp.
      }
      rethrow;
    }
    return getProfile(user.uid);
  }

  Future<UserProfile> updateProfile(UserProfile profile) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw const ServiceException('Bạn chưa đăng nhập.');
    await _wrap(
      () => _users.doc(uid).update({
        ...profile.toUpdateJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
    return getProfile(uid);
  }

  /// Firebase gửi email chứa liên kết đặt lại mật khẩu (oobCode).
  Future<void> forgotPassword(String email) async => _wrap(
    () => _auth.sendPasswordResetEmail(email: email.trim().toLowerCase()),
  );

  /// Chỉ dùng khi app nhận được oobCode từ liên kết trong email.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _wrap(
    () =>
        _auth.confirmPasswordReset(code: code.trim(), newPassword: newPassword),
  );

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const ServiceException('Bạn chưa đăng nhập.');
    }
    await _wrap(
      () => user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      ),
    );
    await _wrap(() => user.updatePassword(newPassword));
  }

  Future<void> signOut() => _auth.signOut();

  UserProfile _parse(DocumentSnapshot<Map<String, dynamic>> doc, String uid) =>
      UserProfile.fromJson({...?doc.data(), 'uid': uid});

  Future<T> _wrap<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (error) {
      throw ServiceException(error.message);
    } on ServiceException {
      rethrow;
    } catch (error) {
      throw ServiceException(errorText(error));
    }
  }
}
