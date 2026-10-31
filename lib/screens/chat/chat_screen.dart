import 'dart:async';

import '../../controllers/session_controller.dart';
import '../../services/chat_service.dart';

import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<_ChatMessage> _messages = [];
  late final ChatService _chat;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  bool _sending = false;
  bool _loading = true;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _chat = ChatService(widget.session.api);
    _subscription = _chat.listenToMessages(
      (rows) {
        if (!mounted) return;
        final shouldScroll =
            !_scrollController.hasClients ||
            _scrollController.position.maxScrollExtent -
                    _scrollController.offset <
                100;
        setState(() {
          _loading = false;
          _connectionError = null;
          _messages = rows.map((row) {
            final date = DateTime.tryParse(row['timestamp'] as String? ?? '')
                ?.toLocal();
            return _ChatMessage(
              sender: row['name'] as String? ?? 'Thành viên',
              content: row['text'] as String? ?? '',
              time: date == null
                  ? ''
                  : '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
              type: row['uid'] == widget.session.user?.id
                  ? _MessageType.me
                  : _MessageType.member,
            );
          }).toList();
        });
        if (shouldScroll) _scrollToBottom();
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _loading = false;
            _connectionError = 'Không kết nối được chat. Đang thử lại…';
          });
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _chat.sendMessage(text);
      if (!mounted) return;
      if (_messageController.text.trim() == text) _messageController.clear();
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildMessage(_ChatMessage message) {
    if (message.type == _MessageType.bot) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_outlined, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'TeamUp Bot',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(message.content, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  message.time,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isMe = message.type == _MessageType.me;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.sender,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(message.content),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                message.time,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Thông tin phòng chat
        const ListTile(
          leading: CircleAvatar(child: Icon(Icons.groups_outlined)),
          title: Text('Chat chung TeamUp'),
        ),
        const Divider(height: 1),

        if (_connectionError != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_connectionError!),
          ),
        if (_loading) const LinearProgressIndicator(),
        if (!_loading && _messages.isEmpty && _connectionError == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có tin nhắn. Hãy bắt đầu cuộc trò chuyện!'),
          ),
        // Danh sách tin nhắn
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _buildMessage(_messages[index]);
            },
          ),
        ),

        // Khu vực nhập tin nhắn
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Gửi tin nhắn',
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _MessageType { me, member, bot }

class _ChatMessage {
  final String sender;
  final String content;
  final String time;
  final _MessageType type;

  const _ChatMessage({
    required this.sender,
    required this.content,
    required this.time,
    required this.type,
  });
}
