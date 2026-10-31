import 'package:flutter/foundation.dart';

@immutable
class UserProject {
  const UserProject({
    required this.id,
    required this.name,
    required this.role,
    this.specificTask,
    required this.status,
  });
  final String id;
  final String name;
  final String role;
  final String? specificTask;
  final String status;

  factory UserProject.fromJson(Map<String, dynamic> json) => UserProject(
    id: _text(json['id'] ?? json['_id']),
    name: _text(json['name'], 'Dự án chưa đặt tên'),
    role: _text(json['role'], 'Thành viên'),
    specificTask: _optionalText(json['specificTask']),
    status: _text(json['status'], 'Đang thực hiện'),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'specificTask': specificTask,
    'status': status,
  };
}

// Only used when the API has not implemented the projects field yet.
// Never written back to the backend or used to authorize project access.
const previewProjects = <UserProject>[
  UserProject(
    id: 'preview-teamup',
    name: 'TeamUp – Đồ án Mobile',
    role: 'Flutter Dev',
    specificTask: 'Phụ trách đăng nhập, đăng ký và hồ sơ cá nhân.',
    status: 'Đang thực hiện',
  ),
  UserProject(
    id: 'preview-study',
    name: 'Study Together',
    role: 'UI/UX Designer',
    specificTask: 'Thiết kế giao diện và trải nghiệm học tập nhóm.',
    status: 'Hoàn thành',
  ),
];

String _text(dynamic value, [String fallback = '']) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
String? _optionalText(dynamic value) =>
    _text(value).isEmpty ? null : _text(value);

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.phone = '',
    this.specialty = '',
    this.bio = '',
    this.avatarUrl = '',
    this.studentId,
    this.className,
    this.projects = const [],
    this.projectsAreMock = false,
  });
  final String id, username, name, email, phone, specialty, bio, avatarUrl;
  final String? studentId, className;
  final List<UserProject> projects;
  final bool projectsAreMock;
  String get major => specialty;

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    UserProfile? fallback,
  }) {
    final rawProjects = json['projects'];
    final hasProjects = rawProjects is List;
    return UserProfile(
      id: _text(json['id'] ?? json['_id']),
      username: _text(json['username']),
      name: _text(json['displayName']),
      email: _text(json['email']),
      phone: _text(json['phone']),
      specialty: _text(json['major']),
      bio: _text(json['bio']),
      avatarUrl: _text(json['avatarUrl']),
      studentId: json.containsKey('studentId')
          ? _optionalText(json['studentId'])
          : fallback?.studentId,
      className: json.containsKey('className')
          ? _optionalText(json['className'])
          : fallback?.className,
      // An explicit [] means no memberships. Do not replace it with fake projects.
      projects: List<UserProject>.unmodifiable(
        hasProjects
            ? rawProjects.whereType<Map<String, dynamic>>().map(
                UserProject.fromJson,
              )
            : fallback?.projects ?? previewProjects,
      ),
      projectsAreMock: hasProjects ? false : fallback?.projectsAreMock ?? true,
    );
  }

  // Project memberships and academic identifiers are read-only in this form.
  Map<String, dynamic> toUpdateJson() => {
    'displayName': name,
    'major': specialty,
    'phone': phone,
    'bio': bio,
  };
}
