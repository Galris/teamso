import 'package:flutter/material.dart';

import 'vote_dialogs.dart';
import 'vote_widgets.dart';
import 'workspace_dialog_style.dart';

const Color _accent = Color(0xFFA34076);
const Color _tint = Color(0xFFFFF1F7);

/// Kết quả chỉnh sửa bình chọn.
///
/// [indexMap] có độ dài bằng [options]: phần tử là chỉ số cũ của phương án /
/// khung giờ được giữ lại (để backend chuyển phiếu sang vị trí mới), hoặc null
/// nếu là mục mới. Phương án bị xóa không xuất hiện trong [indexMap] nên phiếu
/// của nó bị loại bỏ, các phiếu còn lại giữ nguyên.
class VoteEdit {
  const VoteEdit({
    required this.question,
    this.options,
    this.indexMap,
    this.deadlineChanged = false,
    this.deadline,
  });

  final String question;
  final List<String>? options;
  final List<int?>? indexMap;
  final bool deadlineChanged;
  final DateTime? deadline;
}

DateTime? parseVoteDeadline(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  // Firestore Timestamp có toDate(); tránh import trực tiếp ở UI.
  try {
    final dynamic d = (value as dynamic).toDate();
    if (d is DateTime) return d.toLocal();
  } catch (_) {}
  return DateTime.tryParse(value.toString())?.toLocal();
}

String _two(int v) => v.toString().padLeft(2, '0');

String formatVoteDeadline(DateTime d) =>
    '${_two(d.day)}/${_two(d.month)}/${d.year} ${_two(d.hour)}:${_two(d.minute)}';

Future<bool> _confirmLoss(BuildContext context, int lostVotes) async {
  if (lostVotes <= 0) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Xóa mục đã có phiếu?'),
      content: Text(
        'Các mục bị xóa đang có $lostVotes phiếu. Những phiếu này sẽ bị bỏ, '
        'phiếu của các mục còn lại được giữ nguyên.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Quay lại'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Vẫn xóa'),
        ),
      ],
    ),
  );
  return ok == true;
}

int _lostVotes(Map<String, dynamic> vote, List<int?> indexMap) {
  final counts = (vote['counts'] as List? ?? const []);
  final kept = indexMap.whereType<int>().toSet();
  var lost = 0;
  for (var i = 0; i < counts.length; i++) {
    if (!kept.contains(i)) lost += (counts[i] as num).toInt();
  }
  return lost;
}

// =============================================================
// SỬA BÌNH CHỌN THƯỜNG
// =============================================================

Future<VoteEdit?> showGeneralVoteEditDialog(
  BuildContext context, {
  required Map<String, dynamic> vote,
}) => showDialog<VoteEdit>(
  context: context,
  builder: (_) => _GeneralEditDialog(vote: vote),
);

class _OptionEdit {
  _OptionEdit(this.oldIndex, String text)
    : controller = TextEditingController(text: text);
  final int? oldIndex;
  final TextEditingController controller;
}

class _GeneralEditDialog extends StatefulWidget {
  const _GeneralEditDialog({required this.vote});
  final Map<String, dynamic> vote;

  @override
  State<_GeneralEditDialog> createState() => _GeneralEditDialogState();
}

