import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/session_controller.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';
import '../../utils/doc_kind.dart';
import '../tasks/task_store.dart';
import 'vote_dialogs.dart';

/// Workspace theo từng dự án:
/// Tài liệu, Quick Vote nhiều lựa chọn và lịch họp.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, this.session});

  final SessionController? session;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  String? _projectId;

  List<Map<String, dynamic>> _documents = const [];
  List<Map<String, dynamic>> _meetings = const [];
  List<Map<String, dynamic>> _votes = const [];
  List<Map<String, dynamic>> _members = const [];

  bool _loading = true;
  String? _error;
  bool _busy = false;
  final Set<String> _loaded = {};

  StreamSubscription? _docsSub;
  StreamSubscription? _meetingsSub;
  StreamSubscription? _votesSub;
  StreamSubscription? _membersSub;

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _docsSub?.cancel();
    _meetingsSub?.cancel();
    _votesSub?.cancel();
    _membersSub?.cancel();

    _docsSub = null;
    _meetingsSub = null;
    _votesSub = null;
    _membersSub = null;
  }

  void _syncProject(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) {
      if (_projectId != null) {
        _cancel();
        _projectId = null;

        setState(() {
          _documents = const [];
          _meetings = const [];
          _votes = const [];
          _members = const [];
          _loading = false;
        });
      }
      return;
    }

    final valid = projects.any(
      (project) => project['id'].toString() == _projectId,
    );

    if (!valid) {
      _pickProject(projects.first['id'].toString());
    }
  }

  void _pickProject(String projectId) {
    if (_projectId == projectId) return;

    _projectId = projectId;
    _listen();
  }

  void _listen() {
    _cancel();

    final workspace = widget.session?.workspace;
    final projectId = _projectId;

    if (workspace == null || projectId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _loaded.clear();
      _error = null;
      _documents = const [];
      _meetings = const [];
      _votes = const [];
      _members = const [];
    });

    _docsSub = workspace
        .watchDocuments(projectId)
        .listen(
          (rows) {
            if (!mounted || _projectId != projectId) return;

            setState(() {
              _documents = rows;
              _loaded.add('documents');
              _loading = _error == null && _loaded.length < 3;
            });
          },
          onError: (Object error) {
            if (mounted && _projectId == projectId) _onError(error);
          },
        );

    _meetingsSub = workspace
        .watchMeetings(projectId)
        .listen(
          (rows) {
            if (!mounted || _projectId != projectId) return;

            setState(() {
              _meetings = rows;
              _loaded.add('meetings');
              _loading = _error == null && _loaded.length < 3;
            });
          },
          onError: (Object error) {
            if (mounted && _projectId == projectId) _onError(error);
          },
        );

    _votesSub = workspace
        .watchVotes(projectId)
        .listen(
          (rows) {
            if (!mounted || _projectId != projectId) return;

            setState(() {
              _votes = rows;
              _loaded.add('votes');
              _loading = _error == null && _loaded.length < 3;
            });
          },
          onError: (Object error) {
            if (mounted && _projectId == projectId) _onError(error);
          },
        );

    _listenMembers(projectId);
  }

  void _listenMembers(String projectId) {
    _membersSub = widget.session!.projects
        .watchMembers(projectId)
        .listen(
          (rows) {
            if (!mounted || _projectId != projectId) return;
            setState(() => _members = rows);
          },
          // Lưới lịch họp chỉ là phần hiển thị phụ, lỗi ở đây không chặn Workspace.
          onError: (Object _) {},
        );
  }

  void _onError(Object error) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = errorText(error);
    });
  }

  Future<void> _guard(Future<void> Function() action, String success) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await action();

      if (mounted) {
        showAppSnack(context, success);
      }
    } catch (error) {
      if (mounted) {
        showAppSnack(context, errorText(error), error: true);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required String label,
    bool optional = false,
    int maxLength = 200,
    String? Function(String)? validate,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _WorkspaceInputDialog(
      title: title,
      label: label,
      optional: optional,
      maxLength: maxLength,
      validate: validate,
    ),
  );

  // =========================================================
  // TÀI LIỆU NHÓM
  // =========================================================

  Future<void> _addDocument() async {
    final projectId = _projectId;

    if (projectId == null || widget.session == null) return;

    final label = await _showInputDialog(
      title: 'Thêm tài liệu',
      label: 'Tên tài liệu',
    );

    if (!mounted || label == null) return;

    final url = await _showInputDialog(
      title: 'Đường dẫn (tùy chọn)',
      label: 'https://...',
      optional: true,
      maxLength: 2048,
      validate: (value) {
        if (value.isEmpty) return null;
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty) {
          return 'Nhập URL http:// hoặc https:// hợp lệ.';
        }
        return null;
      },
    );

    if (!mounted || url == null) return;

    await _guard(
      () => widget.session!.workspace.addDocument(projectId, label, url: url),
      'Đã thêm tài liệu.',
    );
  }

  // =========================================================
  // LỊCH HỌP NHÓM - CHỌN NGÀY VÀ GIỜ
  // =========================================================

  Future<void> _addMeeting() async {
    final projectId = _projectId;

    if (projectId == null || widget.session == null) return;

    final name = await _showInputDialog(
      title: 'Thêm lịch họp',
      label: 'Tên cuộc họp',
      maxLength: 150,
    );

    if (!mounted || name == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'CHỌN NGÀY HỌP',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );

    if (!mounted || selectedDate == null) return;

    final startTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'CHỌN GIỜ BẮT ĐẦU',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (!mounted || startTime == null) return;

    final startMinutes = startTime.hour * 60 + startTime.minute;

    final defaultEndMinutes = (startMinutes + 60) % (24 * 60);

    final endTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: defaultEndMinutes ~/ 60,
        minute: defaultEndMinutes % 60,
      ),
      helpText: 'CHỌN GIỜ KẾT THÚC',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (!mounted || endTime == null) return;

    final endMinutes = endTime.hour * 60 + endTime.minute;

    if (endMinutes <= startMinutes) {
      showAppSnack(context, 'Giờ kết thúc phải sau giờ bắt đầu.', error: true);
      return;
    }

    final meetingStart = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime.hour,
      startTime.minute,
    );

    if (meetingStart.isBefore(DateTime.now())) {
      showAppSnack(
        context,
        'Vui lòng chọn ngày và giờ họp trong tương lai.',
        error: true,
      );
      return;
    }

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    String formatTime(TimeOfDay time) {
      return '${twoDigits(time.hour)}:'
          '${twoDigits(time.minute)}';
    }

    final dateText =
        '${twoDigits(selectedDate.day)}/'
        '${twoDigits(selectedDate.month)}/'
        '${selectedDate.year}';

    final label =
        '$name - $dateText, '
        '${formatTime(startTime)}–${formatTime(endTime)}';

    await _guard(
      () => widget.session!.workspace.addMeeting(
        projectId,
        label,
        startsAt: meetingStart,
        endsAt: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          endTime.hour,
          endTime.minute,
        ),
      ),
      'Đã thêm lịch họp.',
    );
  }

  // =========================================================
  // QUICK VOTE - TẠO BÌNH CHỌN
  // =========================================================

  Future<void> _createVote() async {
    final projectId = _projectId;

    if (projectId == null || widget.session == null) return;

    final draft = await showVoteCreateDialog(context);

    if (!mounted || draft == null) return;

    await _guard(
      () => widget.session!.workspace.addVote(
        projectId,
        draft.question,
        draft.options,
        kind: draft.kind,
      ),
      'Đã tạo bình chọn.',
    );
  }

  // =========================================================
  // QUICK VOTE - CHỌN NHIỀU PHƯƠNG ÁN VÀ ĐỔI PHIẾU
  // =========================================================

  Future<void> _editVote(Map<String, dynamic> vote) async {
    if (_busy || _projectId == null || widget.session == null) {
      return;
    }

    final projectId = _projectId!;
    final voteId = vote['id'].toString();

    final result = await showVoteBallotDialog(context, vote: vote);

    if (!mounted || result == null) return;

    await _guard(
      () => widget.session!.workspace.voteMultiple(projectId, voteId, result),
      result.isEmpty
          ? 'Đã bỏ toàn bộ lựa chọn.'
          : 'Đã cập nhật lựa chọn bình chọn.',
    );
  }

  // =========================================================
  // XÓA TÀI LIỆU, LỊCH HỌP HOẶC BÌNH CHỌN
  // =========================================================

  Future<void> _removeRow(String collection, String id) async {
    final projectId = _projectId;

    if (projectId == null || widget.session == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa mục này?'),
        content: Text(
          collection == 'votes'
              ? 'Bình chọn và toàn bộ phiếu sẽ bị xóa vĩnh viễn.'
              : 'Mục này sẽ bị xóa vĩnh viễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _guard(
      () => widget.session!.workspace.removeRow(projectId, collection, id),
      'Đã xóa.',
    );
  }

  // =========================================================
  // KHUNG GIAO DIỆN CHUNG
  // =========================================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? onAdd,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EEF7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: const Color(0xFF4D4379)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onAdd != null)
                  IconButton(
                    tooltip: 'Thêm mới',
                    onPressed: _busy ? null : onAdd,
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }

  // =========================================================
  // HIỂN THỊ TÀI LIỆU
  // =========================================================

  bool _canDelete(Map<String, dynamic> row) =>
      row['createdBy'] == widget.session?.auth.currentUserId ||
      TaskStore.instance.roleInProject(_projectId ?? '') == 'Leader';

  Future<void> _openDocument(String value) async {
    try {
      final uri = Uri.tryParse(value);
      if (uri == null ||
          !['http', 'https'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          !await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          )) {
        throw const FormatException();
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Không mở được đường dẫn tài liệu.', error: true);
      }
    }
  }

  Widget _docLeading(Map<String, dynamic> doc) {
    final url = (doc['url'] ?? '').toString();
    if (url.isEmpty) return const Icon(Icons.description_outlined);
    final kind = DocKind.detect(url);
    return Icon(kind.icon, color: kind.color);
  }

  Widget _buildDocuments() {
    if (_documents.isEmpty) {
      return const Text('Chưa có tài liệu nào.');
    }

    return Column(
      children: [
        for (final doc in _documents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: _docLeading(doc),
            title: Text((doc['label'] ?? 'Tài liệu').toString()),
            subtitle: (doc['url'] ?? '').toString().isNotEmpty
                ? Text(
                    doc['url'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            onTap: (doc['url'] ?? '').toString().isEmpty
                ? null
                : () => _openDocument(doc['url'].toString()),
            trailing: !_canDelete(doc)
                ? null
                : IconButton(
                    tooltip: 'Xóa tài liệu',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () => _removeRow('documents', doc['id'].toString()),
                  ),
          ),
      ],
    );
  }

  // =========================================================
  // HIỂN THỊ LỊCH HỌP
  // =========================================================

  Widget _buildMeetings() {
    if (_meetings.isEmpty) {
      return const Text('Chưa có lịch họp nào.');
    }

    return Column(
      children: [
        for (final meeting in _meetings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text((meeting['label'] ?? 'Cuộc họp').toString()),
            trailing: !_canDelete(meeting)
                ? null
                : IconButton(
                    tooltip: 'Xóa lịch họp',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _busy
                        ? null
                        : () =>
                              _removeRow('meetings', meeting['id'].toString()),
                  ),
          ),
      ],
    );
  }

  // =========================================================
  // HIỂN THỊ DANH SÁCH QUICK VOTE
  // =========================================================

  Widget _buildVotes() {
    if (_votes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chưa có bình chọn nào.'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _createVote,
            icon: const Icon(Icons.add_chart),
            label: const Text('Tạo bình chọn mới'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final vote in _votes) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  (vote['question'] ?? 'Bình chọn').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_canDelete(vote))
                IconButton(
                  tooltip: 'Xóa bình chọn',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _busy
                      ? null
                      : () => _removeRow('votes', vote['id'].toString()),
                ),
            ],
          ),
          const SizedBox(height: 4),
          _voteOptions(vote),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _busy ? null : _createVote,
          icon: const Icon(Icons.add_chart),
          label: const Text('Tạo bình chọn mới'),
        ),
      ],
    );
  }

  // =========================================================
  // HIỂN THỊ KẾT QUẢ VÀ LỰA CHỌN CỦA TỪNG NGƯỜI
  // =========================================================

  String _initialsOf(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  /// Bình chọn loại 'meeting': lưới When2meet (dòng = khung giờ, cột = người).
  Widget _meetingVote(Map<String, dynamic> vote) {
    final List<Map<String, dynamic>> members = [
      for (final member in _members)
        {
          'uid': (member['uid'] ?? member['id'] ?? '').toString(),
          'name': (member['displayName'] ?? member['username'] ?? 'TV')
              .toString(),
          'initials': _initialsOf(
            (member['displayName'] ?? member['username'] ?? '?').toString(),
          ),
        },
    ];
    final total = (vote['totalVotes'] as num? ?? 0).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MeetingVoteGrid(vote: vote, members: members),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Số người đã tham gia: $total'),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _editVote(vote),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Chọn khung giờ rảnh'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _voteOptions(Map<String, dynamic> vote) {
    if (vote['kind']?.toString() == 'meeting') return _meetingVote(vote);

    final options = (vote['options'] as List? ?? const []).toList();

    final counts = (vote['counts'] as List? ?? const []).toList();

    final myVotes = <int>{
      ...((vote['myVotes'] as List?) ?? const []).whereType<int>(),
    };

    final total = (vote['totalVotes'] as num? ?? 0).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              myVotes.contains(i)
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: myVotes.contains(i)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: Text(options[i].toString()),
            subtitle: Text('${i < counts.length ? counts[i] : 0} phiếu'),
            onTap: _busy ? null : () => _editVote(vote),
          ),
        const SizedBox(height: 8),
        Text('Số người đã tham gia: $total'),
      ],
    );
  }
  // =========================================================
  // CHỌN DỰ ÁN
  // =========================================================

  Widget _projectHeader(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_projectId),
        initialValue:
            projects.any((project) => project['id'].toString() == _projectId)
            ? _projectId
            : projects.first['id'].toString(),
        decoration: const InputDecoration(
          labelText: 'Dự án',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final project in projects)
            DropdownMenuItem<String>(
              value: project['id'].toString(),
              child: Text((project['name'] ?? 'Dự án').toString()),
            ),
        ],
        onChanged: (id) {
          if (id != null) {
            _pickProject(id);
          }
        },
      ),
    );
  }

  // =========================================================
  // MÀN HÌNH WORKSPACE
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TaskStore.instance,
      builder: (context, _) {
        final projects = TaskStore.instance.projectsForCurrentUser();

        // Tránh setState trong build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _syncProject(TaskStore.instance.projectsForCurrentUser());
          }
        });

        final hasProject = _projectId != null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'TeamUp Workspace',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Không gian tổng hợp tài liệu, '
              'bình chọn và lịch họp của nhóm.',
            ),
            const SizedBox(height: 20),
            _projectHeader(projects),
            if (!hasProject)
              const EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'Chưa có dự án',
                message:
                    'Tạo hoặc tham gia một dự án '
                    'để dùng Workspace.',
              )
            else if (_loading)
              const SkeletonList(count: 3, itemHeight: 120)
            else if (_error != null)
              EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Không tải được dữ liệu',
                message: _error,
                actionLabel: 'Thử lại',
                onAction: _listen,
              )
            else ...[
              _buildSection(
                title: 'Tài liệu nhóm',
                icon: Icons.folder_outlined,
                onAdd: _addDocument,
                child: _buildDocuments(),
              ),
              _buildSection(
                title: 'Quick Vote',
                icon: Icons.how_to_vote_outlined,
                child: _buildVotes(),
              ),
              _buildSection(
                title: 'Lịch họp nhóm',
                icon: Icons.groups_outlined,
                onAdd: _addMeeting,
                child: _buildMeetings(),
              ),
            ],
          ],
        );
      },
    );
  }
}

// The dialog owns its controller through the closing animation.
class _WorkspaceInputDialog extends StatefulWidget {
  const _WorkspaceInputDialog({
    required this.title,
    required this.label,
    required this.optional,
    required this.maxLength,
    this.validate,
  });
  final String title, label;
  final bool optional;
  final int maxLength;
  final String? Function(String)? validate;
  @override
  State<_WorkspaceInputDialog> createState() => _WorkspaceInputDialogState();
}

class _WorkspaceInputDialogState extends State<_WorkspaceInputDialog> {
  final _controller = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          final text = (value ?? '').trim();
          if (!widget.optional && text.isEmpty) {
            return 'Vui lòng nhập nội dung.';
          }
          return widget.validate?.call(text);
        },
        onFieldSubmitted: (_) => _save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu')),
    ],
  );
}
