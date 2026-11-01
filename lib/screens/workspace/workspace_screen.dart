import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';
import '../tasks/task_store.dart';

/// Không gian nhóm theo từng dự án: tài liệu, bình chọn và lịch họp, tất cả
/// đọc/ghi realtime qua Firestore.
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
  bool _loading = true;
  String? _error;
  bool _busy = false;

  StreamSubscription? _docsSub;
  StreamSubscription? _meetingsSub;
  StreamSubscription? _votesSub;

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  void _cancel() {
    _docsSub?.cancel();
    _meetingsSub?.cancel();
    _votesSub?.cancel();
    _docsSub = _meetingsSub = _votesSub = null;
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
          _loading = false;
        });
      }
      return;
    }
    final valid = projects.any((p) => p['id'] == _projectId);
    if (!valid) _pickProject(projects.first['id'].toString());
  }

  void _pickProject(String projectId) {
    if (_projectId == projectId) return;
    _projectId = projectId;
    _listen();
  }

  void _listen() {
    _cancel();
    final ws = widget.session?.workspace;
    final pid = _projectId;
    if (ws == null || pid == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _docsSub = ws
        .watchDocuments(pid)
        .listen(
          (rows) => setState(() {
            _documents = rows;
            _loading = false;
          }),
          onError: _onError,
        );
    _meetingsSub = ws
        .watchMeetings(pid)
        .listen(
          (rows) => setState(() {
            _meetings = rows;
            _loading = false;
          }),
          onError: _onError,
        );
    _votesSub = ws
        .watchVotes(pid)
        .listen(
          (rows) => setState(() {
            _votes = rows;
            _loading = false;
          }),
          onError: _onError,
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
      if (mounted) showAppSnack(context, success);
    } catch (e) {
      if (mounted) showAppSnack(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              final text = value.trim();
              if (text.isNotEmpty) Navigator.pop(dialogContext, text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isNotEmpty) Navigator.pop(dialogContext, value);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _addDocument() async {
    final label = await _showInputDialog(
      title: 'Thêm tài liệu',
      label: 'Tên tài liệu',
    );
    if (!mounted || label == null) return;
    final url = await _showInputDialog(
      title: 'Đường dẫn (tùy chọn)',
      label: 'https://...',
    );
    if (!mounted) return;
    await _guard(
      () => widget.session!.workspace.addDocument(
        _projectId!,
        label,
        url: url ?? '',
      ),
      'Đã thêm tài liệu.',
    );
  }

  Future<void> _addMeeting() async {
    final label = await _showInputDialog(
      title: 'Thêm lịch họp',
      label: 'Tên cuộc họp và thời gian',
    );
    if (!mounted || label == null) return;
    await _guard(
      () => widget.session!.workspace.addMeeting(_projectId!, label),
      'Đã thêm lịch họp.',
    );
  }

  Future<void> _createVote() async {
    final question = await _showInputDialog(
      title: 'Tạo bình chọn',
      label: 'Nội dung câu hỏi',
    );
    if (!mounted || question == null) return;
    final rawOptions = await _showInputDialog(
      title: 'Các phương án',
      label: 'Ngăn cách bằng dấu phẩy (≥ 2)',
    );
    if (!mounted || rawOptions == null) return;
    final options = rawOptions
        .split(',')
        .map((o) => o.trim())
        .where((o) => o.isNotEmpty)
        .toList();
    await _guard(
      () => widget.session!.workspace.addVote(_projectId!, question, options),
      'Đã tạo bình chọn.',
    );
  }

  Future<void> _vote(String voteId, int option) => _guard(
    () => widget.session!.workspace.vote(_projectId!, voteId, option),
    'Đã ghi nhận bình chọn.',
  );

  Future<void> _removeRow(String collection, String id) => _guard(
    () => widget.session!.workspace.removeRow(_projectId!, collection, id),
    'Đã xóa.',
  );

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

  Widget _buildDocuments() {
    if (_documents.isEmpty) {
      return const Text('Chưa có tài liệu nào.');
    }
    return Column(
      children: [
        for (final doc in _documents)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text((doc['label'] ?? 'Tài liệu').toString()),
            subtitle: (doc['url'] ?? '').toString().isNotEmpty
                ? Text(
                    doc['url'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: IconButton(
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
            trailing: IconButton(
              tooltip: 'Xóa lịch họp',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy
                  ? null
                  : () => _removeRow('meetings', meeting['id'].toString()),
            ),
          ),
      ],
    );
  }

  Widget _buildVotes() {
    if (_votes.isEmpty) {
      return const Text('Chưa có bình chọn nào.');
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
        ],
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _busy ? null : _createVote,
          icon: const Icon(Icons.add_chart),
          label: const Text('Tạo bình chọn mới'),
        ),
      ],
    );
  }

  Widget _voteOptions(Map<String, dynamic> vote) {
    final options = (vote['options'] as List? ?? const []).cast<dynamic>();
    final counts = (vote['counts'] as List? ?? const []).cast<num>();
    final myVote = vote['myVote'];
    final total = (vote['totalVotes'] as num? ?? 0).toInt();
    final id = vote['id'].toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < options.length; i++)
          RadioGroup<int>(
            groupValue: myVote is int ? myVote : null,
            onChanged: (value) {
              if (value != null && myVote == null) _vote(id, value);
            },
            child: RadioListTile<int>(
              contentPadding: EdgeInsets.zero,
              title: Text(options[i].toString()),
              subtitle: Text(
                '${i < counts.length ? counts[i].toInt() : 0} phiếu',
              ),
              value: i,
              enabled: myVote == null && !_busy,
            ),
          ),
        Text('Tổng số phiếu: $total'),
      ],
    );
  }

  Widget _projectHeader(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: projects.any((p) => p['id'] == _projectId)
            ? _projectId
            : projects.first['id'].toString(),
        decoration: const InputDecoration(
          labelText: 'Dự án',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final p in projects)
            DropdownMenuItem(
              value: p['id'].toString(),
              child: Text((p['name'] ?? 'Dự án').toString()),
            ),
        ],
        onChanged: (id) {
          if (id != null) _pickProject(id);
        },
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
              'Không gian tổng hợp tài liệu, bình chọn '
              'và lịch họp của nhóm.',
            ),
            const SizedBox(height: 20),
            _projectHeader(projects),
            if (!hasProject)
              const EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'Chưa có dự án',
                message: 'Tạo hoặc tham gia một dự án để dùng Workspace.',
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
