import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_widgets.dart';

/// Only receives the signed-in user's real memberships; never supplies demo rooms.
class ProjectChatList extends StatefulWidget {
  const ProjectChatList({
    super.key,
    required this.projects,
    required this.previews,
    required this.onSelected,
    this.loading = false,
    this.error,
    this.previewErrors = const {},
    this.currentUserId = '',
  });
  final List<Map<String, dynamic>> projects;
  final Map<String, Map<String, dynamic>?> previews;
  final Set<String> previewErrors;
  final ValueChanged<String> onSelected;
  final bool loading;
  final String? error;
  final String currentUserId;
  @override
  State<ProjectChatList> createState() => _ProjectChatListState();
}

class _ProjectChatListState extends State<ProjectChatList> {
  String _query = '';
  DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  String _time(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    if (now.year == date.year &&
        now.month == date.month &&
        now.day == date.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  DateTime _sortDate(Map<String, dynamic> project) =>
      _date(widget.previews[project['id'].toString()]?['createdAt']) ??
      _date(project['createdAt']) ??
      DateTime.fromMillisecondsSinceEpoch(0);
  String _preview(String id) {
    if (widget.previewErrors.contains(id)) return 'Không tải được tin nhắn';
    if (!widget.previews.containsKey(id)) return 'Đang tải tin nhắn…';
    final message = widget.previews[id];
    if (message == null) return 'Chưa có tin nhắn';
    final text = (message['content'] ?? '').toString().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    if (message['kind'] != 'user') return text;
    final sender = message['senderId'] == widget.currentUserId
        ? 'Bạn'
        : (message['senderName'] ?? 'Thành viên').toString();
    return '$sender: $text';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null && widget.projects.isEmpty) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được dự án',
        message: widget.error,
      );
    }
    if (widget.projects.isEmpty) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Chưa có dự án',
        message:
            'Tạo hoặc tham gia một dự án để trò chuyện cùng các thành viên.',
      );
    }
    final projects =
        widget.projects
            .where(
              (project) => (project['name'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(_query.trim().toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final byTime = _sortDate(b).compareTo(_sortDate(a));
            return byTime != 0
                ? byTime
                : (a['name'] ?? '').toString().compareTo(
                    (b['name'] ?? '').toString(),
                  );
          });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Tìm dự án',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.purpleSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Row(
            children: [
              const Icon(Icons.expand_more_rounded, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Cuộc trò chuyện',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${widget.projects.length}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (widget.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Text(
              widget.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: projects.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy dự án',
                  message: 'Thử tìm bằng tên khác.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: projects.length,
                  separatorBuilder: (_, _) =>
                      const Divider(indent: 90, endIndent: 20, height: 1),
                  itemBuilder: (context, index) {
                    final project = projects[index];
                    final id = project['id'].toString();
                    final latest = widget.previews[id];
                    return ListTile(
                      key: ValueKey('chat-project-$id'),
                      onTap: () => widget.onSelected(id),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      leading: const CircleAvatar(
                        radius: 27,
                        backgroundColor: AppColors.purpleSoft,
                        child: Icon(
                          Icons.forum_rounded,
                          color: AppColors.darkPurple,
                          size: 26,
                        ),
                      ),
                      title: Text(
                        (project['name'] ?? 'Dự án').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          _preview(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      trailing: Text(
                        _time(_date(latest?['createdAt'])),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
