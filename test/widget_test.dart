import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/main.dart';

void main() {
  testWidgets(
    'Login validates, profile changes propagate, logout returns to login',
    (tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập email hợp lệ'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'nghi@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
      await tester.ensureVisible(find.text('Đăng nhập'));
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('nghi@example.com'), findsOneWidget);
      await tester.ensureVisible(find.text('Chỉnh sửa thông tin cá nhân'));
      await tester.tap(find.text('Chỉnh sửa thông tin cá nhân'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Nghi');
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(find.text('Nghi'), findsOneWidget);
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('Chào mừng trở lại 👋'), findsOneWidget);
    },
  );
}
