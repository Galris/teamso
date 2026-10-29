import '../models/user_profile.dart';
import 'api_client.dart';

class UserService {
  UserService(this.api);
  final ApiClient api;
  Future<UserProfile> me() async => UserProfile.fromJson(
    (await api.request('GET', '/users/me', protected: true))['user']
        as Map<String, dynamic>,
  );
  Future<UserProfile> update(UserProfile profile) async => UserProfile.fromJson(
    (await api.request(
          'PUT',
          '/users/profile',
          body: profile.toUpdateJson(),
          protected: true,
        ))['user']
        as Map<String, dynamic>,
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
}
