import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teamup_app/main.dart';
import 'package:teamup_app/services/api_client.dart';
import 'package:teamup_app/controllers/session_controller.dart';

import 'support.dart';

void main() {
  testWidgets('real UI uses services for login, edit and signout', (
    tester,
  ) async {
    final store = MemoryTokenStore();
    final calls = <String>[];
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        calls.add(r.url.path);
        if (r.url.path.endsWith('/signin')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'access',
              'refreshToken': 'refresh',
              'user': sampleUser(),
            }),
            200,
          );
        }
        if (r.url.path.endsWith('/profile')) {
          expect(r.headers['Authorization'], 'Bearer access');
          final fields = jsonDecode(r.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'user': {...sampleUser(), ...fields},
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      }),
    );
    final session = SessionController(client: api);
    await tester.pumpWidget(MyApp(session: session));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tên đăng nhập: 3–30 ký tự a-z, 0-9 hoặc _.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'nghi');
    await tester.enterText(find.byType(TextFormField).at(1), 'Test-pass-123');
    await tester.ensureVisible(find.text('Đăng nhập'));
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.account_circle_outlined));
    await tester.pumpAndSettle();
    expect(find.text('nghi@example.com'), findsOneWidget);
    await tester.ensureVisible(find.text('Chỉnh sửa thông tin cá nhân'));
    await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Nghi updated');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Nghi updated'), findsOneWidget);
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại 👋'), findsOneWidget);
    expect(store.data, isNull);
    expect(
      calls,
      containsAll([
        '/api/auth/signin',
        '/api/users/profile',
        '/api/auth/signout',
      ]),
    );
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
}
