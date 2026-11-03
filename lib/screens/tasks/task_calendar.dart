import '../../core/theme/accent_surface.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'task_store.dart';

const Color _green = Color(0xFF439751);
const Color _purple = Color(0xFF867CB3);
const Color _pink = Color(0xFFF472B6);
const Color _darkPurple = Color(0xFF4D4379);
const Color _blue = Color(0xFF4285F4);
const Color _amber = Color(0xFFDB9B18);
const Color _red = Color(0xFFD64550);
const Color _textPrimary = Color(0xFF282638);
const Color _textSecondary = Color(0xFF858397);
const Color _border = Color(0xFFECEBF2);

const List<String> _weekdayShort = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
const List<String> _weekdayLong = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Hạn của task theo giờ địa phương; null nếu chưa đặt hoặc không đọc được.
DateTime? _dueOf(Map<String, dynamic> task) {
  final raw = task['dueDate']?.toString() ?? '';
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toLocal();
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Lịch deadline: lấy dữ liệu trực tiếp từ danh sách task (đã realtime qua
/// TaskStore). Mỗi ngày có hạn được đánh dấu chấm màu; bấm vào ngày để xem
/// danh sách task, bấm vào task để xem chú thích chi tiết.
class TaskCalendarView extends StatefulWidget {
  const TaskCalendarView({
    super.key,
    required this.store,
    required this.myTasks,
    required this.teamTasks,
  });

  final TaskStore store;

  /// Task được giao cho tôi + task tôi cần duyệt.
  final List<Map<String, dynamic>> myTasks;

  /// Mọi task trong các dự án tôi tham gia.
  final List<Map<String, dynamic>> teamTasks;

  @override
  State<TaskCalendarView> createState() => _TaskCalendarViewState();
}

class _TaskCalendarViewState extends State<TaskCalendarView> {
  late DateTime _month;
  late DateTime _selected;
  bool _team = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    final today = _dayOf(DateTime.now());
    _month = DateTime(today.year, today.month);
    _selected = today;
    // Làm mới mỗi phút để "hôm nay" và trạng thái quá hạn luôn đúng thời gian thực,
    // kể cả khi app mở qua nửa đêm.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _tasks =>
      _team ? widget.teamTasks : widget.myTasks;

  Map<DateTime, List<Map<String, dynamic>>> _groupByDay() {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final task in _tasks) {
      final due = _dueOf(task);
      if (due == null) continue;
      map.putIfAbsent(_dayOf(due), () => []).add(task);
    }
    return map;
  }

  bool _isDone(Map<String, dynamic> task) => task['status'] == 'Hoàn thành';

  bool _isOverdue(Map<String, dynamic> task) {
    if (_isDone(task)) return false;
    final due = _dueOf(task);
    return due != null && _dayOf(due).isBefore(_dayOf(DateTime.now()));
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Hoàn thành':
        return _green;
      case 'Đang làm':
        return _blue;
      case 'Chờ duyệt':
      case 'Cần bạn duyệt':
        return _amber;
      case 'Cần sửa':
        return _pink;
      default:
        return _textSecondary;
    }
  }

  Color _taskColor(Map<String, dynamic> task) => _isOverdue(task)
      ? _red
      : _statusColor(task['status']?.toString() ?? 'Cần làm');

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      _selected = DateTime(
        _month.year,
        _month.month,
        _selected.day.clamp(1, lastDay),
      );
    });
  }

  void _goToday() {
    final today = _dayOf(DateTime.now());
    setState(() {
      _month = DateTime(today.year, today.month);
      _selected = today;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selected = day;
      // Bấm vào ngày của tháng trước/sau thì chuyển lịch sang tháng đó.
      if (day.month != _month.month || day.year != _month.year) {
        _month = DateTime(day.year, day.month);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final byDay = _groupByDay();
    final selectedTasks = [...?byDay[_selected]]
      ..sort((a, b) {
        final da = _dueOf(a) ?? _selected;
        final db = _dueOf(b) ?? _selected;
        return da.compareTo(db);
      });
    final noDeadline = _tasks.where((t) => _dueOf(t) == null).length;
    final monthTasks = _tasks.where((t) {
      final due = _dueOf(t);
      return due != null &&
          due.year == _month.year &&
          due.month == _month.month;
    }).toList();
    final overdueCount = monthTasks.where(_isOverdue).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _buildScopeChips(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE6D9FA), Color(0xFFFCECF6), Color(0xFFF2E5F8)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: .9),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A4D4379),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildMonthHeader(),
              const SizedBox(height: 4),
              _buildWeekdayRow(),
              const SizedBox(height: 4),
              _buildGrid(byDay),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AccentBoxDecoration(
                  accent: _purple,
                  color: Colors.white.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _buildLegend(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _summary(
                'Trong tháng',
                monthTasks.length,
                Icons.event_note_rounded,
                _purple,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summary(
                'Quá hạn',
                overdueCount,
                Icons.event_busy_outlined,
                _red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSelectedHeader(selectedTasks.length),
        const SizedBox(height: 10),
        if (selectedTasks.isEmpty)
          _buildEmptyDay()
        else
          for (final task in selectedTasks) ...[
            _buildTaskTile(task),
            const SizedBox(height: 10),
          ],
        if (noDeadline > 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '$noDeadline công việc chưa đặt hạn nên không hiện trên lịch.',
              style: const TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _summary(String label, int count, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: AccentBoxDecoration(
          accent: color,
          color: Colors.white.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(21),
        ),
        child: Row(
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildScopeChips() => SegmentedButton<bool>(
    showSelectedIcon: false,
    segments: const [
      ButtonSegment(
        value: false,
        icon: Icon(Icons.person_outline_rounded, size: 18),
        label: Text('Của tôi'),
      ),
      ButtonSegment(
        value: true,
        icon: Icon(Icons.groups_outlined, size: 18),
        label: Text('Cả nhóm'),
      ),
    ],
    selected: {_team},
    onSelectionChanged: (value) => setState(() => _team = value.first),
    style: SegmentedButton.styleFrom(
      selectedBackgroundColor: _darkPurple,
      selectedForegroundColor: Colors.white,
      backgroundColor: Colors.white.withValues(alpha: .75),
      foregroundColor: _darkPurple,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );

  Widget _buildMonthHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
    child: Column(
      children: [
        Row(
          children: [
            const Icon(Icons.date_range_rounded, color: _purple, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Tháng ${_month.month}, ${_month.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _darkPurple,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: .65),
                foregroundColor: _darkPurple,
              ),
              onPressed: _goToday,
              child: const Text('Hôm nay'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              tooltip: 'Tháng trước',
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton.filledTonal(
              tooltip: 'Tháng sau',
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildWeekdayRow() => Row(
    children: [
      for (final label in _weekdayShort)
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDCCCF2).withValues(alpha: .8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _darkPurple,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _buildGrid(Map<DateTime, List<Map<String, dynamic>>> byDay) {
    final first = DateTime(_month.year, _month.month);
    // Thứ Hai là cột đầu tiên: DateTime.monday == 1.
    final leading = first.weekday - DateTime.monday;
    // Dựng bằng constructor (không trừ Duration) để không lệch giờ khi đổi múi giờ.
    final start = DateTime(first.year, first.month, 1 - leading);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / 7).ceil();
    final today = _dayOf(DateTime.now());

    return Column(
      children: [
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _buildDayCell(
                    DateTime(start.year, start.month, start.day + r * 7 + c),
                    byDay,
                    today,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildDayCell(
    DateTime day,
    Map<DateTime, List<Map<String, dynamic>>> byDay,
    DateTime today,
  ) {
    final inMonth = day.month == _month.month;
    final isToday = day == today;
    final isSelected = day == _selected;
    final tasks = byDay[day] ?? const <Map<String, dynamic>>[];
    final dots = tasks.take(3).map(_taskColor).toList();

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _selectDay(day),
      child: Container(
        height: 52,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? _darkPurple
              : isToday
              ? _purple.withValues(alpha: .08)
              : null,
          border: isToday && !isSelected
              ? Border.all(color: _purple, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: null),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : inMonth
                      ? _textPrimary
                      : const Color(0xFFBDBBC9),
                ),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in dots)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: .85)
                            : inMonth
                            ? color
                            : color.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (tasks.length > 3)
                    Text(
                      '+${tasks.length - 3}',
                      style: const TextStyle(
                        fontSize: 8,
                        height: 1,
                        color: _textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: _textSecondary),
        ),
      ],
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        item(_textSecondary, 'Cần làm'),
        item(_blue, 'Đang làm'),
        item(_amber, 'Chờ duyệt'),
        item(_pink, 'Cần sửa'),
        item(_green, 'Hoàn thành'),
        item(_red, 'Quá hạn'),
      ],
    );
  }

  Widget _buildSelectedHeader(int count) {
    final weekday = _weekdayLong[_selected.weekday - 1];
    final today = _dayOf(DateTime.now());
    final suffix = _selected == today ? ' · Hôm nay' : '';
    return Row(
      children: [
        const Icon(Icons.event_note_rounded, color: _purple, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '$weekday, ${_fmtDate(_selected)}$suffix',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ),
        Text(
          '$count công việc',
          style: const TextStyle(color: _textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildEmptyDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: AccentBoxDecoration(
        accent: _purple,
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_rounded, size: 36, color: _purple),
          SizedBox(height: 8),
          Text(
            'Ngày này chưa có deadline',
            style: TextStyle(color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    final color = _taskColor(task);
    final status = task['status']?.toString() ?? 'Cần làm';
    final project = widget.store.projectById(
      task['projectId']?.toString() ?? '',
    );
    final overdue = _isOverdue(task);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _showTaskDetail(task),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title']?.toString() ?? 'Công việc',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${project?['name'] ?? 'Dự án'} · '
                    '${widget.store.memberName(task['assigneeId']?.toString() ?? '')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                overdue ? 'Quá hạn' : status,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chú thích chi tiết của task
  // ---------------------------------------------------------------------------

  String _relativeDeadline(Map<String, dynamic> task) {
    final due = _dueOf(task);
    if (due == null) return '';
    final diff = _dayOf(due).difference(_dayOf(DateTime.now())).inDays;
    if (_isDone(task)) return 'Đã hoàn thành';
    if (diff == 0) return 'Hạn là hôm nay';
    if (diff > 0) return 'Còn $diff ngày';
    return 'Quá hạn ${-diff} ngày';
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    final due = _dueOf(task);
    final color = _taskColor(task);
    final status = task['status']?.toString() ?? 'Cần làm';
    final project = widget.store.projectById(
      task['projectId']?.toString() ?? '',
    );
    final ids = task['assigneeIds'];
    final assignees = ids is List && ids.isNotEmpty
        ? ids.map((id) => widget.store.memberName(id.toString())).join(', ')
        : widget.store.memberName(task['assigneeId']?.toString() ?? '');
    final description = task['description']?.toString().trim() ?? '';
    final link = task['outputLink']?.toString().trim() ?? '';
    final review = task['reviewComment']?.toString().trim() ?? '';
    final relative = _relativeDeadline(task);

    Widget row(IconData icon, String label, String value, {Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: _textSecondary),
            const SizedBox(width: 10),
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: const TextStyle(color: _textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task['title']?.toString() ?? 'Công việc',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isOverdue(task) ? 'Quá hạn' : status,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              row(
                Icons.folder_open_rounded,
                'Dự án',
                project?['name']?.toString() ?? 'Dự án',
              ),
              row(Icons.person_outline_rounded, 'Người làm', assignees),
              row(
                Icons.event_rounded,
                'Deadline',
                due == null
                    ? 'Chưa đặt hạn'
                    : '${_weekdayLong[due.weekday - 1]}, ${_fmtDate(due)}'
                          '${relative.isEmpty ? '' : '  ·  $relative'}',
                valueColor: _isOverdue(task) ? _red : null,
              ),
              if ((task['priority']?.toString() ?? '').isNotEmpty)
                row(
                  Icons.flag_outlined,
                  'Ưu tiên',
                  task['priority'].toString(),
                ),
              if (description.isNotEmpty)
                row(Icons.notes_rounded, 'Mô tả', description),
              if (review.isNotEmpty)
                row(
                  Icons.rate_review_outlined,
                  'Nhận xét',
                  review,
                  valueColor: const Color(0xFFB94B83),
                ),
              if (link.isNotEmpty)
                row(
                  Icons.link_rounded,
                  'Kết quả',
                  link,
                  valueColor: _darkPurple,
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (link.isNotEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Đã sao chép đường dẫn kết quả.'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Sao chép link'),
                      ),
                    ),
                  if (link.isNotEmpty) const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
