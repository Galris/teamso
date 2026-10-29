import 'dart:convert';

String? requiredText(String? value) =>
    (value ?? '').trim().isEmpty ? 'Vui lòng điền trường này.' : null;
String? usernameValidator(String? value) =>
    RegExp(r'^[a-z0-9_]{3,30}$').hasMatch((value ?? '').trim().toLowerCase())
    ? null
    : 'Tên đăng nhập: 3–30 ký tự a-z, 0-9 hoặc _.';
String? emailValidator(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((value ?? '').trim())
    ? null
    : 'Email không hợp lệ.';
String? passwordValidator(String? value) => (value ?? '').length < 8
    ? 'Mật khẩu cần ít nhất 8 ký tự.'
    : utf8.encode(value!).length > 72
    ? 'Mật khẩu tối đa 72 byte UTF-8.'
    : null;
String? phoneValidator(String? value) {
  final text = (value ?? '').trim();
  final digits = text.replaceAll(RegExp(r'\D'), '');
  return text.isEmpty ||
          RegExp(r'^[+\d\s()-]+$').hasMatch(text) &&
              digits.length >= 9 &&
              digits.length <= 15
      ? null
      : 'Số điện thoại cần 9–15 chữ số.';
}
