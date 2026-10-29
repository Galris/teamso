import 'package:teamup_app/services/api_client.dart';

class MemoryTokenStore extends TokenStore {
  Map<String, dynamic>? data;
  @override
  Future<Map<String, dynamic>?> read() async => data;
  @override
  Future<void> write(Map<String, dynamic> tokens) async {
    data = tokens;
  }

  @override
  Future<void> clear() async {
    data = null;
  }
}

Map<String, dynamic> sampleUser({String name = 'Nghi'}) => {
  'id': 'user-1',
  'username': 'nghi',
  'displayName': name,
  'email': 'nghi@example.com',
  'major': 'Flutter',
  'phone': '0912345678',
  'bio': 'TeamUp',
  'avatarUrl': '',
};
