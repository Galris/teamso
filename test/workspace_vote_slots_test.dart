import 'package:flutter_test/flutter_test.dart';
import 'package:teamup_app/screens/workspace/vote_dialogs.dart';
import 'package:teamup_app/utils/doc_kind.dart';

void main() {
  group('buildMeetingSlots', () {
    test('sinh khung giờ theo dải ngày và độ dài ô', () {
      final slots = buildMeetingSlots(
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 11, 4),
        startMinutes: 9 * 60,
        endMinutes: 11 * 60,
        slotLength: 60,
      );

      expect(slots, [
        'T3 03/11 · 09:00–10:00',
        'T3 03/11 · 10:00–11:00',
        'T4 04/11 · 09:00–10:00',
        'T4 04/11 · 10:00–11:00',
      ]);
    });

    test('bỏ ô cuối khi không vừa khung giờ trong ngày', () {
      final slots = buildMeetingSlots(
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 11, 3),
        startMinutes: 9 * 60,
        endMinutes: 11 * 60,
        slotLength: 90,
      );

      expect(slots, ['T3 03/11 · 09:00–10:30']);
    });

    test('giới hạn 60 ô như backend và trả rỗng khi giờ sai', () {
      final many = buildMeetingSlots(
        from: DateTime(2026, 11, 3),
        to: DateTime(2026, 12, 31),
        startMinutes: 0,
        endMinutes: 24 * 60,
        slotLength: 30,
      );
      expect(many.length, 60);

      expect(
        buildMeetingSlots(
          from: DateTime(2026, 11, 3),
          to: DateTime(2026, 11, 3),
          startMinutes: 11 * 60,
          endMinutes: 9 * 60,
          slotLength: 60,
        ),
        isEmpty,
      );

      expect(
        buildMeetingSlots(
          from: DateTime(2026, 11, 5),
          to: DateTime(2026, 11, 3),
          startMinutes: 9 * 60,
          endMinutes: 12 * 60,
          slotLength: 60,
        ),
        isEmpty,
      );
    });
  });

  group('DocKind.detect', () {
    test('phân loại theo path của Google Drive', () {
      expect(
        DocKind.detect('https://drive.google.com/document/d/1abc').label,
        'Tài liệu',
      );
      expect(
        DocKind.detect('https://drive.google.com/spreadsheets/d/1abc').label,
        'Bảng tính',
      );
      expect(
        DocKind.detect('https://drive.google.com/drive/folders/1abc').label,
        'Drive',
      );
    });

    test('phân loại theo host', () {
      expect(
        DocKind.detect('https://docs.google.com/forms/d/e/1x/viewform').label,
        'Biểu mẫu',
      );
      expect(
        DocKind.detect('https://meet.google.com/abc-defg-hij').label,
        'Google Meet',
      );
      expect(DocKind.detect('https://us02web.zoom.us/j/123456').label, 'Zoom');
      expect(
        DocKind.detect('https://teams.live.com/l/meeting/abc').label,
        'Microsoft Teams',
      );
      expect(
        DocKind.detect('https://www.figma.com/file/abc/Flow').label,
        'Figma',
      );
      expect(
        DocKind.detect('https://team.notion.so/Board-abc').label,
        'Notion',
      );
      expect(DocKind.detect('https://example.com/report.pdf').label, 'PDF');
      expect(DocKind.detect('https://example.com/any/page').label, 'Liên kết');
      expect(DocKind.detect('không phải link').label, 'Liên kết');
    });

    test('isHttpUrl chặn link thiếu protocol và có tài khoản', () {
      expect(DocKind.isHttpUrl('https://docs.google.com/x'), isTrue);
      expect(DocKind.isHttpUrl('meet.google.com/abc'), isFalse);
      expect(DocKind.isHttpUrl('https://user:pass@example.com'), isFalse);
      expect(DocKind.isHttpUrl('javascript:alert(1)'), isFalse);
      expect(DocKind.isHttpUrl(''), isFalse);
    });
  });
}
