/// Định dạng thời gian của chat theo kiểu Messenger.

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

String _two(int value) => value.toString().padLeft(2, '0');

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Số ngày lịch từ [date] đến hôm nay (0 = hôm nay, 1 = hôm qua...).
int _daysAgo(DateTime date, DateTime now) =>
    _dayOf(now).difference(_dayOf(date)).inDays;

String _clock(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// `dd/MM`, thêm `/yyyy` khi khác năm hiện tại.
String _shortDate(DateTime t, DateTime now) => t.year == now.year
    ? '${_two(t.day)}/${_two(t.month)}'
    : '${_two(t.day)}/${_two(t.month)}/${t.year}';

/// Giờ dưới mỗi tin nhắn, luôn kèm ngày: `14:30 · 03/11`.
String messageTimeLabel(DateTime time, {DateTime? now}) {
  final local = time.toLocal();
  return '${_clock(local)} · ${_shortDate(local, now ?? DateTime.now())}';
}

/// Nhãn ngăn cách giữa các ngày trong khung chat:
/// `Hôm nay`, `Hôm qua`, `Thứ Hai, 27/10`, `Thứ Hai, 27/10/2025`.
String daySeparatorLabel(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = date.toLocal();
  final diff = _daysAgo(local, current);
  if (diff == 0) return 'Hôm nay';
  if (diff == 1) return 'Hôm qua';
  return '${_weekdayLong[local.weekday - 1]}, ${_shortDate(local, current)}';
}

/// Thời gian của tin nhắn mới nhất trong danh sách hội thoại:
/// hôm nay `14:30`, hôm qua `Hôm qua`, trong 7 ngày `T2`, xa hơn `dd/MM`.
String conversationTimeLabel(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final local = date.toLocal();
  final diff = _daysAgo(local, current);
  if (diff <= 0) return _clock(local);
  if (diff == 1) return 'Hôm qua';
  if (diff < 7) return _weekdayShort[local.weekday - 1];
  return _shortDate(local, current);
}
