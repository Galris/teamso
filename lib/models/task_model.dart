import 'package:flutter/foundation.dart';

@immutable
class TaskModel {
  const TaskModel({
    required this.id,
    this.projectId = '',
    this.title = '',
    this.description = '',
    this.status = 'Cần làm',
    this.priority = 'Trung bình',
    this.assigneeId = '',
    this.assigneeIds = const <String>[],
    this.dueDate,
    this.outputType = 'none',
    this.outputRequired = false,
    this.outputLink,
    this.reviewComment,
    this.createdAt,
    this.updatedAt,
    this.extra = const <String, dynamic>{},
  });

  final String id;
  final String projectId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String assigneeId;
  final List<String> assigneeIds;
  final String? dueDate;
  final String outputType;
  final bool outputRequired;
  final String? outputLink;
  final String? reviewComment;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> extra;

  bool get hasAssignee => assigneeId.isNotEmpty || assigneeIds.isNotEmpty;

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final rawAssigneeIds = json['assigneeIds'];
    final rawAssigneeId = json['assigneeId'] ?? json['assignee'];
    final assigneeIds = rawAssigneeIds is List
        ? rawAssigneeIds
            .map((item) => item?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : <String>[];

    final assignedId = rawAssigneeId == null
        ? (assigneeIds.isNotEmpty ? assigneeIds.first : '')
        : rawAssigneeId.toString();

    final projectId = _stringValue(
      json['projectId'] ?? json['project_id'] ?? json['project'],
      fallback: '',
    );

    return TaskModel(
      id: _stringValue(json['id'] ?? json['_id'] ?? json['taskId'] ?? json['task_id']),
      projectId: projectId,
      title: _stringValue(json['title'], fallback: 'Công việc chưa có tên'),
      description: _stringValue(json['description'] ?? json['detail'] ?? json['content']),
      status: _normalizeStatus(json['status'] ?? json['taskStatus'] ?? json['task_status']),
      priority: _normalizePriority(json['priority']),
      assigneeId: assignedId,
      assigneeIds: assigneeIds,
      dueDate: _nullableString(json['dueDate'] ?? json['deadline']),
      outputType: _stringValue(json['outputType'] ?? json['output_type'], fallback: 'none'),
      outputRequired: json['outputRequired'] == true || json['output_required'] == true,
      outputLink: _nullableString(json['outputLink'] ?? json['output_link']),
      reviewComment: _nullableString(json['reviewComment'] ?? json['review_comment']),
      createdAt: _nullableString(json['createdAt'] ?? json['created_at']),
      updatedAt: _nullableString(json['updatedAt'] ?? json['updated_at']),
      extra: json.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) => TaskModel.fromJson(map);

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'description': description,
    'status': _statusCode(status),
    'priority': _priorityCode(priority),
    'assigneeId': assigneeId,
    'assigneeIds': assigneeIds,
    'dueDate': dueDate,
    'outputType': outputType,
    'outputRequired': outputRequired,
    'outputLink': outputLink,
    'reviewComment': reviewComment,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    ...extra,
  };

  Map<String, dynamic> toMap() => toJson();

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    List<String>? assigneeIds,
    String? dueDate,
    String? outputType,
    bool? outputRequired,
    String? outputLink,
    String? reviewComment,
    String? createdAt,
    String? updatedAt,
    Map<String, dynamic>? extra,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeIds: assigneeIds ?? this.assigneeIds,
      dueDate: dueDate ?? this.dueDate,
      outputType: outputType ?? this.outputType,
      outputRequired: outputRequired ?? this.outputRequired,
      outputLink: outputLink ?? this.outputLink,
      reviewComment: reviewComment ?? this.reviewComment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      extra: extra ?? this.extra,
    );
  }

  static String _normalizeStatus(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Cần làm';
    final normalized = raw.toLowerCase().replaceAll('-', '_');

    switch (normalized) {
      case 'todo':
      case 'can_lam':
      case 'cần làm':
        return 'Cần làm';
      case 'in_progress':
      case 'inprogress':
      case 'đang_làm':
      case 'đang làm':
        return 'Đang làm';
      case 'pending_review':
      case 'pendingreview':
      case 'chờ_duyệt':
      case 'chờ duyệt':
        return 'Chờ duyệt';
      case 'completed':
      case 'hoàn_thành':
      case 'hoàn thành':
        return 'Hoàn thành';
      case 'revision_required':
      case 'revisionrequired':
      case 'cần_sửa':
      case 'cần sửa':
        return 'Cần sửa';
      default:
        return raw;
    }
  }

  static String _normalizePriority(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Trung bình';
    final normalized = raw.toLowerCase();

    switch (normalized) {
      case 'high':
      case 'cao':
        return 'Cao';
      case 'medium':
      case 'trung_bình':
      case 'trung bình':
        return 'Trung bình';
      case 'low':
      case 'thấp':
        return 'Thấp';
      default:
        return raw;
    }
  }

  static String _statusCode(String value) {
    switch (value) {
      case 'Cần làm':
        return 'todo';
      case 'Đang làm':
        return 'in_progress';
      case 'Chờ duyệt':
        return 'pending_review';
      case 'Hoàn thành':
        return 'completed';
      case 'Cần sửa':
        return 'revision_required';
      default:
        return value;
    }
  }

  static String _priorityCode(String value) {
    switch (value) {
      case 'Cao':
        return 'high';
      case 'Trung bình':
        return 'medium';
      case 'Thấp':
        return 'low';
      default:
        return value;
    }
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final string = value.toString().trim();
    return string.isEmpty ? fallback : string;
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final string = value.toString().trim();
    return string.isEmpty ? null : string;
  }
}
