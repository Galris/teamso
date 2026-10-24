import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    this.phone = '',
    this.specialty = 'UI/UX Designer',
    this.bio = '',
  });
  final String name, email, phone, specialty, bio;
}

/// Shared in-memory state for the prototype. Replace authentication with a
/// backend service before using real accounts. Passwords are never stored here.
class SessionController extends ChangeNotifier {
  UserProfile? user;
  void signIn(String email) {
    user = UserProfile(
      name: 'Nguyễn Thị Linh',
      email: email,
      phone: '0912 345 678',
      bio: 'Thích thiết kế, học hỏi và làm việc nhóm 💛',
    );
    notifyListeners();
  }

  void update(UserProfile profile) {
    user = profile;
    notifyListeners();
  }

  void signOut() {
    user = null;
    notifyListeners();
  }
}
