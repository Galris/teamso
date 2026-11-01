import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/auth_widgets.dart';
import '../tasks/task_store.dart';

/// Chat nhóm theo từng dự án, đọc/ghi realtime qua `projects/{id}/messages`.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.session, this.userName = ''});
  final SessionController? session;
  final String userName;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _MessageType { me, member, bot }

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    required this.content,
    required this.time,
    required this.type,
  });
  final String sender;
  final String content;
  final String time;
  final _MessageType type;

  static _ChatMessage fromDoc(Map<String, dynamic> doc, String myUid) {
    final kind = (doc['kind'] ?? 'user').toString();
    final senderId = (doc['senderId'] ?? '').toString();
    final created = _createdAt(doc['createdAt']);
    final type = kind != 'user'
        ? _MessageType.bot
        : (senderId.isNotEmpty && senderId == myUid
              ? _MessageType.me
              : _MessageType.member);
    return _ChatMessage(
      sender: (doc['senderName'] ?? '').toString(),
      content: (doc['content'] ?? '').toString(),
      time: created == null ? '' : _hhmm(created.toLocal()),
      type: type,
    );
  }

  static DateTime? _createdAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _sending = false;

  String? _projectId;
  List<_ChatMessage> _messages = const [];
  bool _loadingMessages = true;
  String? _messagesError;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;

  String get _me =>
      widget.userName.trim().isEmpty ? 'Tôi' : widget.userName.trim();

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final has = _messageController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _chatSub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd([bool animate = true]) {
    if (!_scrollController.hasClients) return;
    final end = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        end,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(end);
    }
  }

  /// Chọn dự án (mặc định dự án gần nhất) rồi reconnect stream chat.
  void _syncProject(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) {
      if (_projectId != null) {
        _projectId = null;
        _chatSub?.cancel();
        _chatSub = null;
        setState(() {
          _messages = const [];
          _loadingMessages = false;
        });
      }
      return;
    }
    final stillValid = projects.any((p) => p['id'] == _projectId);
    if (!stillValid) _pickProject(projects.first['id'].toString());
  }

  void _pickProject(String projectId) {
    if (_projectId == projectId) return;
    _projectId = projectId;
    _listen();
  }

  void _listen() {
    _chatSub?.cancel();
    final session = widget.session;
    final projectId = _projectId;
    if (session == null || projectId == null) {
      setState(() {
        _messages = const [];
        _loadingMessages = false;
      });
      return;
    }
    setState(() {
      _loadingMessages = true;
      _messagesError = null;
    });
    _chatSub = session.chat
        .watch(projectId)
        .listen(
          (rows) {
            if (!mounted) return;
            setState(() {
              _messages = rows
                  .map(
                    (doc) => _ChatMessage.fromDoc(
                      doc,
                      session.auth.currentUser?.uid ?? '',
                    ),
                  )
                  .toList();
              _loadingMessages = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _loadingMessages = false;
              _messagesError = errorText(error);
            });
          },
        );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final session = widget.session;
    if (content.isEmpty || session == null || _projectId == null) return;
    setState(() => _sending = true);
    try {
      await session.chat.send(_projectId!, content);
      _messageController.clear();
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _botNotice(_ChatMessage m) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.purpleSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.smart_toy_outlined,
              size: 18,
              color: AppColors.darkPurple,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.content,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  if (m.time.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(m.time, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _bubble(int index) {
    final m = _messages[index];
    if (m.type == _MessageType.bot) return _botNotice(m);

    final isMe = m.type == _MessageType.me;
    final prev = index > 0 ? _messages[index - 1] : null;
    final next = index < _messages.length - 1 ? _messages[index + 1] : null;
    final firstInGroup =
        prev == null || prev.type != m.type || prev.sender != m.sender;
    final lastInGroup =
        next == null || next.type != m.type || next.sender != m.sender;

    const big = Radius.circular(18);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: !isMe && !firstInGroup ? small : big,
      bottomLeft: !isMe && !lastInGroup ? small : (isMe ? big : small),
      topRight: isMe && !firstInGroup ? small : big,
      bottomRight: isMe && !lastInGroup ? small : (isMe ? small : big),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
      decoration: BoxDecoration(
        color: isMe ? AppColors.darkPurple : AppColors.surfaceMuted,
        borderRadius: radius,
        border: isMe ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe && firstInGroup && m.sender.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                m.sender,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.purple,
                ),
              ),
            ),
          Text(
            m.content,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.35,
              color: isMe ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (lastInGroup && m.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                m.time,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isMe ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: firstInGroup ? 10 : 2),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            SizedBox(
              width: 32,
              child: lastInGroup
                  ? Avatar(radius: 16, name: m.sender.isEmpty ? _me : m.sender)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          bubble,
        ],
      ),
    );
  }

  Widget _header(List<Map<String, dynamic>> projects) {
    String? projectName;
    for (final p in projects) {
      if (p['id'] == _projectId) {
        projectName = (p['name'] ?? 'Dự án').toString();
        break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: AppColors.purpleSoft,
            child: Icon(Icons.groups_rounded, color: AppColors.darkPurple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: projects.isEmpty
                ? Text(
                    'Phòng chat nhóm',
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: projects.any((p) => p['id'] == _projectId)
                          ? _projectId
                          : projects.first['id'].toString(),
                      items: [
                        for (final p in projects)
                          DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(
                              (p['name'] ?? 'Dự án').toString(),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        if (id != null) _pickProject(id);
                      },
                    ),
                  ),
          ),
          if (projectName != null)
            Text(
              '${projects.length} dự án',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TaskStore.instance,
      builder: (context, _) {
        final projects = TaskStore.instance.projectsForCurrentUser();
        _syncProject(projects);
        return Column(
          children: [
            _header(projects),
            Expanded(child: _body(projects.isEmpty)),
            if (projects.isNotEmpty) _inputBar(),
          ],
        );
      },
    );
  }

  Widget _body(bool noProjects) {
    if (noProjects) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Chưa có dự án để trò chuyện',
        message: 'Tạo hoặc tham gia một dự án để mở phòng chat của nhóm.',
      );
    }
    if (_loadingMessages) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.darkPurple),
      );
    }
    if (_messagesError != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Không tải được tin nhắn',
        message: _messagesError,
        actionLabel: 'Thử lại',
        onAction: _listen,
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chưa có tin nhắn',
        message: 'Gửi tin nhắn đầu tiên cho nhóm của bạn.',
      );
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _bubble(index),
    );
  }

  Widget _inputBar() {
    final enabled = _projectId != null && !_sending;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: _hasText ? 1 : 0.9,
              duration: const Duration(milliseconds: 150),
              child: IconButton.filled(
                tooltip: 'Gửi tin nhắn',
                onPressed: (_hasText && enabled) ? _sendMessage : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
