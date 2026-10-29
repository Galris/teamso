import 'package:flutter/material.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

enum _NotificationType { assigned, deadline, completed, updated }

enum _NotificationFilter { all, unread, task, deadline }

class _TeamNotification {
  final int id;
  final String title;
  final String description;
  final String time;
  final _NotificationType type;
  bool isRead;

  _TeamNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.type,
    this.isRead = false,
  });
}

class _NotificationScreenState extends State<NotificationScreen> {
  _NotificationFilter _selectedFilter = _NotificationFilter.all;

  final List<_TeamNotification> _notifications = [
    _TeamNotification(
      id: 1,
      title: 'Bạn được giao công việc mới',
      description: 'Doanh đã giao cho bạn task "Xây dựng Workspace Hub".',
      time: '5 phút trước',
      type: _NotificationType.assigned,
    ),
    _TeamNotification(
      id: 2,
      title: 'Sắp đến hạn công việc',
      description: 'Task "Hoàn thiện màn hình Chat" sắp đến deadline.',
      time: '30 phút trước',
      type: _NotificationType.deadline,
    ),
    _TeamNotification(
      id: 3,
      title: 'Công việc đã hoàn thành',
      description: 'Nghi đã chuyển task "Thiết kế Login" sang Done.',
      time: '1 giờ trước',
      type: _NotificationType.completed,
      isRead: true,
    ),
    _TeamNotification(
      id: 4,
      title: 'Trạng thái công việc thay đổi',
      description: 'Vũ đã chuyển task "Task Board" sang In Progress.',
      time: '2 giờ trước',
      type: _NotificationType.updated,
    ),
    _TeamNotification(
      id: 5,
      title: 'Nhắc nhở deadline',
      description: 'Task "Kiểm tra giao diện" cần hoàn thành sớm.',
      time: 'Hôm qua',
      type: _NotificationType.deadline,
      isRead: true,
    ),
  ];

  int get _unreadCount {
    return _notifications.where((item) => !item.isRead).length;
  }

  List<_TeamNotification> get _filteredNotifications {
    switch (_selectedFilter) {
      case _NotificationFilter.all:
        return _notifications;
      case _NotificationFilter.unread:
        return _notifications.where((item) => !item.isRead).toList();
      case _NotificationFilter.task:
        return _notifications.where((item) {
          return item.type == _NotificationType.assigned ||
              item.type == _NotificationType.completed ||
              item.type == _NotificationType.updated;
        }).toList();
      case _NotificationFilter.deadline:
        return _notifications
            .where((item) => item.type == _NotificationType.deadline)
            .toList();
    }
  }

  IconData _iconForType(_NotificationType type) {
    switch (type) {
      case _NotificationType.assigned:
        return Icons.assignment_ind_outlined;
      case _NotificationType.deadline:
        return Icons.schedule_outlined;
      case _NotificationType.completed:
        return Icons.task_alt_outlined;
      case _NotificationType.updated:
        return Icons.sync_outlined;
    }
  }

  String _labelForType(_NotificationType type) {
    switch (type) {
      case _NotificationType.assigned:
        return 'Giao việc';
      case _NotificationType.deadline:
        return 'Deadline';
      case _NotificationType.completed:
        return 'Hoàn thành';
      case _NotificationType.updated:
        return 'Cập nhật';
    }
  }

  void _markAsRead(_TeamNotification notification) {
    if (!notification.isRead) {
      setState(() {
        notification.isRead = true;
      });
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (final notification in _notifications) {
        notification.isRead = true;
      }
    });
  }

  void _showNotificationDetail(_TeamNotification notification) {
    _markAsRead(notification);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(notification.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.description),
              const SizedBox(height: 12),
              Text('Loại: ${_labelForType(notification.type)}'),
              Text('Thời gian: ${notification.time}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip(String label, _NotificationFilter filter) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == filter,
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildNotificationTile(_TeamNotification notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showNotificationDetail(notification),
        leading: CircleAvatar(child: Icon(_iconForType(notification.type))),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(notification.description),
            const SizedBox(height: 6),
            Text(
              '${_labelForType(notification.type)} • ${notification.time}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        trailing: notification.isRead
            ? const Icon(Icons.check, size: 18)
            : const Icon(Icons.circle, size: 12),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleNotifications = _filteredNotifications;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chưa đọc: $_unreadCount',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: _unreadCount == 0 ? null : _markAllAsRead,
                child: const Text('Đánh dấu tất cả đã đọc'),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('Tất cả', _NotificationFilter.all),
              const SizedBox(width: 8),
              _buildFilterChip('Chưa đọc', _NotificationFilter.unread),
              const SizedBox(width: 8),
              _buildFilterChip('Công việc', _NotificationFilter.task),
              const SizedBox(width: 8),
              _buildFilterChip('Deadline', _NotificationFilter.deadline),
            ],
          ),
        ),

        const Divider(height: 1),

        Expanded(
          child: visibleNotifications.isEmpty
              ? const Center(child: Text('Không có thông báo nào.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleNotifications.length,
                  itemBuilder: (context, index) {
                    return _buildNotificationTile(visibleNotifications[index]);
                  },
                ),
        ),
      ],
    );
  }
}
