import '../lib/screens/notify/notification_target.dart';

void main() {
  var checks = 0;
  void check(bool condition) {
    checks++;
    if (!condition) throw StateError('Failed check $checks');
  }

  const routes = {
    'document': 'documents',
    'vote': 'votes',
    'meeting': 'meetings',
    'chat': 'messages',
    'assigned': 'tasks',
    'updated': 'tasks',
    'review_required': 'tasks',
    'pending_review': 'tasks',
    'revision_required': 'tasks',
    'completed': 'tasks',
    'deadline': 'tasks',
  };
  for (final entry in routes.entries) {
    final target = NotificationTarget.fromData({
      'type': entry.key,
      'projectId': 'p1',
      'targetId': 't1',
    });
    check(
      target.collection == entry.value &&
          target.projectId == 'p1' &&
          target.targetId == 't1' &&
          !target.isDirect,
    );
  }
  for (final type in ['member_added', 'project_joined']) {
    check(
      NotificationTarget.fromData({'type': type, 'projectId': 'p1'})
              .collection ==
          null,
    );
  }
  final direct = NotificationTarget.fromData({
    'type': 'chat',
    'conversationId': 'room1',
  });
  check(
    direct.isDirect &&
        direct.conversationId == 'room1' &&
        direct.projectId.isEmpty,
  );
  for (final data in <Map<String, dynamic>>[
    {'type': 'vote', 'projectId': 'p1'},
    {'type': 'chat', 'conversationId': 'a/b'},
    {'type': 'document', 'projectId': 'p1/x', 'targetId': 't1'},
    {'type': 'assigned', 'projectId': 'p1', 'targetId': 'a/b'},
    {'type': 'member_added'},
    {'type': 'unsupported', 'projectId': 'p1', 'targetId': 't1'},
  ]) {
    var rejected = false;
    try {
      NotificationTarget.fromData(data);
    } on FormatException {
      rejected = true;
    }
    check(rejected);
  }
  print('$checks notification routing checks passed.');
}
