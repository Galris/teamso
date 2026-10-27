import 'package:flutter/material.dart';

class TaskStore {
  TaskStore._();

  static final TaskStore instance = TaskStore._();

  // =========================================================
  // 1. NGƯỜI DÙNG HIỆN TẠI
  // =========================================================

  final String currentUserId = 'user_linh';

  final List<Map<String, dynamic>> members = [
    {
      'id': 'user_linh',
      'name': 'Linh',
      'initials': 'L',
    },
    {
      'id': 'user_minh_anh',
      'name': 'Minh Anh',
      'initials': 'MA',
    },
    {
      'id': 'user_hoang_nam',
      'name': 'Hoàng Nam',
      'initials': 'HN',
    },
    {
      'id': 'user_thu_ha',
      'name': 'Thu Hà',
      'initials': 'TH',
    },
    {
      'id': 'user_quoc_bao',
      'name': 'Quốc Bảo',
      'initials': 'QB',
    },
    {
      'id': 'user_gia_huy',
      'name': 'Gia Huy',
      'initials': 'GH',
    },
    {
      'id': 'user_ngoc_anh',
      'name': 'Ngọc Anh',
      'initials': 'NA',
    },
    {
      'id': 'user_tuan_kiet',
      'name': 'Tuấn Kiệt',
      'initials': 'TK',
    },
    {
      'id': 'user_phuong_anh',
      'name': 'Phương Anh',
      'initials': 'PA',
    },
  ];

  // =========================================================
  // 2. DỰ ÁN
  // =========================================================

  final List<Map<String, dynamic>> projects = [
    {
      'id': 'project_uiux',
      'name': 'Design System Website',
      'tag': 'UI/UX',
      'color': const Color(0xFF867CB3),
      'leaderId': 'user_linh',
      'members': [
        'user_linh',
        'user_minh_anh',
        'user_hoang_nam',
        'user_thu_ha',
        'user_quoc_bao',
      ],
      'description': 'Xây dựng hệ thống thiết kế cho website.',
    },
    {
      'id': 'project_mobile',
      'name': 'Mobile App - Campus Life',
      'tag': 'Mobile',
      'color': const Color(0xFF439751),
      'leaderId': 'user_minh_anh',
      'members': [
        'user_minh_anh',
        'user_linh',
        'user_gia_huy',
        'user_ngoc_anh',
        'user_tuan_kiet',
      ],
      'description': 'Phát triển ứng dụng di động cho sinh viên.',
    },
    {
      'id': 'project_marketing',
      'name': 'Marketing Campaign 2026',
      'tag': 'Marketing',
      'color': const Color(0xFFF472B6),
      'leaderId': 'user_linh',
      'members': [
        'user_linh',
        'user_thu_ha',
        'user_quoc_bao',
        'user_phuong_anh',
      ],
      'description': 'Lên kế hoạch và triển khai chiến dịch truyền thông.',
    },
    {
      'id': 'project_research',
      'name': 'UI/UX Research',
      'tag': 'Research',
      'color': const Color(0xFFFACC15),
      'leaderId': 'user_hoang_nam',
      'members': [
        'user_hoang_nam',
        'user_linh',
        'user_minh_anh',
        'user_gia_huy',
        'user_ngoc_anh',
      ],
      'description': 'Nghiên cứu người dùng và đánh giá trải nghiệm.',
    },
  ];

  // =========================================================
  // 3. DỮ LIỆU CÔNG VIỆC MẪU
  //
  // Trạng thái:
  // Cần làm -> Đang làm -> Chờ duyệt -> Hoàn thành
  //                                  -> Cần sửa -> Chờ duyệt
  //
  // Công việc của Leader:
  // Cần làm -> Đang làm -> Hoàn thành
  // =========================================================

