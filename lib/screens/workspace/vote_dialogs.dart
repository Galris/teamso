import 'workspace_dialog_style.dart';

import 'package:flutter/material.dart';

import '../../utils/doc_kind.dart';

/// Bản nháp bình chọn mà dialog tạo bình chọn trả về cho Workspace.
class VoteDraft {
  const VoteDraft({
    required this.question,
    required this.kind,
    required this.options,
  });

  final String question;
  final String kind;
  final List<String> options;
}

const List<int> _slotLengths = <int>[30, 60, 90];
const int _maxSlots = 60;
const int _maxGeneralOptions = 20;

const List<String> _weekdayShort = <String>[
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN',
];

String _two(int value) => value.toString().padLeft(2, '0');

String _timeLabel(int minutes) =>
    '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

String _dateLabel(DateTime day) =>
    '${_weekdayShort[day.weekday - 1]} ${_two(day.day)}/${_two(day.month)}';

/// Sinh nhãn khung giờ kiểu When2meet từ dải ngày + khung giờ trong ngày.
List<String> buildMeetingSlots({
  required DateTime from,
  required DateTime to,
  required int startMinutes,
  required int endMinutes,
  required int slotLength,
}) {
  if (endMinutes <= startMinutes || slotLength <= 0) return const [];

  final first = DateTime(from.year, from.month, from.day);
  final last = DateTime(to.year, to.month, to.day);
  if (last.isBefore(first)) return const [];

  final slots = <String>[];

  for (
    var day = first;
    !day.isAfter(last) && slots.length < _maxSlots;
    day = day.add(const Duration(days: 1))
  ) {
    for (
      var start = startMinutes;
      start + slotLength <= endMinutes && slots.length < _maxSlots;
      start += slotLength
    ) {
      slots.add(
        '${_dateLabel(day)} · '
        '${_timeLabel(start)}–${_timeLabel(start + slotLength)}',
      );
    }
  }
  return slots;
}

/// Dialog một bước: chọn loại bình chọn rồi nhập nội dung tương ứng.
Future<VoteDraft?> showVoteCreateDialog(BuildContext context) =>
    showDialog<VoteDraft>(
      context: context,
      builder: (_) => const _VoteCreateDialog(),
    );

class _VoteCreateDialog extends StatefulWidget {
  const _VoteCreateDialog();

  @override
  State<_VoteCreateDialog> createState() => _VoteCreateDialogState();
}

