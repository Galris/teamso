import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/auth_widgets.dart';

const List<Color> _memberPalette = <Color>[
  Color(0xFF7C6FD0),
  Color(0xFF2FA866),
  Color(0xFFEC5FA5),
  Color(0xFF3B82F6),
  Color(0xFFF5B301),
  Color(0xFFE5484D),
  Color(0xFF14B8B8),
  Color(0xFFF97316),
  Color(0xFF8B5CF6),
  Color(0xFF84CC16),
  Color(0xFF0EA5E9),
  Color(0xFFB4538A),
];

const Color _unknownMemberColor = Color(0xFF9A98A8);

Color memberColorFor(int index) =>
    _memberPalette[index % _memberPalette.length];

/// Thành viên dự án dùng cho bình chọn: mỗi người một màu cố định.
class VoteMember {
  const VoteMember({
    required this.uid,
    required this.name,
    required this.color,
    this.avatarUrl = '',
  });

  final String uid;
  final String name;
  final String avatarUrl;
  final Color color;
}

/// Tách nhãn khung giờ `T2 05/11 · 09:00–10:00` thành ngày và giờ.
({String date, String time}) splitSlotLabel(String label) {
  final i = label.indexOf(' · ');
  if (i < 0) return (date: '', time: label.trim());
  return (date: label.substring(0, i).trim(), time: label.substring(i + 3).trim());
}

/// Avatar người đã vote xếp chồng lên nhau (kiểu Messenger), không trùng uid.
class VoterAvatars extends StatelessWidget {
  const VoterAvatars({
    super.key,
    required this.uids,
    required this.members,
    this.max = 4,
    this.radius = 11,
  });

  final List<String> uids;
  final Map<String, VoteMember> members;
  final int max;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final unique = <String>[];
    for (final uid in uids) {
      if (uid.isNotEmpty && !unique.contains(uid)) unique.add(uid);
    }
    if (unique.isEmpty) return const SizedBox.shrink();

    final shown = unique.take(max).toList();
    final extra = unique.length - shown.length;
    final total = shown.length + (extra > 0 ? 1 : 0);
    final ring = radius * 2 + 3;
    final step = radius * 1.45;

    Widget wrap(Widget child) => Container(
      width: ring,
      height: ring,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: child,
    );

