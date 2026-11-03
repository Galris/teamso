import 'package:flutter/material.dart';

/// Loại tài liệu suy ra từ đường dẫn, dùng để chọn icon/màu/nhãn cho Workspace.
class DocKind {
  const DocKind({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  static const unknown = DocKind(
    label: 'Liên kết',
    icon: Icons.link_rounded,
    color: Color(0xFF777482),
  );

  static const _kinds = <String, DocKind>{
    'docs': DocKind(
      label: 'Tài liệu',
      icon: Icons.description_rounded,
      color: Color(0xFF4285F4),
    ),
    'sheets': DocKind(
      label: 'Bảng tính',
      icon: Icons.grid_on_rounded,
      color: Color(0xFF439751),
    ),
    'slides': DocKind(
      label: 'Slide',
      icon: Icons.slideshow_rounded,
      color: Color(0xFFFACC15),
    ),
    'forms': DocKind(
      label: 'Biểu mẫu',
      icon: Icons.checklist_rounded,
      color: Color(0xFF867CB3),
    ),
    'drive': DocKind(
      label: 'Drive',
      icon: Icons.folder_rounded,
      color: Color(0xFF439751),
    ),
    'meet': DocKind(
      label: 'Google Meet',
      icon: Icons.videocam_rounded,
      color: Color(0xFF439751),
    ),
    'zoom': DocKind(
      label: 'Zoom',
      icon: Icons.videocam_rounded,
      color: Color(0xFF4285F4),
    ),
    'teams': DocKind(
      label: 'Microsoft Teams',
      icon: Icons.groups_rounded,
      color: Color(0xFF867CB3),
    ),
    'notion': DocKind(
      label: 'Notion',
      icon: Icons.sticky_note_2_rounded,
      color: Color(0xFF252331),
    ),
    'figma': DocKind(
      label: 'Figma',
      icon: Icons.palette_rounded,
      color: Color(0xFFF472B6),
    ),
    'canva': DocKind(
      label: 'Canva',
      icon: Icons.brush_rounded,
      color: Color(0xFF4285F4),
    ),
    'miro': DocKind(
      label: 'Miro',
      icon: Icons.dashboard_rounded,
      color: Color(0xFFFACC15),
    ),
    'github': DocKind(
      label: 'GitHub',
      icon: Icons.code_rounded,
      color: Color(0xFF252331),
    ),
    'pdf': DocKind(
      label: 'PDF',
      icon: Icons.picture_as_pdf_rounded,
      color: Color(0xFFD94A4A),
    ),
  };

  /// Nhận diện theo host rồi mới tới path (Google dùng cùng host cho nhiều app).
  static DocKind detect(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.host.isEmpty) return unknown;
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host.endsWith('drive.google.com')) {
      if (path.startsWith('/document')) return _kinds['docs']!;
      if (path.startsWith('/spreadsheets')) return _kinds['sheets']!;
      if (path.startsWith('/presentation')) return _kinds['slides']!;
      if (path.startsWith('/forms')) return _kinds['forms']!;
      if (path.endsWith('.pdf')) return _kinds['pdf']!;
      return _kinds['drive']!;
    }
    if (host.endsWith('docs.google.com')) {
      if (path.startsWith('/spreadsheets')) return _kinds['sheets']!;
      if (path.startsWith('/presentation')) return _kinds['slides']!;
      if (path.startsWith('/forms')) return _kinds['forms']!;
      return _kinds['docs']!;
    }
    if (host.endsWith('sheets.google.com')) return _kinds['sheets']!;
    if (host.endsWith('slides.google.com')) return _kinds['slides']!;
    if (host.endsWith('forms.gle') || host.endsWith('meet.google.com')) {
      return host.endsWith('forms.gle') ? _kinds['forms']! : _kinds['meet']!;
    }
    if (host.contains('zoom.us') || host.contains('zoom.com')) {
      return _kinds['zoom']!;
    }
    if (host.contains('teams.microsoft.com') ||
        host.contains('teams.live.com')) {
      return _kinds['teams']!;
    }
    if (host.contains('notion.so') || host.contains('notion.site')) {
      return _kinds['notion']!;
    }
    if (host.contains('figma.com')) return _kinds['figma']!;
    if (host.contains('canva.com')) return _kinds['canva']!;
    if (host.contains('miro.com')) return _kinds['miro']!;
    if (host.contains('github.com')) return _kinds['github']!;
    if (path.endsWith('.pdf')) return _kinds['pdf']!;
    return unknown;
  }

  static bool isHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }
}