class _VoteCreateDialogState extends State<_VoteCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _question = TextEditingController();
  final List<TextEditingController> _options = [
    TextEditingController(),
    TextEditingController(),
  ];

  String _kind = 'general';
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 6));
  int _startMinutes = 9 * 60;
  int _endMinutes = 18 * 60;
  int _slotLength = 60;

  @override
  void dispose() {
    _question.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> get _generatedSlots => buildMeetingSlots(
    from: _from,
    to: _to,
    startMinutes: _startMinutes,
    endMinutes: _endMinutes,
    slotLength: _slotLength,
  );

  void _addOption() {
    if (_options.length >= _maxGeneralOptions) return;
    setState(() => _options.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    setState(() => _options.removeAt(index).dispose());
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final today = DateTime.now();
    final initial = isFrom ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, 12, 31),
      helpText: isFrom ? 'TỪ NGÀY' : 'ĐẾN NGÀY',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = _to;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = TimeOfDay(
      hour: (isStart ? _startMinutes : _endMinutes) ~/ 60,
      minute: (isStart ? _startMinutes : _endMinutes) % 60,
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'GIỜ BẮT ĐẦU TRONG NGÀY' : 'GIỜ KẾT THÚC TRONG NGÀY',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      final minutes = picked.hour * 60 + picked.minute;
      if (isStart) {
        _startMinutes = minutes;
        if (_endMinutes <= _startMinutes) {
          _endMinutes = minutes + 60 > 24 * 60 ? 24 * 60 : minutes + 60;
        }
      } else {
        _endMinutes = minutes;
      }
    });
  }

  String? _validateQuestion(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Vui lòng nhập nội dung bình chọn.';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_kind == 'general') {
      final options = _options
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();

      if (options.length < 2) {
        _message('Cần ít nhất hai phương án.');
        return;
      }
      if (options.map((value) => value.toLowerCase()).toSet().length !=
          options.length) {
        _message('Các phương án không được trùng nhau.');
        return;
      }
      Navigator.pop(
        context,
        VoteDraft(
          question: _question.text.trim(),
          kind: 'general',
          options: options,
        ),
      );
      return;
    }

    final slots = _generatedSlots;
    if (slots.length < 2) {
      _message('Khung giờ chưa hợp lệ, cần ít nhất hai ô thời gian.');
      return;
    }

    Navigator.pop(
      context,
      VoteDraft(
        question: _question.text.trim(),
        kind: 'meeting',
        options: slots,
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final slots = _generatedSlots;
    final tooMany = slots.length >= _maxSlots;

    return WorkspaceDialogStyle(
      accent: const Color(0xFFA34076),
      tint: const Color(0xFFFFF1F7),
      child: AlertDialog(
        title: const WorkspaceDialogTitle(
          'Tạo bình chọn',
          icon: Icons.how_to_vote_outlined,
          color: Color(0xFFA34076),
        ),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'general',
                        icon: Icon(Icons.how_to_vote_outlined, size: 18),
                        label: Text('Bình chọn thường'),
                      ),
                      ButtonSegment(
                        value: 'meeting',
                        icon: Icon(Icons.schedule_rounded, size: 18),
                        label: Text('Khung giờ họp'),
                      ),
                    ],
                    selected: {_kind},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        setState(() => _kind = value.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _question,
                    autofocus: true,
                    maxLength: 500,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: _kind == 'general'
                          ? 'Nội dung bình chọn'
                          : 'Chủ đề cần chọn khung giờ (VD: Họp review tuần)',
                    ),
                    validator: _validateQuestion,
                  ),
                  const SizedBox(height: 8),
                  if (_kind == 'general') ...[
                    for (var i = 0; i < _options.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _options[i],
                                maxLength: 120,
                                decoration: InputDecoration(
                                  labelText: 'Phương án ${i + 1}',
                                  counterText: '',
                                ),
                                validator: _options.length <= 2 && i < 2
                                    ? (value) => (value ?? '').trim().isEmpty
                                          ? 'Không được để trống.'
                                          : null
                                    : null,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Xóa phương án',
                              onPressed: _options.length <= 2
                                  ? null
                                  : () => _removeOption(i),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _options.length >= _maxGeneralOptions
                            ? null
                            : _addOption,
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Thêm phương án (${_options.length}/'
                          '$_maxGeneralOptions)',
                        ),
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.date_range, size: 18),
                            label: Text(_dateLabel(_from)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.date_range, size: 18),
                            label: Text(_dateLabel(_to)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(isStart: true),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(_timeLabel(_startMinutes)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickTime(isStart: false),
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(_timeLabel(_endMinutes)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Độ dài mỗi ô',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final length in _slotLengths)
                          ChoiceChip(
                            label: Text('$length phút'),
                            selected: _slotLength == length,
                            onSelected: (_) =>
                                setState(() => _slotLength = length),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      slots.isEmpty
                          ? 'Chưa có khung giờ nào.'
                          : 'Sẽ có ${slots.length} khung giờ'
                                '${tooMany ? ' (tối đa $_maxSlots)' : ''}.',
                      style: TextStyle(
                        fontSize: 13,
                        color: slots.isEmpty
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final slot in slots.take(8))
                          Chip(
                            label: Text(
                              slot,
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (slots.length > 8)
                          Chip(
                            label: Text(
                              '+${slots.length - 8} khung giờ khác',
                              style: const TextStyle(fontSize: 12),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
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
          FilledButton(onPressed: _submit, child: const Text('Tạo bình chọn')),
        ],
      ),
    );
  }
}

/// Dialog tích phương án / khung giờ rảnh cho một bình chọn.
Future<List<int>?> showVoteBallotDialog(
  BuildContext context, {
  required Map<String, dynamic> vote,
}) {
  final options = (vote['options'] as List? ?? const []).toList();
  final isMeeting = vote['kind']?.toString() == 'meeting';

  final selected = <int>{
    ...((vote['myVotes'] as List?) ?? const []).whereType<int>(),
  };

  return showDialog<List<int>>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(isMeeting ? 'Khung giờ bạn rảnh' : 'Chọn phương án'),
        content: SizedBox(
          width: 420,
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
                Text(
                  isMeeting
                      ? 'Tích tất cả khung giờ bạn tham gia được. '
                            'Bỏ tích nếu bạn bận.'
                      : 'Bạn có thể chọn nhiều phương án '
                            'và thay đổi lựa chọn bất cứ lúc nào.',
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < options.length; i++)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, selected.toList()..sort()),
            child: const Text('Lưu lựa chọn'),
          ),
        ],
      ),
    ),
  );
}