    return SizedBox(
      width: step * (total - 1) + ring,
      height: ring,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * step,
              child: wrap(
                Avatar(
                  radius: radius,
                  url: members[shown[i]]?.avatarUrl ?? '',
                  name: members[shown[i]]?.name ?? '',
                ),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * step,
              child: wrap(
                CircleAvatar(
                  radius: radius,
                  backgroundColor: const Color(0xFFE7E1F5),
                  child: Text(
                    '+$extra',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkPurple,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bảng chọn giờ rảnh: cột = ngày (ở trên), dòng = khung giờ.
/// Bấm trực tiếp vào ô để chọn / bỏ chọn. Ô được chia đều theo số người rảnh,
/// mỗi phần mang màu của một thành viên (chú thích ở dưới bảng).
class MeetingVoteGrid extends StatelessWidget {
  const MeetingVoteGrid({
    super.key,
    required this.vote,
    required this.members,
    required this.myUid,
    required this.onToggle,
    this.enabled = true,
  });

  final Map<String, dynamic> vote;
  final List<VoteMember> members;
  final String myUid;
  final ValueChanged<int> onToggle;
  final bool enabled;

  static const double _timeWidth = 62;
  static const double _cellWidth = 54;
  static const double _cellHeight = 42;
  static const double _headHeight = 46;
  static const double _gap = 4;

  @override
  Widget build(BuildContext context) {
    final options = (vote['options'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    if (options.isEmpty) {
      return const Text('Bình chọn chưa có khung giờ nào.');
    }

    final dates = <String>[];
    final timeSet = <String>{};
    final cellIndex = <String, int>{};
    for (var i = 0; i < options.length; i++) {
      final s = splitSlotLabel(options[i]);
      if (!dates.contains(s.date)) dates.add(s.date);
      timeSet.add(s.time);
      cellIndex['${s.date}|${s.time}'] = i;
    }
    final times = timeSet.toList()..sort();

    final uidsByIndex = <int, List<String>>{};
    for (final voter in (vote['voters'] as List? ?? const [])) {
      if (voter is! Map) continue;
      final uid = voter['uid']?.toString() ?? '';
      if (uid.isEmpty) continue;
      for (final index in (voter['options'] as List? ?? const [])) {
        if (index is int) uidsByIndex.putIfAbsent(index, () => []).add(uid);
      }
    }

    final colorByUid = {for (final m in members) m.uid: m.color};
    // Thứ tự phần màu trong ô cố định theo thứ tự thành viên.
    final order = {for (var i = 0; i < members.length; i++) members[i].uid: i};
    for (final list in uidsByIndex.values) {
      list.sort((a, b) => (order[a] ?? 999).compareTo(order[b] ?? 999));
    }
    final counts = [
      for (var i = 0; i < options.length; i++) uidsByIndex[i]?.length ?? 0,
    ];
    final maxCount = counts.fold<int>(0, (a, b) => a > b ? a : b);

    Widget cell(String date, String time) {
      final index = cellIndex['$date|$time'];
      return SizedBox(
        width: _cellWidth + _gap,
        height: _cellHeight + _gap,
        child: Padding(
          padding: const EdgeInsets.only(right: _gap, bottom: _gap),
          child: index == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFE4E0EF)),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: enabled ? () => onToggle(index) : null,
                  child: CustomPaint(
                    painter: _SlotCellPainter(
                      colors: [
                        for (final uid in uidsByIndex[index] ?? const <String>[])
                          colorByUid[uid] ?? _unknownMemberColor,
                      ],
                      mine: (uidsByIndex[index] ?? const <String>[]).contains(
                        myUid,
                      ),
                      best: maxCount > 0 && counts[index] == maxCount,
                    ),
                  ),
                ),
        ),
      );
    }

    final bestSlots = [
      for (var i = 0; i < options.length; i++)
        if (maxCount > 0 && counts[i] == maxCount) options[i],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _timeWidth,
              child: Column(
                children: [
                  const SizedBox(height: _headHeight),
                  for (final time in times)
                    SizedBox(
                      height: _cellHeight + _gap,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: _gap),
                        child: _TimeLabel(time),
                      ),
                    ),
                ],
              ),
            ),
            // Nhiều ngày: kéo ngang, không làm bảng tràn màn hình.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final date in dates)
                          SizedBox(
                            width: _cellWidth + _gap,
                            height: _headHeight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: _gap),
                              child: _DateHead(date),
                            ),
                          ),
                      ],
                    ),
                    for (final time in times)
                      Row(children: [for (final date in dates) cell(date, time)]),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Chú thích màu thành viên.
        if (members.isNotEmpty)
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final member in members)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: member.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        member.uid == myUid ? '${member.name} (Bạn)' : member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        if (bestSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Nhiều người rảnh nhất: ${bestSlots.first}'
            '${bestSlots.length > 1 ? ' và ${bestSlots.length - 1} khung giờ khác' : ''}'
            ' ($maxCount người)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2F7D46),
            ),
          ),
        ],
      ],
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final parts = value.split('–');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.first,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        if (parts.length > 1)
          Text(
            parts.last,
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _DateHead extends StatelessWidget {
  const _DateHead(this.value);
  final String value;

  @override
  Widget build(BuildContext context) {
    final i = value.indexOf(' ');
    final weekday = i < 0 ? value : value.substring(0, i);
    final day = i < 0 ? '' : value.substring(i + 1);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          weekday,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.darkPurple,
          ),
        ),
        Text(
          day,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Vẽ một ô giờ: nền xám nếu chưa ai rảnh; nếu có thì chia đều theo số người,
/// mỗi phần là màu của một thành viên.
class _SlotCellPainter extends CustomPainter {
  _SlotCellPainter({
    required this.colors,
    required this.mine,
    required this.best,
  });

  final List<Color> colors;
  final bool mine;
  final bool best;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(9));

    if (colors.isEmpty) {
      canvas.drawRRect(rrect, Paint()..color = const Color(0xFFEFEDF5));
    } else {
      canvas.save();
      canvas.clipRRect(rrect);
      final part = size.width / colors.length;
      for (var i = 0; i < colors.length; i++) {
        canvas.drawRect(
          Rect.fromLTWH(i * part, 0, part + .6, size.height),
          Paint()..color = colors[i],
        );
      }
      canvas.restore();
    }

    if (mine) {
      canvas.drawRRect(
        rrect.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppColors.darkPurple,
      );
    }
    if (best) {
      canvas.drawCircle(
        Offset(size.width - 6, 6),
        3.5,
        Paint()..color = const Color(0xFF2FA866),
      );
      canvas.drawCircle(
        Offset(size.width - 6, 6),
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SlotCellPainter old) =>
      old.mine != mine ||
      old.best != best ||
      old.colors.length != colors.length ||
      !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