  final List<Map<String, dynamic>> tasks = [
    // ---------------- UI/UX ----------------
    {
      'id': 'task_uiux_01',
      'projectId': 'project_uiux',
      'title': 'Thiết kế giao diện trang chủ',
      'assigneeId': 'user_linh',
      'status': 'Đang làm',
      'priority': 'Cao',
      'dueDate': '2026-10-26T00:00:00',
      'outputType': 'files',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_uiux_02',
      'projectId': 'project_uiux',
      'title': 'Xây dựng bảng màu và typography',
      'assigneeId': 'user_minh_anh',
      'status': 'Chờ duyệt',
      'priority': 'Cao',
      'dueDate': '2026-10-27T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/',
      'reviewComment': '',
    },
    {
      'id': 'task_uiux_03',
      'projectId': 'project_uiux',
      'title': 'Thiết kế bộ components',
      'assigneeId': 'user_hoang_nam',
      'status': 'Cần sửa',
      'priority': 'Trung bình',
      'dueDate': '2026-10-28T00:00:00',
      'outputType': 'files',
      'outputRequired': true,
      'outputLink': 'https://figma.com/',
      'reviewComment': 'Cần thống nhất kích thước và trạng thái nút.',
    },
    {
      'id': 'task_uiux_04',
      'projectId': 'project_uiux',
      'title': 'Viết hướng dẫn sử dụng design system',
      'assigneeId': 'user_thu_ha',
      'status': 'Cần làm',
      'priority': 'Thấp',
      'dueDate': '2026-10-30T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_uiux_05',
      'projectId': 'project_uiux',
      'title': 'Kiểm tra tính nhất quán giao diện',
      'assigneeId': 'user_quoc_bao',
      'status': 'Hoàn thành',
      'priority': 'Trung bình',
      'dueDate': '2026-10-24T00:00:00',
      'outputType': 'none',
      'outputRequired': false,
      'outputLink': '',
      'reviewComment': '',
    },

    // ---------------- MOBILE ----------------
    {
      'id': 'task_mobile_01',
      'projectId': 'project_mobile',
      'title': 'Thiết kế màn hình đăng nhập',
      'assigneeId': 'user_linh',
      'status': 'Cần làm',
      'priority': 'Cao',
      'dueDate': '2026-10-27T00:00:00',
      'outputType': 'files',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_mobile_02',
      'projectId': 'project_mobile',
      'title': 'Phân tích chức năng ứng dụng',
      'assigneeId': 'user_minh_anh',
      'status': 'Đang làm',
      'priority': 'Cao',
      'dueDate': '2026-10-29T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_mobile_03',
      'projectId': 'project_mobile',
      'title': 'Thiết kế cấu trúc cơ sở dữ liệu',
      'assigneeId': 'user_gia_huy',
      'status': 'Chờ duyệt',
      'priority': 'Trung bình',
      'dueDate': '2026-10-28T00:00:00',
      'outputType': 'sheet',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/spreadsheets/',
      'reviewComment': '',
    },
    {
      'id': 'task_mobile_04',
      'projectId': 'project_mobile',
      'title': 'Kiểm thử chức năng đăng ký',
      'assigneeId': 'user_ngoc_anh',
      'status': 'Cần làm',
      'priority': 'Trung bình',
      'dueDate': '2026-10-31T00:00:00',
      'outputType': 'files',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_mobile_05',
      'projectId': 'project_mobile',
      'title': 'Hoàn thiện tài liệu yêu cầu',
      'assigneeId': 'user_tuan_kiet',
      'status': 'Hoàn thành',
      'priority': 'Thấp',
      'dueDate': '2026-10-23T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/',
      'reviewComment': '',
    },

    // ---------------- MARKETING ----------------
    {
      'id': 'task_marketing_01',
      'projectId': 'project_marketing',
      'title': 'Lên ý tưởng chiến dịch',
      'assigneeId': 'user_linh',
      'status': 'Đang làm',
      'priority': 'Cao',
      'dueDate': '2026-10-27T00:00:00',
      'outputType': 'none',
      'outputRequired': false,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_marketing_02',
      'projectId': 'project_marketing',
      'title': 'Lập lịch đăng bài truyền thông',
      'assigneeId': 'user_thu_ha',
      'status': 'Chờ duyệt',
      'priority': 'Cao',
      'dueDate': '2026-10-28T00:00:00',
      'outputType': 'sheet',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/spreadsheets/',
      'reviewComment': '',
    },
    {
      'id': 'task_marketing_03',
      'projectId': 'project_marketing',
      'title': 'Viết nội dung bài đăng đầu tiên',
      'assigneeId': 'user_quoc_bao',
      'status': 'Cần sửa',
      'priority': 'Trung bình',
      'dueDate': '2026-10-29T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/',
      'reviewComment': 'Cần chỉnh lại thông điệp và lời kêu gọi hành động.',
    },
    {
      'id': 'task_marketing_04',
      'projectId': 'project_marketing',
      'title': 'Thiết kế poster chiến dịch',
      'assigneeId': 'user_phuong_anh',
      'status': 'Cần làm',
      'priority': 'Cao',
      'dueDate': '2026-10-30T00:00:00',
      'outputType': 'files',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_marketing_05',
      'projectId': 'project_marketing',
      'title': 'Tổng hợp chỉ số truyền thông',
      'assigneeId': 'user_thu_ha',
      'status': 'Hoàn thành',
      'priority': 'Thấp',
      'dueDate': '2026-10-22T00:00:00',
      'outputType': 'sheet',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/spreadsheets/',
      'reviewComment': '',
    },

    // ---------------- RESEARCH ----------------
    {
      'id': 'task_research_01',
      'projectId': 'project_research',
      'title': 'Xây dựng bảng câu hỏi khảo sát',
      'assigneeId': 'user_linh',
      'status': 'Chờ duyệt',
      'priority': 'Cao',
      'dueDate': '2026-10-26T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/',
      'reviewComment': '',
    },
    {
      'id': 'task_research_02',
      'projectId': 'project_research',
      'title': 'Tổng hợp dữ liệu khảo sát',
      'assigneeId': 'user_minh_anh',
      'status': 'Đang làm',
      'priority': 'Cao',
      'dueDate': '2026-10-29T00:00:00',
      'outputType': 'sheet',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_research_03',
      'projectId': 'project_research',
      'title': 'Xây dựng chân dung người dùng',
      'assigneeId': 'user_gia_huy',
      'status': 'Cần làm',
      'priority': 'Trung bình',
      'dueDate': '2026-10-30T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': '',
      'reviewComment': '',
    },
    {
      'id': 'task_research_04',
      'projectId': 'project_research',
      'title': 'Phân tích insight người dùng',
      'assigneeId': 'user_ngoc_anh',
      'status': 'Hoàn thành',
      'priority': 'Trung bình',
      'dueDate': '2026-10-24T00:00:00',
      'outputType': 'docs',
      'outputRequired': true,
      'outputLink': 'https://docs.google.com/',
      'reviewComment': '',
    },
    {
      'id': 'task_research_05',
      'projectId': 'project_research',
      'title': 'Đánh giá trải nghiệm người dùng',
      'assigneeId': 'user_hoang_nam',
      'status': 'Đang làm',
      'priority': 'Thấp',
      'dueDate': '2026-11-01T00:00:00',
      'outputType': 'none',
      'outputRequired': false,
      'outputLink': '',
      'reviewComment': '',
    },
  ];

