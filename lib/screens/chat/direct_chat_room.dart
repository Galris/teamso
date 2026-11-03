import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/theme/chat_palette.dart';
import '../../services/service_errors.dart';
import '../../utils/chat_time.dart';
import '../../widgets/auth_widgets.dart';

class DirectChatRoom extends StatefulWidget {
  const DirectChatRoom({
    super.key,
    required this.session,
    required this.id,
    required this.name,
  });
  final SessionController session;
  final String id, name;
  @override
  State<DirectChatRoom> createState() => _DirectChatRoomState();
}

class _DirectChatRoomState extends State<DirectChatRoom>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true,
      _fetching = false,
      _sending = false,
      _resumed = true,
      _hasMore = false;
  String? _error, _readId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resumed =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_resumed) _load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) _load();
  }

  Future<void> _load({bool older = false}) async {
    if (_fetching || !mounted || !_resumed) return;
    _fetching = true;
    try {
      final response = await widget.session.chat.directMessages(
        widget.id,
        before: older && _messages.isNotEmpty
            ? _messages.first['id'].toString()
            : null,
      );
      final rows = (response['messages'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      final nearEnd =
          !_scroll.hasClients ||
          _scroll.position.maxScrollExtent - _scroll.offset < 100;
      final oldIds = _messages.map((e) => e['id']).toList();
      final merged = <String, Map<String, dynamic>>{
        for (final m in _messages) m['id'].toString(): m,
        for (final m in rows) m['id'].toString(): m,
      };
      final all = merged.values.toList()
        ..sort(
          (a, b) => (a['createdAt'] ?? '').toString().compareTo(
            (b['createdAt'] ?? '').toString(),
          ),
        );
      final changed = oldIds.join(',') != all.map((e) => e['id']).join(',');
      setState(() {
        _messages = all;
        _loading = false;
        _error = null;
        if (older || oldIds.isEmpty) _hasMore = response['hasMore'] == true;
      });
      if (changed && nearEnd && !older)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients)
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      if (all.isNotEmpty &&
          _readId != all.last['id'] &&
          _resumed &&
          ModalRoute.of(context)?.isCurrent == true) {
        final id = all.last['id'].toString();
        await widget.session.chat.readDirect(widget.id, id);
        _readId = id;
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final content = _text.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.session.chat.sendDirect(widget.id, content);
      if (!mounted) return;
      if (_text.text.trim() == content) _text.clear();
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (tone, accent) = chatRoomColors('direct:${widget.id}');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: tone,
        foregroundColor: accent,
        title: Row(
          children: [
            Avatar(radius: 19, name: widget.name),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'Trò chuyện riêng',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(
                    onPressed: () => _load(),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(
                      child: Text('Gửi lời chào để bắt đầu cuộc trò chuyện.'),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_hasMore && index == 0)
                          return TextButton(
                            onPressed: () => _load(older: true),
                            child: const Text('Xem tin nhắn cũ hơn'),
                          );
                        final m = _messages[index - (_hasMore ? 1 : 0)],
                            me =
                                m['senderId'] ==
                                widget.session.auth.currentUserId;
                        final date = DateTime.tryParse('${m['createdAt']}')
                            ?.toLocal();
                        return Align(
                          alignment: me
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * .76,
                            ),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: me
                                  ? const Color(0xFFE4D6F7)
                                  : const Color(0xFFDCEEE5),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${m['content'] ?? ''}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                                if (date != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      messageTimeLabel(date),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      maxLength: 2000,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Nhập tin nhắn…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Gửi tin nhắn',
                    onPressed: _sending || _text.text.trim().isEmpty
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
