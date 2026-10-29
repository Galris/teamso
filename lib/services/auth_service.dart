import '../models/user_profile.dart';
import 'api_client.dart';

class AuthService {
  AuthService(this.api);
  final ApiClient api;
  Future<UserProfile> signIn(String username, String password) async {
    final data = await api.request(
      'POST',
      '/auth/signin',
      body: {'username': username.trim().toLowerCase(), 'password': password},
    );
    final user = UserProfile.fromJson(data['user'] as Map<String, dynamic>);
    await api.saveTokens(data);
    return user;
  }

  Future<void> signUp(Map<String, dynamic> fields) async {
    await api.request('POST', '/auth/signup', body: fields);
  }

  Future<void> signOut() => api.endSession();
}