  // =========================================================
  // 4. TRA CỨU THÔNG TIN
  // =========================================================

  Map<String, dynamic>? projectById(String projectId) {
    for (final project in projects) {
      if (project['id'] == projectId) return project;
    }
    return null;
  }

  Map<String, dynamic>? memberById(String memberId) {
    for (final member in members) {
      if (member['id'] == memberId) return member;
    }
    return null;
  }

  String memberName(String memberId) {
    return memberById(memberId)?['name']?.toString() ??
        'Thành viên';
  }

  String memberInitials(String memberId) {
    return memberById(memberId)?['initials']?.toString() ??
        '?';
  }

  String roleInProject(String projectId) {
    final project = projectById(projectId);

    if (project == null) return 'Member';

    if (project['leaderId'] == currentUserId) {
      return 'Leader';
    }

    final projectMembers =
        (project['members'] as List<dynamic>? ?? [])
            .map((id) => id.toString())
            .toList();

    return projectMembers.contains(currentUserId)
        ? 'Member'
        : 'Không có quyền';
  }

  bool isMemberOfProject(String projectId, String memberId) {
    final project = projectById(projectId);
    if (project == null) return false;

    final projectMembers =
        (project['members'] as List<dynamic>? ?? [])
            .map((id) => id.toString())
            .toList();

    return projectMembers.contains(memberId);
  }

