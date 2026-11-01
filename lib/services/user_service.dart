import '../models/user_profile.dart';
import 'api_client.dart';

class UserService {
  UserService(this.api);
  final ApiClient api;

  UserProfile _parse(Map<String, dynamic> data, {UserProfile? fallback}) {
    final raw = data['user'];
    if (raw is! Map<String, dynamic>) {
      throw const ApiException('Máy chủ trả dữ liệu không hợp lệ.');
    }
    return UserProfile.fromJson(raw, fallback: fallback);
  }

  Future<UserProfile> me() async =>
      _parse(await api.request('GET', '/users/me', protected: true));

  Future<UserProfile> update(UserProfile profile) async => _parse(
    await api.request(
      'PUT',
      '/users/profile',
      body: profile.toUpdateJson(),
      protected: true,
    ),
    fallback: profile,
  );

  Future<void> changePassword(String current, String next) async {
    await api.request(
      'PUT',
      '/users/change-password',
      protected: true,
      body: {'currentPassword': current, 'newPassword': next},
    );
    await api.clearSession();
  }

  /// Upload ảnh đại diện (multipart). Hợp đồng giả định:
  /// POST /users/avatar, field `avatar` -> {user: {...}}.
  Future<UserProfile> uploadAvatar(
    List<int> bytes, {
    String filename = 'avatar.jpg',
    UserProfile? fallback,
  }) async => _parse(
    await api.request(
      'POST',
      '/users/avatar',
      protected: true,
      file: UploadFile(field: 'avatar', filename: filename, bytes: bytes),
    ),
    fallback: fallback,
  );

  /// Xoá tài khoản (bắt buộc với app lên store). DELETE /users/me {password}.
  Future<void> deleteAccount(String password) async {
    await api.request(
      'DELETE',
      '/users/me',
      protected: true,
      body: {'password': password},
    );
    await api.clearSession();
  }
}
