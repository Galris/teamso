import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';

/// Thông báo đọc trực tiếp từ `users/{uid}/notifications` qua stream realtime.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key, this.session, this.unread});
  final SessionController? session;

  /// Báo số thông báo chưa đọc lên MainScreen để hiện badge.
  final ValueNotifier<int>? unread;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

enum _NotificationType { assigned, deadline, completed, updated }

enum _NotificationFilter { all, unread, task, deadline }

class _TeamNotification {
  _TeamNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    this.isRead = false,
  });
  final String id;
  final String title;
  final String description;
  final String time;
  final _NotificationType type;
  bool isRead;

  static _TeamNotification? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) return null;
    final type = switch ((j['type'] ?? '').toString().toLowerCase()) {
      'assigned' || 'assign' || 'task_assigned' => _NotificationType.assigned,
      'deadline' || 'due' || 'reminder' => _NotificationType.deadline,
      'completed' || 'done' || 'approved' => _NotificationType.completed,
      _ => _NotificationType.updated,
    };
    final created = _createdAt(j['createdAt']);
    return _TeamNotification(
      id: id,
      title: (j['title'] ?? 'Thông báo').toString(),
      description: (j['body'] ?? j['description'] ?? j['message'] ?? '')
          .toString(),
      time: created == null ? '' : _ago(created.toLocal()),
      type: type,
      isRead: j['read'] == true || j['isRead'] == true,
    );
  }

  static DateTime? _createdAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    if (d.inDays == 1) return 'Hôm qua';
    if (d.inDays < 7) return '${d.inDays} ngày trước';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }
}

class _NotificationScreenState extends State<NotificationScreen> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;
  List<_TeamNotification> _notifications = [];
  bool _loading = true;
  String? _loadError;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _syncBadge() {
    final notifier = widget.unread;
    if (notifier != null && notifier.value != _unreadCount) {
      notifier.value = _unreadCount;
    }
  }

  /// Đăng ký lại stream; gọi khi mở màn hình và khi người dùng kéo làm mới.
  void _listen() {
    _subscription?.cancel();
    _subscription = null;
    final session = widget.session;
    if (session == null) {
      setState(() {
        _notifications = [];
        _loading = false;
        _loadError = 'Bạn chưa đăng nhập.';
      });
      _syncBadge();
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _subscription = session.notifications.watchMine().listen(
      (rows) {
        if (!mounted) return;
        setState(() {
          _notifications = rows
              .map(_TeamNotification.fromJson)
              .whereType<_TeamNotification>()
              .toList();
          _loading = false;
          _loadError = null;
        });
        _syncBadge();
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadError = errorText(error);
        });
        _syncBadge();
      },
    );
  }

  Future<void> _refresh() async {
    _listen();
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  List<_TeamNotification> get _filtered => switch (_selectedFilter) {
    _NotificationFilter.all => _notifications,
    _NotificationFilter.unread =>
      _notifications.where((n) => !n.isRead).toList(),
    _NotificationFilter.task =>
      _notifications
          .where((n) => n.type != _NotificationType.deadline)
          .toList(),
    _NotificationFilter.deadline =>
      _notifications
          .where((n) => n.type == _NotificationType.deadline)
          .toList(),
  };

  IconData _iconForType(_NotificationType t) => switch (t) {
    _NotificationType.assigned => Icons.assignment_ind_outlined,
    _NotificationType.deadline => Icons.schedule_rounded,
    _NotificationType.completed => Icons.task_alt_rounded,
    _NotificationType.updated => Icons.sync_rounded,
  };

  Color _colorForType(_NotificationType t) => switch (t) {
    _NotificationType.assigned => AppColors.purple,
    _NotificationType.deadline => const Color(0xFFE08A00),
    _NotificationType.completed => AppColors.green,
    _NotificationType.updated => AppColors.darkPurple,
  };

  String _labelForType(_NotificationType t) => switch (t) {
    _NotificationType.assigned => 'Giao việc',
    _NotificationType.deadline => 'Deadline',
    _NotificationType.completed => 'Hoàn thành',
    _NotificationType.updated => 'Cập nhật',
  };

  Future<void> _markAsRead(_TeamNotification n) async {
    if (n.isRead) return;
    // Stream realtime sẽ cập nhật lại danh sách sau khi Firestore ghi xong,
    // nên chỉ optimistic-set để badge phản hồi ngay.
    setState(() => n.isRead = true);
    _syncBadge();
    final session = widget.session;
    if (session == null) return;
    try {
      await session.notifications.markRead(n.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => n.isRead = false);
      _syncBadge();
      showAppSnack(context, errorText(e), error: true);
    }
  }

  Future<void> _markAllAsRead() async {
    final session = widget.session;
    if (session == null) return;
    final previouslyUnread = _notifications.where((n) => !n.isRead).toList();
    if (previouslyUnread.isEmpty) return;
    setState(() {
      for (final n in previouslyUnread) {
        n.isRead = true;
      }
    });
    _syncBadge();
    try {
      await session.notifications.markAllRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        for (final n in previouslyUnread) {
          n.isRead = false;
        }
      });
      _syncBadge();
      showAppSnack(context, errorText(e), error: true);
    }
  }

  void _showDetail(_TeamNotification n) {
    _markAsRead(n);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TypeBadge(
                    icon: _iconForType(n.type),
                    color: _colorForType(n.type),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      n.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(n.description),
              const SizedBox(height: 10),
              Text(
                '${_labelForType(n.type)} · ${n.time}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheet),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, _NotificationFilter f) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == f,
      onSelected: (_) => setState(() => _selectedFilter = f),
    ),
  );

  Widget _tile(_TeamNotification n) {
    final color = _colorForType(n.type);
    return Dismissible(
      key: ValueKey('notif-${n.id}'),
      direction: n.isRead ? DismissDirection.none : DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await _markAsRead(n);
        return false; // chỉ đánh dấu đã đọc, không xoá khỏi danh sách
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: AppColors.successSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, color: AppColors.green),
            SizedBox(width: 8),
            Text('Đã đọc', style: TextStyle(color: AppColors.green)),
          ],
        ),
      ),
      child: Material(
        color: n.isRead ? Colors.white : AppColors.purpleSoft,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showDetail(n),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: n.isRead ? AppColors.border : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeBadge(icon: _iconForType(n.type), color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: n.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_labelForType(n.type)} · ${n.time}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!n.isRead)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: AppColors.pink,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonList(count: 5, itemHeight: 88);
    final items = _filtered;
    return Column(
      children: [
        if (_loadError != null)
          Container(
            width: double.infinity,
            color: const Color(0xFFFFF6DD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loadError!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _listen,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _unreadCount == 0
                      ? 'Bạn đã đọc hết thông báo'
                      : '$_unreadCount chưa đọc',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _unreadCount == 0 ? null : _markAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Đọc tất cả'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              _chip('Tất cả', _NotificationFilter.all),
              _chip('Chưa đọc', _NotificationFilter.unread),
              _chip('Công việc', _NotificationFilter.task),
              _chip('Deadline', _NotificationFilter.deadline),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: items.isEmpty
                ? ListView(
                    // ListView để kéo-làm-mới vẫn hoạt động khi danh sách rỗng
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 360,
                        child: EmptyState(
                          icon: Icons.notifications_off_outlined,
                          title: _selectedFilter == _NotificationFilter.unread
                              ? 'Không còn thông báo chưa đọc'
                              : 'Chưa có thông báo nào',
                          message: 'Kéo xuống để làm mới.',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _tile(items[i]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}