  List<Map<String, dynamic>> projectsForCurrentUser() {
    return projects.where((project) {
      return isMemberOfProject(
        project['id'].toString(),
        currentUserId,
      );
    }).toList();
  }

  List<Map<String, dynamic>> tasksForProject(String projectId) {
    return tasks.where((task) {
      return task['projectId'] == projectId;
    }).toList();
  }

  List<Map<String, dynamic>> tasksForCurrentUser() {
    return tasks.where((task) {
      return task['assigneeId'] == currentUserId;
    }).toList();
  }

  List<Map<String, dynamic>> tasksToReview() {
    return tasks.where((task) {
      final projectId = task['projectId'].toString();

      return roleInProject(projectId) == 'Leader' &&
          task['status'] == 'Chờ duyệt';
    }).toList();
  }

  int countTasks({
    String? status,
    String? projectId,
    String? assigneeId,
  }) {
    return tasks.where((task) {
      if (status != null && task['status'] != status) {
        return false;
      }

      if (projectId != null &&
          task['projectId'] != projectId) {
        return false;
      }

      if (assigneeId != null &&
          task['assigneeId'] != assigneeId) {
        return false;
      }

      return true;
    }).length;
  }

  // =========================================================
  // 5. PHÂN QUYỀN
  // =========================================================

  bool canCreateTask(String projectId) {
    return roleInProject(projectId) == 'Leader';
  }

