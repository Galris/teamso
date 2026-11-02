import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/session_controller.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';
import '../tasks/task_store.dart';

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

  bool _loading = true;
  String? _error;
  bool _busy = false;
  final Set<String> _loaded = {};

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

    _docsSub = null;
    _meetingsSub = null;
    _votesSub = null;
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

    final question = await _showInputDialog(
      title: 'Tạo bình chọn',
      label: 'Nội dung câu hỏi',
      maxLength: 500,
    );

    if (!mounted || question == null) return;

    final rawOptions = await _showInputDialog(
      title: 'Các phương án',
      label: 'Ngăn cách bằng dấu phẩy (2–20)',
      maxLength: 2400,
      validate: (value) {
        final choices = value
            .split(',')
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toList();
        if (choices.length < 2 || choices.length > 20) {
          return 'Nhập từ 2 đến 20 phương án.';
        }
        if (choices.any((v) => v.length > 120)) {
          return 'Mỗi phương án tối đa 120 ký tự.';
        }
        if (choices.map((v) => v.toLowerCase()).toSet().length !=
            choices.length) {
          return 'Các phương án không được trùng nhau.';
        }
        return null;
      },
    );

    if (!mounted || rawOptions == null) return;

    final options = rawOptions
        .split(',')
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    if (options.length < 2) {
      showAppSnack(context, 'Cần nhập ít nhất hai phương án.', error: true);
      return;
    }

    await _guard(
      () => widget.session!.workspace.addVote(projectId, question, options),
      'Đã tạo bình chọn.',
    );
  }

  // =========================================================
  // QUICK VOTE - CHỌN NHIỀU PHƯƠNG ÁN VÀ ĐỔI PHIẾU
  // =========================================================

  Future<void> _addVoteOption(Map<String, dynamic> vote) async {
    final projectId = _projectId;
    if (_busy || projectId == null || widget.session == null) return;
    final options = (vote['options'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final option = await _showInputDialog(
      title: 'Thêm đáp án',
      label: 'Đáp án mới',
      maxLength: 120,
      validate: (text) =>
          options.any((e) => e.toLowerCase() == text.toLowerCase())
          ? 'Đáp án này đã tồn tại.'
          : null,
    );
    if (!mounted || option == null) return;
    await _guard(
      () => widget.session!.workspace.addVoteOption(
        projectId,
        vote['id'].toString(),
        option,
      ),
      'Đã thêm đáp án. Các phiếu trước đó được giữ nguyên.',
    );
  }

  Future<void> _editVote(Map<String, dynamic> vote) async {
    if (_busy || _projectId == null || widget.session == null) {
      return;
    }

    final projectId = _projectId!;
    final voteId = vote['id'].toString();

    final options = (vote['options'] as List? ?? const []).toList();

    final selected = <int>{
      ...((vote['myVotes'] as List?) ?? const []).whereType<int>(),
    };

    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: const Text('Bình chọn nhóm'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (vote['question'] ?? 'Bình chọn').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bạn có thể chọn nhiều phương án '
                        'và thay đổi lựa chọn bất cứ lúc nào.',
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < options.length; i++)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(options[i].toString()),
                          value: selected.contains(i),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(i);
                              } else {
                                selected.remove(i);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final choices = selected.toList()..sort();

                    Navigator.pop(dialogContext, choices);
                  },
                  child: const Text('Lưu lựa chọn'),
                ),
              ],
            );
          },
        );
      },
    );

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
        scrollable: true,
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
    required Color color,
    required Widget child,
    VoidCallback? onAdd,
  }) {
    final accent = switch (title) {
      'Bình chọn nhóm' => const Color(0xFFA34076),
      'Lịch họp nhóm' => const Color(0xFF3968A8),
      _ => const Color(0xFF6B509C),
    };
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withValues(alpha: .78), accent],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      letterSpacing: -.4,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                if (onAdd != null)
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .85),
                      foregroundColor: accent,
                    ),
                    tooltip: 'Thêm mới',
                    onPressed: _busy ? null : onAdd,
                    icon: const Icon(Icons.add_rounded, size: 26),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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

  Widget _deleteButton(
    Map<String, dynamic> row,
    String collection,
    String label,
  ) {
    final allowed = _canDelete(row);
    return IconButton.filledTonal(
      tooltip: allowed
          ? 'Xóa $label'
          : 'Chỉ người tạo hoặc trưởng nhóm được xóa $label',
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFFFE7EC),
        foregroundColor: const Color(0xFFB03D59),
        disabledBackgroundColor: const Color(0xFFEDE7EC),
        disabledForegroundColor: const Color(0xFFAA9DA6),
      ),
      icon: const Icon(Icons.delete_outline_rounded, size: 23),
      onPressed: !allowed || _busy
          ? null
          : () => _removeRow(collection, row['id'].toString()),
    );
  }

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
            onTap: (doc['url'] ?? '').toString().isEmpty
                ? null
                : () => _openDocument(doc['url'].toString()),
            trailing: _deleteButton(doc, 'documents', 'tài liệu'),
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
            trailing: _deleteButton(meeting, 'meetings', 'lịch họp'),
          ),
      ],
    );
  }

  // =========================================================
  // HIỂN THỊ DANH SÁCH QUICK VOTE
  // =========================================================

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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(14),
                    border: const Border(
                      left: BorderSide(color: Color(0xFFA34076), width: 4),
                    ),
                  ),
                  child: Text(
                    (vote['question'] ?? 'Bình chọn').toString(),
                    style: const TextStyle(
                      fontSize: 19,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF753054),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _deleteButton(vote, 'votes', 'bình chọn'),
            ],
          ),
          const SizedBox(height: 4),
          _voteOptions(vote),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA34076),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5CAD9),
                  disabledForegroundColor: const Color(0xFF947286),
                ),
                onPressed:
                    _busy || (vote['options'] as List? ?? const []).length >= 20
                    ? null
                    : () => _addVoteOption(vote),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm đáp án'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  // =========================================================
  // HIỂN THỊ KẾT QUẢ VÀ LỰA CHỌN CỦA TỪNG NGƯỜI
  // =========================================================

  Widget _voteOptions(Map<String, dynamic> vote) {
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Material(
              color: myVotes.contains(i)
                  ? const Color(0xFFF0E9FC)
                  : const Color(0xFFFAF9FD),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _busy ? null : () => _editVote(vote),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        myVotes.contains(i)
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        color: const Color(0xFF7666A5),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              options[i].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${i < counts.length ? counts[i] : 0} phiếu',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
      padding: const EdgeInsets.only(bottom: 20),
      child: DropdownButtonFormField<String>(
        key: ValueKey(_projectId),
        initialValue:
            projects.any((project) => project['id'].toString() == _projectId)
            ? _projectId
            : projects.first['id'].toString(),
        isExpanded: true,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF332A52),
        ),
        icon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE8E0F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.expand_more_rounded,
            color: Color(0xFF4D4379),
            size: 26,
          ),
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF5F1FB),
          prefixIcon: const Icon(
            Icons.folder_rounded,
            color: Color(0xFF867CB3),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF867CB3), width: 2),
          ),
        ),
        items: [
          for (final project in projects)
            DropdownMenuItem<String>(
              value: project['id'].toString(),
              child: Text(
                (project['name'] ?? 'Dự án').toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (id) {
          if (id != null) _pickProject(id);
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

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .72, 1],
              colors: [Colors.white, Colors.white, Color(0xFFFFF1F7)],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                  color: const Color(0xFFECE4FA),
                  icon: Icons.folder_outlined,
                  onAdd: _addDocument,
                  child: _buildDocuments(),
                ),
                _buildSection(
                  title: 'Bình chọn nhóm',
                  onAdd: _createVote,
                  color: const Color(0xFFFBE7F0),
                  icon: Icons.how_to_vote_outlined,
                  child: _buildVotes(),
                ),
                _buildSection(
                  title: 'Lịch họp nhóm',
                  color: const Color(0xFFE6EEFF),
                  icon: Icons.groups_outlined,
                  onAdd: _addMeeting,
                  child: _buildMeetings(),
                ),
              ],
            ],
          ),
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
    scrollable: true,
    title: Text(widget.title),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        decoration: InputDecoration(labelText: widget.label),
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
