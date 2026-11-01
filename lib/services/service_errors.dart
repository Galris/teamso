import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Lỗi nghiệp vụ có thông điệp tiếng Việt an toàn để hiển thị trực tiếp.
class ServiceException implements Exception {
  const ServiceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Chuyển lỗi Firebase/Firestore/Functions thành câu người dùng đọc được.
String errorText(Object error) {
  if (error is ServiceException) return error.message;
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-not-found':
        return 'Không tìm thấy tài khoản.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email hoặc mật khẩu không chính xác.';
      case 'email-already-in-use':
        return 'Email này đã được đăng ký.';
      case 'weak-password':
        return 'Mật khẩu chưa đủ mạnh.';
      case 'requires-recent-login':
        return 'Bạn vừa thay đổi thông tin tài khoản. Hãy đăng nhập lại rồi thử lại.';
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Không thể kết nối mạng. Vui lòng thử lại.';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.';
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'Mã đặt lại mật khẩu không hợp lệ hoặc đã hết hạn.';
      default:
        return 'Xác thực thất bại. Vui lòng thử lại.';
    }
  }
  if (error is FirebaseFunctionsException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 'unauthenticated':
        return 'Vui lòng đăng nhập để tiếp tục.';
      case 'not-found':
        return 'Không tìm thấy dữ liệu yêu cầu.';
      case 'already-exists':
        return 'Dữ liệu đã tồn tại.';
      case 'invalid-argument':
        return _orFallback(error.message, 'Dữ liệu gửi lên không hợp lệ.');
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
        return 'Máy chủ tạm thời không phản hồi. Vui lòng thử lại sau.';
      default:
        return _orFallback(error.message, 'Đã xảy ra lỗi. Vui lòng thử lại.');
    }
  }
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'Bạn không có quyền truy cập dữ liệu này.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Không kết nối được Firestore. Kiểm tra mạng rồi thử lại.';
      case 'not-found':
        return 'Không tìm thấy dữ liệu yêu cầu.';
      case 'already-exists':
        return 'Dữ liệu đã tồn tại.';
      case 'aborted':
        return 'Thao tác bị xung đột. Vui lòng thử lại.';
      case 'failed-precondition':
        return 'Truy vấn chưa được cấu hình chỉ mục. Vui lòng thử lại sau.';
      default:
        return _orFallback(error.message, 'Đã xảy ra lỗi. Vui lòng thử lại.');
    }
  }
  if (error is Exception || error is Error) {
    final message = error.toString().replaceFirst(
      RegExp(r'^Exception:\s*'),
      '',
    );
    if (message.trim().isNotEmpty && !message.startsWith('#0')) {
      return message.trim();
    }
  }
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

String _orFallback(String? message, String fallback) {
  final text = (message ?? '').trim();
  return text.isEmpty ? fallback : text;
}