  bool canReviewTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) return false;

    return roleInProject(task['projectId'].toString()) ==
            'Leader' &&
        task['status'] == 'Chờ duyệt';
  }

  bool canEditTask(String taskId) {
    final task = _taskById(taskId);
    if (task == null) return false;

    if (task['assigneeId'] != currentUserId) {
      return false;
    }

    return task['status'] == 'Cần làm' ||
        task['status'] == 'Đang làm' ||
        task['status'] == 'Cần sửa';
  }

  // =========================================================
  // 6. TẠO CÔNG VIỆC
  // =========================================================

  Map<String, dynamic> createTask({
    required String projectId,
    required String title,
    required String assigneeId,
    String priority = 'Trung bình',
    String? dueDate,
    String outputType = 'none',
    bool outputRequired = false,
  }) {
    if (!canCreateTask(projectId)) {
      throw Exception(
        'Chỉ Leader của dự án mới được tạo công việc.',
      );
    }

    if (title.trim().isEmpty) {
      throw Exception('Tên công việc không được để trống.');
    }

    if (projectById(projectId) == null) {
      throw Exception('Không tìm thấy dự án.');
    }

    if (!isMemberOfProject(projectId, assigneeId)) {
      throw Exception(
        'Người được giao phải là thành viên của dự án.',
      );
    }

    const validOutputTypes = {
      'docs',
      'drive',
      'sheet',
      'files',
      'none',
    };

    if (!validOutputTypes.contains(outputType)) {
      throw Exception('Loại đầu ra không hợp lệ.');
    }

    final task = <String, dynamic>{
      'id': 'task_${DateTime.now().microsecondsSinceEpoch}',
      'projectId': projectId,
      'title': title.trim(),
      'assigneeId': assigneeId,
      'status': 'Cần làm',
      'priority': priority,
      'dueDate': dueDate,
      'outputType': outputType,
      'outputRequired':
          outputType != 'none' && outputRequired,
      'outputLink': '',
      'reviewComment': '',
    };

    tasks.add(task);
    return task;
  }

  // =========================================================
  // 7. BẮT ĐẦU CÔNG VIỆC
  // =========================================================

  void startTask(String taskId) {
    final task = _taskById(taskId);

    if (task == null) {
      throw Exception('Không tìm thấy công việc.');
    }

    if (task['assigneeId'] != currentUserId) {
      throw Exception(
        'Bạn không phải người được giao công việc này.',
      );
    }

    if (task['status'] != 'Cần làm' &&
        task['status'] != 'Cần sửa') {
      throw Exception(
        'Công việc hiện tại không thể bắt đầu.',
      );
    }

    task['status'] = 'Đang làm';
  }

  // =========================================================
  // 8. GỬI KẾT QUẢ
  // =========================================================

  void submitTask(
    String taskId, {
    String outputLink = '',
  }) {
    final task = _taskById(taskId);

    if (task == null) {
      throw Exception('Không tìm thấy công việc.');
    }

    if (task['assigneeId'] != currentUserId) {
      throw Exception(
        'Bạn không phải người được giao công việc này.',
      );
    }

    final status = task['status']?.toString() ?? '';

    if (status != 'Đang làm' && status != 'Cần sửa') {
      throw Exception(
        'Chỉ có thể gửi công việc đang làm hoặc cần sửa.',
      );
    }

    final outputType =
        task['outputType']?.toString() ?? 'none';

    final outputRequired = task['outputRequired'] == true;
    final link = outputLink.trim();

    if (outputType != 'none' &&
        outputRequired &&
        link.isEmpty) {
      throw Exception(
        'Công việc này yêu cầu cung cấp kết quả đầu ra.',
      );
    }

    task['outputLink'] = link;
    task['reviewComment'] = '';

    final projectId = task['projectId'].toString();
    final isLeaderTask =
        roleInProject(projectId) == 'Leader';

    if (isLeaderTask) {
      // Leader tự thực hiện: không cần chờ duyệt.
      task['status'] = 'Hoàn thành';
    } else {
      // Member gửi kết quả cho Leader duyệt.
      task['status'] = 'Chờ duyệt';
    }
  }

  // =========================================================
  // 9. LEADER DUYỆT CÔNG VIỆC
  // =========================================================

  void approveTask(String taskId) {
    final task = _taskById(taskId);

    if (task == null) {
      throw Exception('Không tìm thấy công việc.');
    }

    final projectId = task['projectId'].toString();

    if (!canCreateTask(projectId)) {
      throw Exception(
        'Chỉ Leader của dự án mới được duyệt công việc.',
      );
    }

    if (task['status'] != 'Chờ duyệt') {
      throw Exception(
        'Công việc này không ở trạng thái chờ duyệt.',
      );
    }

    task['status'] = 'Hoàn thành';
    task['reviewComment'] = '';
  }

  // =========================================================
  // 10. LEADER YÊU CẦU CHỈNH SỬA
  // =========================================================

  void requestTaskChanges(
    String taskId, {
    String comment = '',
  }) {
    final task = _taskById(taskId);

    if (task == null) {
      throw Exception('Không tìm thấy công việc.');
    }

    final projectId = task['projectId'].toString();

    if (!canCreateTask(projectId)) {
      throw Exception(
        'Chỉ Leader của dự án mới được yêu cầu chỉnh sửa.',
      );
    }

    if (task['status'] != 'Chờ duyệt') {
      throw Exception(
        'Chỉ có thể yêu cầu sửa công việc đang chờ duyệt.',
      );
    }

    task['status'] = 'Cần sửa';
    task['reviewComment'] = comment.trim().isEmpty
        ? 'Vui lòng kiểm tra và chỉnh sửa lại kết quả.'
        : comment.trim();
  }

  // =========================================================
  // 11. TÌM CÔNG VIỆC THEO ID
  // =========================================================

  Map<String, dynamic>? _taskById(String taskId) {
    for (final task in tasks) {
      if (task['id'] == taskId) return task;
    }

    return null;
  }
}