const List<Color> _memberPalette = <Color>[
  Color(0xFF867CB3),
  Color(0xFF439751),
  Color(0xFFF472B6),
  Color(0xFF4285F4),
  Color(0xFFFACC15),
  Color(0xFF4D4379),
  Color(0xFFD94A4A),
  Color(0xFF00A8A8),
];

Color memberColorFor(int index) =>
    _memberPalette[index % _memberPalette.length];

/// Lưới kiểu When2meet: dòng = khung giờ, cột = thành viên.
class MeetingVoteGrid extends StatelessWidget {
  const MeetingVoteGrid({super.key, required this.vote, required this.members});

  final Map<String, dynamic> vote;
  final List<Map<String, dynamic>> members;

  static const double _slotColumnWidth = 148;
  static const double _cellWidth = 46;

  Map<String, Set<int>> _choicesByUid() {
    final result = <String, Set<int>>{};
    for (final voter in (vote['voters'] as List? ?? const [])) {
      if (voter is! Map) continue;
      final uid = voter['uid']?.toString() ?? '';
      if (uid.isEmpty) continue;
      result[uid] = (voter['options'] as List? ?? const [])
          .whereType<int>()
          .toSet();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final slots = (vote['options'] as List? ?? const []).toList();
    final counts = (vote['counts'] as List? ?? const []).cast<num>();
    final choices = _choicesByUid();
    final maxCount = counts.isEmpty
        ? 0
        : counts.map((value) => value.toInt()).reduce((a, b) => a > b ? a : b);

    if (slots.isEmpty) {
      return const Text('Bình chọn chưa có khung giờ nào.');
    }
    if (members.isEmpty) {
      return const Text('Chưa có thành viên để hiển thị lịch họp.');
    }

    final colorByUid = <String, Color>{};
    for (var i = 0; i < members.length; i++) {
      colorByUid[members[i]['uid'].toString()] = memberColorFor(i);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: _slotColumnWidth,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 6),
                  child: Text(
                    'Khung giờ',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
              for (final member in members)
                SizedBox(
                  width: _cellWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor:
                              colorByUid[member['uid'].toString()] ??
                              DocKind.unknown.color,
                          child: Text(
                            (member['initials'] ?? '?').toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          (member['name'] ?? 'TV').toString().split(' ').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          for (var row = 0; row < slots.length; row++)
            Container(
              color: maxCount > 0 && counts[row].toInt() == maxCount
                  ? const Color(0xFFEAF5EC)
                  : null,
              child: Row(
                children: [
                  SizedBox(
                    width: _slotColumnWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Text(
                        slots[row].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  for (final member in members)
                    SizedBox(
                      width: _cellWidth,
                      height: 30,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                choices[member['uid'].toString()]?.contains(
                                      row,
                                    ) ??
                                    false
                                ? colorByUid[member['uid'].toString()]
                                : const Color(0xFFF3F2F7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                    child: Text(
                      '${counts[row].toInt()} người',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            maxCount > 0 && counts[row].toInt() == maxCount
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: maxCount > 0 && counts[row].toInt() == maxCount
                            ? const Color(0xFF439751)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
