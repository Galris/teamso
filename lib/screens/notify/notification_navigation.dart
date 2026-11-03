import 'notification_target.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../services/service_errors.dart';
import '../../widgets/app_widgets.dart';
import '../chat/chat_screen.dart';
import '../chat/direct_chat_room.dart';
import '../home/project_detail_screen.dart';
import '../workspace/workspace_screen.dart';

/// Payloads carry IDs only. Read the current user's canonical inbox entry before
/// resolving a destination, including when launched from an old FCM payload.
class NotificationNavigation {
  static bool _resolving = false;

  static Future<void> open(
    BuildContext context,
    SessionController session,
    Map<String, dynamic> payload, {
    void Function(String projectId, String taskId)? onTask,
  }) async {
    if (_resolving) return;
    _resolving = true;
    final uid = session.auth.currentUserId;
    try {
      if (uid.isEmpty) {
        throw const ServiceException('Bạn cần đăng nhập để mở thông báo.');
      }
      final id = (payload['notificationId'] ?? payload['id'] ?? '').toString();
      if (!_validId(id)) {
        throw const ServiceException('Thông báo chưa có liên kết hợp lệ.');
      }
      final saved = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(id)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (!saved.exists) {
        throw const ServiceException('Thông báo này không còn tồn tại.');
      }
      final data = saved.data()!;
      final link = NotificationTarget.fromData(data);
      final projectId = link.projectId;
      final targetId = link.targetId;
      final conversationId = link.conversationId;
      Widget? destination;
      String? taskProject, taskTarget;
      if (link.isDirect) {
        final rooms = await session.chat.directRooms().timeout(
          const Duration(seconds: 15),
        );
        final room = rooms.where((r) => r['id'] == conversationId).firstOrNull;
        if (room == null) {
          throw const ServiceException(
            'Cuộc trò chuyện không còn tồn tại hoặc bạn không có quyền truy cập.',
          );
        }
        destination = DirectChatRoom(
          session: session,
          id: conversationId,
          name: (room['name'] ?? 'Trò chuyện riêng').toString(),
        );
      } else {
        if (!_validId(projectId)) {
          throw const ServiceException('Thông báo cũ chưa có liên kết dự án.');
        }
        // Firestore Rules and ProjectService check current membership.
        final project = await session.projects
            .get(projectId)
            .timeout(const Duration(seconds: 15));
        final collection = link.collection;
        if (collection != null) {
          if (!_validId(targetId)) {
            throw const ServiceException(
              'Thông báo cũ chưa có liên kết đến nội dung.',
            );
          }
          final target = await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection(collection)
              .doc(targetId)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 15));
          if (!target.exists || target.data()?['deleting'] == true) {
            throw const ServiceException('Nội dung của thông báo đã bị xóa.');
          }
        }
        if (collection == 'tasks' && onTask != null) {
          taskProject = projectId;
          taskTarget = targetId;
        } else {
          destination = switch (collection) {
            'documents' || 'meetings' || 'votes' => Scaffold(
              appBar: AppBar(
                title: Text(switch (collection) {
                  'documents' => 'Tài liệu nhóm',
                  'meetings' => 'Lịch họp nhóm',
                  _ => 'Bình chọn nhóm',
                }),
              ),
              body: WorkspaceScreen(
                session: session,
                initialProject: project,
                focusCollection: collection,
                focusId: targetId,
              ),
            ),
            'messages' => Scaffold(
              body: ChatScreen(
                session: session,
                userName: session.user?.name ?? '',
                initialProject: project,
              ),
            ),
            'tasks' => ProjectDetailScreen(
              projectId: projectId,
              initialTaskId: targetId,
            ),
            _ => ProjectDetailScreen(projectId: projectId),
          };
        }
      }
      if (!context.mounted || session.auth.currentUserId != uid) return;
      // A read-state failure must not block opening accessible content.
      try {
        await session.notifications
            .markRead(id)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
      if (!context.mounted || session.auth.currentUserId != uid) return;
      _resolving = false;
      if (taskProject != null && taskTarget != null) {
        onTask!(taskProject, taskTarget);
        return;
      }
      final page = destination!;
      unawaited(
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page)),
      );
    } catch (error) {
      if (context.mounted && session.auth.currentUserId == uid) {
        showAppSnack(
          context,
          error is TimeoutException
              ? 'Kết nối chậm. Vui lòng thử lại.'
              : error is FormatException
              ? error.message
              : errorText(error),
          error: true,
        );
      }
    } finally {
      _resolving = false;
    }
  }

  static bool _validId(String id) =>
      id.isNotEmpty && id.length <= 1500 && !id.contains('/');
}
