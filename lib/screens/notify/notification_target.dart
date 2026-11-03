/// Validates stored notification destinations without trusting arbitrary paths.
class NotificationTarget {
  const NotificationTarget._(
    this.collection,
    this.projectId,
    this.targetId,
    this.conversationId,
  );
  final String? collection;
  final String projectId, targetId, conversationId;
  bool get isDirect => conversationId.isNotEmpty;

  factory NotificationTarget.fromData(Map<String, dynamic> data) {
    String field(String name) => (data[name] ?? '').toString();
    final type = field('type');
    final projectId = field('projectId');
    final targetId = field('targetId');
    final conversationId = field('conversationId');
    if (type == 'chat' && conversationId.isNotEmpty) {
      if (!validId(conversationId))
        throw const FormatException('Liên kết cuộc trò chuyện không hợp lệ.');
      return NotificationTarget._('directChats', '', targetId, conversationId);
    }
    final collection = switch (type) {
      'document' => 'documents',
      'meeting' => 'meetings',
      'vote' => 'votes',
      'chat' => 'messages',
      'member_added' || 'project_joined' => null,
      'assigned' ||
      'assign' ||
      'task_assigned' ||
      'updated' ||
      'completed' ||
      'deadline' ||
      'due' ||
      'reminder' ||
      'pending_review' ||
      'review_required' ||
      'revision_required' ||
      'done' ||
      'approved' => 'tasks',
      _ => throw const FormatException(
        'Thông báo này chưa hỗ trợ mở nội dung.',
      ),
    };
    if (!validId(projectId))
      throw const FormatException(
        'Thông báo cũ chưa có liên kết dự án hợp lệ.',
      );
    if (collection != null && !validId(targetId))
      throw const FormatException(
        'Thông báo cũ chưa có liên kết đến nội dung hợp lệ.',
      );
    return NotificationTarget._(collection, projectId, targetId, '');
  }

  static bool validId(String id) =>
      id.isNotEmpty && id.length <= 1500 && !id.contains('/');
}
