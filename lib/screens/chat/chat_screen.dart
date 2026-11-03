import 'project_chat_list.dart';
import 'direct_chat_room.dart';
import '../projects/create_project_screen.dart';
import '../../widgets/prompt_dialog.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/chat_palette.dart';
import '../../services/service_errors.dart';
import '../../utils/chat_time.dart';
import '../../widgets/app_widgets.dart';
import '../../widgets/auth_widgets.dart';
import '../tasks/task_store.dart';

/// Chat nhóm theo từng dự án, đọc/ghi realtime qua `projects/{id}/messages`.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    this.session,
    this.userName = '',
    this.active = true,
    this.unread,
  });
  final SessionController? session;
  final String userName;
  final bool active;
  final ValueNotifier<int>? unread;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

enum _MessageType { me, member, bot }

class _ChatMessage {
  const _ChatMessage({
    required this.sender,
    required this.senderId,
    required this.content,
    required this.time,
    required this.type,
    required this.date,
  });
  final String sender;
  final String senderId;
  final String content;
  final String time;
  final DateTime? date;
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
      senderId: senderId,
      content: (doc['content'] ?? '').toString(),
      time: created == null ? '' : messageTimeLabel(created),
      type: type,
      date: created?.toLocal(),
    );
  }

  static DateTime? _createdAt(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.tryParse(value?.toString() ?? '');
  }
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  StreamSubscription<Map<String, int>>? _unreadSub;
  Map<String, int> _unreadCounts = {};
  String? _latestMessageId;
  bool _markingRead = false;
  bool _resumed = true;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  bool _sending = false;
  bool _startingChat = false, _loadingDirect = false;
  Timer? _directTimer;
  List<Map<String, dynamic>> _directRooms = [];
  String? _directError;
  final Map<String, int> _senderColors = {};

  String? _projectId;
  int _chatGeneration = 0;
  final Map<String, Map<String, dynamic>?> _previews = {};
  final Map<String, StreamSubscription<Map<String, dynamic>?>> _previewSubs =
      {};
  final Set<String> _previewErrors = {};
  List<_ChatMessage> _messages = const [];
  bool _loadingMessages = true;
  String? _messagesError;
  StreamSubscription<List<Map<String, dynamic>>>? _chatSub;

  String get _me =>
      widget.userName.trim().isEmpty ? 'Tôi' : widget.userName.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _unreadSub = widget.session?.chat.watchUnread().listen((counts) {
      if (!mounted) return;
      setState(() => _unreadCounts = counts);
      _updateBadge();
      _markVisibleRead();
    }, onError: (Object _) {});
    _loadDirect();
    _directTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (widget.active && _resumed) _loadDirect();
    });
    TaskStore.instance.addListener(_syncRooms);
    _syncRooms();
    _messageController.addListener(() {
      final has = _messageController.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadSub?.cancel();
    _directTimer?.cancel();
    TaskStore.instance.removeListener(_syncRooms);
    _chatGeneration++;
    _chatSub?.cancel();
    for (final sub in _previewSubs.values) {
      unawaited(sub.cancel());
    }
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _markVisibleRead();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _markVisibleRead();
  }

  Future<void> _loadDirect() async {
    if (_loadingDirect || widget.session == null || !mounted) return;
    _loadingDirect = true;
    try {
      final rooms = await widget.session!.chat.directRooms();
      if (mounted)
        setState(() {
          _directRooms = rooms;
          _directError = null;
        });
    } catch (e) {
      if (mounted) setState(() => _directError = errorText(e));
    } finally {
      _loadingDirect = false;
    }
  }

  Future<void> _openDirect(String id, String name) async {
    final session = widget.session;
    if (session == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DirectChatRoom(session: session, id: id, name: name),
      ),
    );
    if (mounted) await _loadDirect();
  }

  Future<void> _newConversation() async {
    if (_startingChat || widget.session == null) return;
    final type = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Trò chuyện mới',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('Chat nhóm theo dự án'),
              subtitle: const Text('Chọn dự án hoặc tạo dự án mới'),
              onTap: () => Navigator.pop(sheet, 0),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: const Text('Nhắn riêng'),
              subtitle: const Text('Tìm một người bằng username'),
              onTap: () => Navigator.pop(sheet, 1),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (!mounted || type == null) return;
    if (type == 0) {
      final projects = TaskStore.instance.projectsForCurrentUser();
      final id = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Chọn dự án để trò chuyện',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              for (final p in projects)
                ListTile(
                  leading: const Icon(Icons.groups_rounded),
                  title: Text('${p['name'] ?? 'Dự án'}'),
                  onTap: () => Navigator.pop(sheet, p['id'].toString()),
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Tạo dự án mới'),
                onTap: () => Navigator.pop(sheet, '__create__'),
              ),
            ],
          ),
        ),
      );
      if (!mounted || id == null) return;
      if (id == '__create__') {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CreateProjectScreen()),
        );
      } else {
        _pickProject(id);
      }
      return;
    }
    final username = await showTextPrompt(
      context,
      title: 'Bắt đầu nhắn riêng',
      label: 'Username người nhận',
      hint: 'Ví dụ: nghi',
      confirmLabel: 'Mở trò chuyện',
      validator: (value) => RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(value)
          ? null
          : 'Nhập username từ 3–30 ký tự: a-z, 0-9, _.',
    );
    if (!mounted || username == null) return;
    setState(() => _startingChat = true);
    try {
      final room = await widget.session!.chat.startDirect(username);
      await _loadDirect();
      if (!mounted) return;
      final id = room['id'].toString();
      final details = _directRooms.where((r) => r['id'] == id);
      await _openDirect(
        id,
        details.isEmpty ? username : details.first['name'].toString(),
      );
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  void _updateBadge() {
    final ids = TaskStore.instance
        .projectsForCurrentUser()
        .map((p) => p['id'])
        .toSet();
    final count = _unreadCounts.entries
        .where((e) => ids.contains(e.key) || e.key.startsWith('direct:'))
        .fold<int>(0, (total, e) => total + e.value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.unread?.value != count) {
        widget.unread?.value = count;
      }
    });
  }

  Future<void> _markVisibleRead() async {
    final projectId = _projectId;
    final messageId = _latestMessageId;
    if (!widget.active ||
        !_resumed ||
        _markingRead ||
        projectId == null ||
        messageId == null ||
        (_unreadCounts[projectId] ?? 0) == 0) {
      return;
    }
    _markingRead = true;
    try {
      await widget.session?.chat.markRead(projectId, messageId);
    } catch (_) {
      // Keep the unread count if the server is unavailable; retry on next open/update.
    } finally {
      _markingRead = false;
    }
    if (mounted &&
        widget.active &&
        (_projectId != projectId || _latestMessageId != messageId)) {
      _markVisibleRead();
    }
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

  void _syncRooms() {
    if (!mounted) return;
    final session = widget.session;
    final projects = TaskStore.instance.projectsForCurrentUser();
    final ids = projects.map((p) => p['id'].toString()).toSet();
    _updateBadge();
    for (final id
        in _previewSubs.keys.where((id) => !ids.contains(id)).toList()) {
      unawaited(_previewSubs.remove(id)!.cancel());
      _previews.remove(id);
      _previewErrors.remove(id);
    }
    if (_projectId != null && !ids.contains(_projectId)) {
      _chatGeneration++;
      _chatSub?.cancel();
      _chatSub = null;
      _projectId = null;
      _messages = const [];
      _messageController.clear();
    }
    if (session != null) {
      final uid = session.auth.currentUserId;
      for (final id in ids) {
        _previewSubs.putIfAbsent(
          id,
          () => session.chat
              .watchLatest(id)
              .listen(
                (message) {
                  if (!mounted ||
                      !_previewSubs.containsKey(id) ||
                      session.auth.currentUserId != uid) {
                    return;
                  }
                  setState(() {
                    _previews[id] = message;
                    _previewErrors.remove(id);
                  });
                },
                onError: (Object error) {
                  if (mounted && _previewSubs.containsKey(id)) {
                    setState(() => _previewErrors.add(id));
                  }
                },
              ),
        );
      }
    }
    setState(() {});
  }

  void _pickProject(String projectId) {
    if (!TaskStore.instance.projectsForCurrentUser().any(
      (p) => p['id'].toString() == projectId,
    )) {
      return;
    }
    if (_projectId == projectId) return;
    _messageController.clear();
    _projectId = projectId;
    _latestMessageId = null;
    _listen();
  }

  void _leaveRoom() {
    _chatGeneration++;
    _chatSub?.cancel();
    _chatSub = null;
    setState(() {
      _projectId = null;
      _latestMessageId = null;
      _messages = const [];
      _messagesError = null;
    });
    _messageController.clear();
  }

  void _listen() {
    final generation = ++_chatGeneration;
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
            if (!mounted ||
                generation != _chatGeneration ||
                _projectId != projectId) {
              return;
            }
            setState(() {
              _latestMessageId = rows.isEmpty
                  ? null
                  : rows.last['id']?.toString();
              _messages = rows
                  .map(
                    (doc) => _ChatMessage.fromDoc(
                      doc,
                      session.auth.currentUser?.uid ?? '',
                    ),
                  )
                  .toList();
              _loadingMessages = false;
              _messagesError = null;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _scrollToEnd();
              _markVisibleRead();
            });
          },
          onError: (Object error) {
            if (!mounted ||
                generation != _chatGeneration ||
                _projectId != projectId) {
              return;
            }
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
    if (content.isEmpty || _sending || session == null || _projectId == null) {
      return;
    }
    final projectId = _projectId!;
    setState(() => _sending = true);
    try {
      await session.chat.send(projectId, content);
      if (mounted &&
          _projectId == projectId &&
          _messageController.text.trim() == content) {
        _messageController.clear();
      }
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
          borderRadius: BorderRadius.circular(22),
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
        prev == null ||
        prev.type != m.type ||
        prev.senderId != m.senderId ||
        prev.sender != m.sender;
    final lastInGroup =
        next == null ||
        next.type != m.type ||
        next.senderId != m.senderId ||
        next.sender != m.sender;

    const tones = [
      Color(0xFFE5D6F8),
      Color(0xFFF9D9E8),
      Color(0xFFD5EBE3),
      Color(0xFFFFE8BE),
      Color(0xFFD7E5FC),
      Color(0xFFFADACD),
      Color(0xFFD1EDF0),
      Color(0xFFE8EABD),
      Color(0xFFF0D7F4),
      Color(0xFFDDE0F8),
      Color(0xFFE1EFCE),
      Color(0xFFF8DEC1),
    ];
    final senderKey = m.senderId.isEmpty ? m.sender : m.senderId;
    final colorIndex = _senderColors.putIfAbsent(
      senderKey,
      () => _senderColors.length,
    );
    final tone = tones[colorIndex % tones.length];
    const big = Radius.circular(24);
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
        color: tone,
        borderRadius: radius,
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.purple,
                ),
              ),
            ),
          Text(
            m.content,
            style: TextStyle(
              fontSize: 16,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          if (lastInGroup && m.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                m.time,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
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
    final project = projects.firstWhere(
      (p) => p['id'].toString() == _projectId,
      orElse: () => {},
    );
    final (tone, accent) = chatRoomColors(_projectId ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
      decoration: BoxDecoration(
        color: tone,
        border: Border(left: BorderSide(color: accent, width: 6)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Danh sách trò chuyện',
            onPressed: _leaveRoom,
            icon: Icon(Icons.arrow_back_rounded, color: accent),
          ),
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: .8),
            child: Icon(Icons.groups_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (project['name'] ?? 'Dự án').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(project['memberIds'] as List? ?? const []).toSet().union({if ((project['ownerId'] ?? '').toString().isNotEmpty) project['ownerId']}).length} thành viên',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: TaskStore.instance,
    builder: (context, _) {
      final store = TaskStore.instance;
      final projects = store.projectsForCurrentUser();
      if (_projectId == null) {
        final combined = [
          ...projects,
          for (final room in _directRooms)
            {
              ...room,
              'id': 'direct:${room['id']}',
              'createdAt': room['updatedAt'],
            },
        ];
        return Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  if (_directError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Chat riêng: $_directError',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadDirect,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ProjectChatList(
                      unreadCounts: _unreadCounts,
                      projects: combined,
                      previews: {
                        ..._previews,
                        for (final room in _directRooms)
                          'direct:${room['id']}': room['lastMessage'] == null
                              ? null
                              : {
                                  ...Map<String, dynamic>.from(
                                    room['lastMessage'] as Map,
                                  ),
                                  'kind': 'user',
                                },
                      },
                      previewErrors: _previewErrors,
                      currentUserId: widget.session?.auth.currentUserId ?? '',
                      loading: store.projectsLoading,
                      error: store.projectsError,
                      onSelected: (id) {
                        if (id.startsWith('direct:')) {
                          final room = _directRooms.firstWhere(
                            (r) => 'direct:${r['id']}' == id,
                          );
                          _openDirect(
                            room['id'].toString(),
                            room['name'].toString(),
                          );
                        } else {
                          _pickProject(id);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 16,
              bottom: 18,
              child: FilledButton.icon(
                onPressed: _startingChat ? null : _newConversation,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  elevation: 4,
                ),
                icon: const Icon(Icons.add_comment_outlined),
                label: Text(_startingChat ? 'Đang mở…' : 'Trò chuyện mới'),
              ),
            ),
          ],
        );
      }
      return DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            _header(projects),
            Expanded(child: _body(false)),
            _inputBar(),
          ],
        ),
      );
    },
  );

  Widget _body(bool noProjects) {
    if (noProjects) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'Chưa có dự án',
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
      itemBuilder: (context, index) {
        final date = _messages[index].date;
        final prevDate = index == 0 ? null : _messages[index - 1].date;
        final showDate =
            date != null &&
            (prevDate == null ||
                date.year != prevDate.year ||
                date.month != prevDate.month ||
                date.day != prevDate.day);
        return Column(
          children: [
            if (showDate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Chip(
                  label: Text(daySeparatorLabel(date)),
                  backgroundColor: const Color(0xFFE3D7F5),
                  side: BorderSide.none,
                ),
              ),
            _bubble(index),
          ],
        );
      },
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
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
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