class _GeneralEditDialogState extends State<_GeneralEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _question;
  late final List<_OptionEdit> _options;
  late final List<String> _original;
  DateTime? _deadline;
  late final DateTime? _originalDeadline;

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(
      text: (widget.vote['question'] ?? '').toString(),
    );
    _original = (widget.vote['options'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    _options = [
      for (var i = 0; i < _original.length; i++) _OptionEdit(i, _original[i]),
    ];
    _originalDeadline = parseVoteDeadline(widget.vote['deadline']);
    _deadline = _originalDeadline;
  }

  @override
  void dispose() {
    _question.dispose();
    for (final o in _options) {
      o.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: (_deadline != null && _deadline!.isAfter(now))
          ? _deadline!
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'CHỌN NGÀY HẾT HẠN',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deadline ?? now),
      helpText: 'CHỌN GIỜ HẾT HẠN',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!picked.isAfter(DateTime.now())) {
      _snack('Deadline phải ở trong tương lai.');
      return;
    }
    setState(() => _deadline = picked);
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final texts = [for (final o in _options) o.controller.text.trim()];
    if (texts.any((t) => t.isEmpty)) {
      _snack('Đáp án không được để trống.');
      return;
    }
    if (texts.map((t) => t.toLowerCase()).toSet().length != texts.length) {
      _snack('Các đáp án không được trùng nhau.');
      return;
    }
    if (texts.length < 2) {
      _snack('Cần ít nhất hai đáp án.');
      return;
    }

    final indexMap = [for (final o in _options) o.oldIndex];
    // Chỉ coi là sửa đáp án khi nội dung / thứ tự / số lượng thay đổi.
    var optionsChanged = texts.length != _original.length;
    for (var i = 0; !optionsChanged && i < texts.length; i++) {
      optionsChanged = texts[i] != _original[i] || indexMap[i] != i;
    }
    // Đáp án bị đổi chữ thì coi là đáp án mới (không mang phiếu sang).
    final safeMap = [
      for (var i = 0; i < _options.length; i++)
        (_options[i].oldIndex != null &&
                texts[i] == _original[_options[i].oldIndex!])
            ? _options[i].oldIndex
            : null,
    ];

    if (optionsChanged &&
        !await _confirmLoss(context, _lostVotes(widget.vote, safeMap))) {
      return;
    }
    if (!mounted) return;

    Navigator.pop(
      context,
      VoteEdit(
        question: _question.text.trim(),
        options: optionsChanged ? texts : null,
        indexMap: optionsChanged ? safeMap : null,
        deadlineChanged: _deadline != _originalDeadline,
        deadline: _deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WorkspaceDialogStyle(
    accent: _accent,
    tint: _tint,
    child: AlertDialog(
      title: const WorkspaceDialogTitle(
        'Sửa bình chọn',
        icon: Icons.edit_outlined,
        color: _accent,
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _question,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung bình chọn',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Vui lòng nhập nội dung bình chọn.'
                      : null,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _options[i].controller,
                            maxLength: 120,
                            decoration: InputDecoration(
                              labelText: 'Đáp án ${i + 1}',
                              counterText: '',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Xóa đáp án',
                          onPressed: _options.length <= 2
                              ? null
                              : () => setState(
                                  () => _options.removeAt(i).controller.dispose(),
                                ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _options.length >= voteMaxGeneralOptions
                        ? null
                        : () => setState(
                            () => _options.add(_OptionEdit(null, '')),
                          ),
                    icon: const Icon(Icons.add),
                    label: Text(
                      'Thêm đáp án (${_options.length}/$voteMaxGeneralOptions)',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDeadline,
                        icon: const Icon(Icons.timer_outlined, size: 18),
                        label: Text(
                          _deadline == null
                              ? 'Deadline (tùy chọn)'
                              : formatVoteDeadline(_deadline!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (_deadline != null)
                      IconButton(
                        tooltip: 'Bỏ deadline',
                        onPressed: () => setState(() => _deadline = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu thay đổi')),
      ],
    ),
  );
}

// =============================================================
// SỬA BÌNH CHỌN LỊCH HỌP
// =============================================================

Future<VoteEdit?> showMeetingVoteEditDialog(
  BuildContext context, {
  required Map<String, dynamic> vote,
}) => showDialog<VoteEdit>(
  context: context,
  builder: (_) => _MeetingEditDialog(vote: vote),
);

class _SlotEdit {
  _SlotEdit({this.oldIndex, this.start = 0, this.end = 0, this.raw});
  int? oldIndex;
  int start, end;

  /// Khung giờ không đọc được định dạng: giữ nguyên chữ, chỉ cho xóa.
  final String? raw;

  String get timeText => raw ?? '${voteTimeLabel(start)}–${voteTimeLabel(end)}';
}

class _DayEdit {
  _DayEdit(this.label, this.sortKey, this.slots);
  final String label;
  final int sortKey;
  final List<_SlotEdit> slots;
}

class _MeetingEditDialog extends StatefulWidget {
  const _MeetingEditDialog({required this.vote});
  final Map<String, dynamic> vote;

  @override
  State<_MeetingEditDialog> createState() => _MeetingEditDialogState();
}

class _MeetingEditDialogState extends State<_MeetingEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _question;
  late final List<String> _original;
  final List<_DayEdit> _days = [];

  static final _timeRe = RegExp(r'^(\d{1,2}):(\d{2})\s*[–-]\s*(\d{1,2}):(\d{2})$');
  static final _dayRe = RegExp(r'(\d{1,2})/(\d{1,2})');

  /// Khóa sắp xếp ngày từ nhãn `T2 05/11` (nhãn không có năm nên đoán năm).
  static int _sortKeyOf(String label) {
    final m = _dayRe.firstMatch(label);
    if (m == null) return 0;
    final day = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final now = DateTime.now();
    var year = now.year;
    if (month < now.month - 6) year++;
    return year * 10000 + month * 100 + day;
  }

  @override
  void initState() {
    super.initState();
    _question = TextEditingController(
      text: (widget.vote['question'] ?? '').toString(),
    );
    _original = (widget.vote['options'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final byDate = <String, _DayEdit>{};
    for (var i = 0; i < _original.length; i++) {
      final s = splitSlotLabel(_original[i]);
      final day = byDate.putIfAbsent(s.date, () {
        final d = _DayEdit(s.date, _sortKeyOf(s.date), []);
        _days.add(d);
        return d;
      });
      final m = _timeRe.firstMatch(s.time);
      day.slots.add(
        m == null
            ? _SlotEdit(oldIndex: i, raw: s.time)
            : _SlotEdit(
                oldIndex: i,
                start: int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!),
                end: int.parse(m.group(3)!) * 60 + int.parse(m.group(4)!),
              ),
      );
    }
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  int get _slotCount => _days.fold(0, (a, d) => a + d.slots.length);

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<TimeOfDay?> _pickTime(int minutes, String help) => showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
    helpText: help,
    cancelText: 'Hủy',
    confirmText: 'Chọn',
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  /// Chọn giờ bắt đầu - kết thúc. Trả về null nếu hủy / không hợp lệ.
  Future<(int, int)?> _pickRange(
    _DayEdit day, {
    int start = 9 * 60,
    int end = 10 * 60,
    _SlotEdit? editing,
  }) async {
    final a = await _pickTime(start, 'GIỜ BẮT ĐẦU');
    if (a == null || !mounted) return null;
    final s = a.hour * 60 + a.minute;
    final b = await _pickTime(
      end > s ? end : s + 60,
      'GIỜ KẾT THÚC',
    );
    if (b == null || !mounted) return null;
    final e = b.hour * 60 + b.minute;
    if (e <= s) {
      _snack('Giờ kết thúc phải sau giờ bắt đầu.');
      return null;
    }
    final dup = day.slots.any(
      (x) => !identical(x, editing) && x.raw == null && x.start == s && x.end == e,
    );
    if (dup) {
      _snack('Khung giờ này đã có trong ngày.');
      return null;
    }
    return (s, e);
  }

  Future<void> _addSlot(_DayEdit day) async {
    if (_slotCount >= voteMaxSlots) {
      _snack('Tối đa $voteMaxSlots khung giờ.');
      return;
    }
    final last = day.slots.where((s) => s.raw == null).lastOrNull;
    final range = await _pickRange(
      day,
      start: last?.end ?? 9 * 60,
      end: (last?.end ?? 9 * 60) + 60,
    );
    if (range == null) return;
    setState(() => day.slots.add(_SlotEdit(start: range.$1, end: range.$2)));
  }

  Future<void> _editSlot(_DayEdit day, _SlotEdit slot) async {
    if (slot.raw != null) return;
    final range = await _pickRange(
      day,
      start: slot.start,
      end: slot.end,
      editing: slot,
    );
    if (range == null) return;
    setState(() {
      if (range.$1 != slot.start || range.$2 != slot.end) {
        slot.start = range.$1;
        slot.end = range.$2;
        // Đổi khung thời gian = khung giờ mới, phiếu cũ không còn đúng nghĩa.
        slot.oldIndex = null;
      }
    });
  }

  Future<void> _addDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'THÊM NGÀY',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;
    final label = voteDateLabel(picked);
    if (_days.any((d) => d.label == label)) {
      _snack('Ngày này đã có trong bình chọn.');
      return;
    }
    // Sao chép các khung giờ của ngày đầu tiên cho tiện.
    final template = _days.isEmpty
        ? <(int, int)>[(9 * 60, 10 * 60)]
        : [
            for (final s in _days.first.slots)
              if (s.raw == null) (s.start, s.end),
          ];
    if (_slotCount + template.length > voteMaxSlots) {
      _snack('Vượt quá $voteMaxSlots khung giờ, hãy xóa bớt trước khi thêm ngày.');
      return;
    }
    setState(() {
      _days.add(
        _DayEdit(label, picked.year * 10000 + picked.month * 100 + picked.day, [
          for (final t in template) _SlotEdit(start: t.$1, end: t.$2),
        ]),
      );
      _days.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final days = [
      for (final d in _days)
        if (d.slots.isNotEmpty) d,
    ];
    final options = <String>[];
    final indexMap = <int?>[];
    for (final day in days) {
      final slots = [...day.slots]
        ..sort((a, b) => a.raw != null || b.raw != null ? 0 : a.start.compareTo(b.start));
      for (final slot in slots) {
        options.add(
          day.label.isEmpty ? slot.timeText : '${day.label} · ${slot.timeText}',
        );
        indexMap.add(slot.oldIndex);
      }
    }
    if (options.length < 2) {
      _snack('Cần ít nhất hai khung giờ.');
      return;
    }

    var changed = options.length != _original.length;
    for (var i = 0; !changed && i < options.length; i++) {
      changed = options[i] != _original[i] || indexMap[i] != i;
    }
    if (changed &&
        !await _confirmLoss(context, _lostVotes(widget.vote, indexMap))) {
      return;
    }
    if (!mounted) return;

    Navigator.pop(
      context,
      VoteEdit(
        question: _question.text.trim(),
        options: changed ? options : null,
        indexMap: changed ? indexMap : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => WorkspaceDialogStyle(
    accent: _accent,
    tint: _tint,
    child: AlertDialog(
      title: const WorkspaceDialogTitle(
        'Sửa lịch họp',
        icon: Icons.edit_calendar_outlined,
        color: _accent,
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _question,
                  maxLength: 500,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Vui lòng nhập tiêu đề.'
                      : null,
                ),
                const SizedBox(height: 8),
                for (final day in _days)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                day.label.isEmpty ? 'Khung giờ' : day.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa ngày',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _days.remove(day)),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final slot in day.slots)
                              InputChip(
                                label: Text(slot.timeText),
                                onPressed: slot.raw != null
                                    ? null
                                    : () => _editSlot(day, slot),
                                onDeleted: () =>
                                    setState(() => day.slots.remove(slot)),
                                deleteButtonTooltipMessage: 'Xóa giờ',
                                visualDensity: VisualDensity.compact,
                              ),
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 16),
                              label: const Text('Thêm giờ'),
                              onPressed: () => _addSlot(day),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _addDay,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Thêm ngày'),
                  ),
                ),
                Text(
                  '$_slotCount/$voteMaxSlots khung giờ. Bấm vào một khung giờ '
                  'để điều chỉnh thời gian. Phiếu của các khung giờ không đổi '
                  'được giữ nguyên.',
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _save, child: const Text('Lưu thay đổi')),
      ],
    ),
  );
}
