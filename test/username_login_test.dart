import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/models/user_profile.dart';
import 'package:teamup_app/services/api_client.dart'
    show ApiClient, ApiException, UploadFile;
import 'package:teamup_app/services/auth_service.dart';
import 'package:teamup_app/services/service_errors.dart' show ServiceException;

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Credential implements UserCredential {
  _Credential(this.user);
  @override
  final User? user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  String uid = 'uid-1';
  String? signedEmail;
  int signIns = 0;
  bool signedOut = false;
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signedEmail = email;
    signIns++;
    return _Credential(_User(uid));
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Firestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'http://localhost/api');
  Map<String, dynamic>? submitted;
  bool reject = false;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool protected = false,
    Duration? timeout,
    UploadFile? file,
  }) async {
    calls++;
    submitted = body;
    expect(method, 'POST');
    expect(path, '/auth/signin');
    expect(protected, false);
    if (reject) {
      throw const ApiException(
        'Tên đăng nhập hoặc mật khẩu không đúng.',
        status: 401,
      );
    }
    return {
      'user': {'id': 'uid-1', 'email': 'nghi@example.com'},
    };
  }
}

class _Service extends AuthService {
  _Service(_Auth auth, _Api api)
    : super(auth: auth, firestore: _Firestore(), api: api);
  @override
  Future<UserProfile> getProfile(
    String uid, {
    Duration timeout = const Duration(seconds: 12),
  }) async => UserProfile(
    id: uid,
    username: 'nghi',
    name: 'Nghi',
    email: 'nghi@example.com',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Username resolves only after password verification and creates a native Firebase session', () async {
    final api = _Api();
    final auth = _Auth();
    final service = _Service(auth, api);
    final profile = await service.signIn(' NGHI ', 'Password123');
    expect(api.submitted, {'username': 'nghi', 'password': 'Password123'});
    expect(auth.signedEmail, 'nghi@example.com');
    expect(profile.id, 'uid-1');
    api.close();
  });
  test('Email login remains supported without a backend lookup', () async {
    final api = _Api();
    final auth = _Auth();
    final service = _Service(auth, api);
    await service.signIn(' NGHI@EXAMPLE.COM ', 'Password123');
    expect(api.calls, 0);
    expect(auth.signedEmail, 'nghi@example.com');
    api.close();
  });
  test('Rejected credentials never create a Firebase session', () async {
    final api = _Api()..reject = true;
    final auth = _Auth();
    await expectLater(
      _Service(auth, api).signIn('nghi', 'wrong'),
      throwsA(isA<ServiceException>()),
    );
    expect(auth.signIns, 0);
    api.close();
  });
  test(
    'An unexpected Firebase UID is signed out rather than trusted',
    () async {
      final api = _Api();
      final auth = _Auth()..uid = 'other-user';
      await expectLater(
        _Service(auth, api).signIn('nghi', 'Password123'),
        throwsA(isA<ServiceException>()),
      );
      expect(auth.signedOut, true);
      api.close();
    },
  );
}
