import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/screens/chat/project_chat_list.dart';

void main() {
  Widget page(ProjectChatList child) =>
      MaterialApp(home: Scaffold(body: child));
  testWidgets(
    'No memberships shows the exact empty state and no message input',
    (tester) async {
      await tester.pumpWidget(
        page(
          ProjectChatList(
            projects: const [],
            previews: const {},
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Chưa có dự án'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );
  testWidgets(
    'Only supplied memberships are shown and tap selects their project ID',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        page(
          ProjectChatList(
            projects: const [
              {'id': 'project-a', 'name': 'TeamUp Mobile'},
            ],
            previews: const {
              'project-a': {
                'senderId': 'vu',
                'senderName': 'Vũ',
                'content': 'Đã cập nhật task',
                'kind': 'user',
              },
            },
            currentUserId: 'vu',
            onSelected: (id) => selected = id,
          ),
        ),
      );
      expect(find.text('TeamUp Mobile'), findsOneWidget);
      expect(find.text('Bạn: Đã cập nhật task'), findsOneWidget);
      expect(find.text('Dự án ngoài nhóm'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('chat-project-project-a')));
      expect(selected, 'project-a');
    },
  );
  testWidgets(
    'Search filters real rooms and does not manufacture sample conversations',
    (tester) async {
      await tester.pumpWidget(
        page(
          ProjectChatList(
            projects: const [
              {'id': 'a', 'name': 'Flutter Mobile'},
              {'id': 'b', 'name': 'Backend API'},
            ],
            previews: const {'a': null, 'b': null},
            onSelected: (_) {},
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'API');
      await tester.pump();
      expect(find.text('Backend API'), findsOneWidget);
      expect(find.text('Flutter Mobile'), findsNothing);
      await tester.enterText(find.byType(TextField), 'không có');
      await tester.pump();
      expect(find.text('Không tìm thấy dự án'), findsOneWidget);
    },
  );
  testWidgets(
    'Loading and permission failures are not mistaken for no projects',
    (tester) async {
      await tester.pumpWidget(
        page(
          ProjectChatList(
            projects: const [],
            previews: const {},
            loading: true,
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chưa có dự án'), findsNothing);
      await tester.pumpWidget(
        page(
          ProjectChatList(
            projects: const [],
            previews: const {},
            error: 'Không có quyền',
            onSelected: (_) {},
          ),
        ),
      );
      expect(find.text('Không tải được dự án'), findsOneWidget);
      expect(find.text('Chưa có dự án'), findsNothing);
    },
  );
}
