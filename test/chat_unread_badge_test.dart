import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/widgets/app_navigation_bar.dart';
import 'package:teamup_app/screens/chat/project_chat_list.dart';

void main() {
  testWidgets('chat and notification counters update independently', (
    tester,
  ) async {
    final chat = ValueNotifier<int>(3);
    final notices = ValueNotifier<int>(7);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppNavigationBar(
            selectedIndex: 0,
            onSelected: (_) {},
            unread: notices,
            chatUnread: chat,
          ),
        ),
      ),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    notices.value = 0;
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    chat.value = 12;
    await tester.pump();
    expect(find.text('9+'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    chat.dispose();
    notices.dispose();
  });
  testWidgets('each room shows its count and clears when the receipt updates', (
    tester,
  ) async {
    Widget page(Map<String, int> counts) => MaterialApp(
      home: Scaffold(
        body: ProjectChatList(
          projects: const [
            {'id': 'a', 'name': 'Mobile App'},
            {'id': 'b', 'name': 'Website'},
          ],
          previews: const {},
          unreadCounts: counts,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(page({'a': 4, 'b': 102}));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('99+'), findsOneWidget);
    await tester.pumpWidget(page({'b': 102}));
    expect(find.text('4'), findsNothing);
    expect(find.text('99+'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
