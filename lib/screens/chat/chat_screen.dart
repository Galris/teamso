import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      sender: 'Doanh',
      content: 'Mọi người cập nhật tiến độ công việc hôm nay nha!',
      time: '08:30',
      type: _MessageType.member,
    ),
    _ChatMessage(
      sender: 'Vân',
      content: 'Mình đang làm màn hình Workspace và Chat.',
      time: '08:35',
      type: _MessageType.me,
    ),
    _ChatMessage(
      sender: 'TeamUp Bot',
      content: 'Nhắc nhở: Task "Hoàn thành giao diện" sắp đến hạn.',
      time: '08:40',
      type: _MessageType.bot,
    ),
    _ChatMessage(
      sender: 'Nghi',
      content: 'Mình đã cập nhật phần đăng nhập rồi nhé.',
      time: '08:45',
      type: _MessageType.member,
    ),
    _ChatMessage(
      sender: 'TeamUp Bot',
      content: 'Task "Thiết kế màn hình Login" đã được chuyển sang Done.',
      time: '08:50',
      type: _MessageType.bot,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();

    if (content.isEmpty) return;

    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(
        _ChatMessage(
          sender: 'Vân',
          content: content,
          time: time,
          type: _MessageType.me,
        ),
      );
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
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
          title: Text('Chat dự án TeamUp'),
          subtitle: Text('Phòng chat nhóm - Dữ liệu mẫu'),
        ),
        const Divider(height: 1),

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
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
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
