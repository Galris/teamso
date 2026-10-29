import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teamup_app/models/user_profile.dart';
import 'package:teamup_app/services/api_client.dart';
import 'package:teamup_app/services/user_service.dart';
import 'package:teamup_app/controllers/session_controller.dart';
import 'package:teamup_app/screens/profile/profile_screen.dart';

import 'support.dart';

void main() {
  test('missing projects uses labeled fallback, but an explicit empty list stays empty', () {
    final missing = UserProfile.fromJson(sampleUser());
    expect(missing.projects, hasLength(2));
    expect(missing.projectsAreMock, isTrue);
    final empty = UserProfile.fromJson({...sampleUser(), 'projects': []});
    expect(empty.projects, isEmpty);
    expect(empty.projectsAreMock, isFalse);
    expect(
      UserProfile.fromJson({...sampleUser(), 'projects': null}).projects,
      hasLength(2),
    );
  });
  test('API projects and academic information parse and serialize without mock replacement', () {
    final project = UserProject(
      id: 'p1',
      name: 'Dự án thật',
      role: 'Leader',
      specificTask: 'Phụ trách API',
      status: 'Đang thực hiện',
    );
    final user = UserProfile.fromJson({
      ...sampleUser(),
      'studentId': 'SV001',
      'className': 'K50',
      'projects': [project.toJson()],
    });
    expect(user.projects.single.toJson(), project.toJson());
    expect(user.projectsAreMock, isFalse);
    expect(user.studentId, 'SV001');
    expect(user.className, 'K50');
    expect(() => user.projects.clear(), throwsUnsupportedError);
    expect(user.toUpdateJson().containsKey('projects'), isFalse);
  });
  test('profile update preserves memberships if backend omits them and never sends membership permissions', () async {
    final user = UserProfile.fromJson({
      ...sampleUser(),
      'projects': [
        {
          'id': 'real',
          'name': 'Backend project',
          'role': 'Leader',
          'status': 'active',
        },
      ],
      'studentId': 'SV001',
    });
    final api = ApiClient(
      store: MemoryTokenStore(),
      client: MockClient((r) async {
        expect(jsonDecode(r.body).containsKey('projects'), isFalse);
        return http.Response(
          jsonEncode({'user': sampleUser(name: 'Updated')}),
          200,
        );
      }),
    );
    final saved = await UserService(api).update(user);
    expect(saved.name, 'Updated');
    expect(saved.projects.single.id, 'real');
    expect(saved.projectsAreMock, isFalse);
    expect(saved.studentId, 'SV001');
    api.close();
  });
  testWidgets(
    'profile is scrollable at narrow width and large text with projects and no progress widgets',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = SessionController(
        client: ApiClient(
          store: MemoryTokenStore(),
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
      );
      session.user = UserProfile.fromJson({
        ...sampleUser(),
        'studentId': 'SV001',
        'className': 'K50',
      });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: ProfileScreen(session: session),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Dự án tham gia'), findsOneWidget);
      await tester.ensureVisible(find.text('TeamUp – Đồ án Mobile'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('SV001'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(session.user, isNotNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
