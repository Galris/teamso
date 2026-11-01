import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0, this.isNetwork = false});
  final String message;
  final int status;

  /// true khi không tới được server (mất mạng, timeout, DNS...).
  final bool isNetwork;
  @override
  String toString() => message;
}

/// Chuyển mọi lỗi thành câu tiếng Việt an toàn để hiển thị cho người dùng.
String errorText(Object error) {
  if (error is ApiException) return error.message;
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
      case 'too-many-requests':
        return 'Bạn thao tác quá nhiều lần. Vui lòng thử lại sau.';
      case 'network-request-failed':
        return 'Không thể kết nối mạng. Vui lòng thử lại.';
    }
  }
  return 'Đã xảy ra lỗi. Vui lòng thử lại.';
}

/// File đính kèm cho request multipart (ví dụ upload avatar).
class UploadFile {
  const UploadFile({
    required this.field,
    required this.filename,
    required this.bytes,
  });
  final String field, filename;
  final List<int> bytes;
}

class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  // A single encrypted value prevents access/refresh pairs getting out of sync.
  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: 'teamup.tokens');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      await clear();
      return null;
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> tokens) =>
      _storage.write(key: 'teamup.tokens', value: jsonEncode(tokens));
  Future<void> clear() => _storage.delete(key: 'teamup.tokens');
}

class ApiClient {
  ApiClient({http.Client? client, TokenStore? store, String? baseUrl})
    : _client = client ?? http.Client(),
      store = store ?? TokenStore(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment('API_BASE_URL', defaultValue: '') {
    if (this.baseUrl.isEmpty) {
      this.baseUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:3000/api'
          : 'http://127.0.0.1:3000/api';
    }
  }
  final http.Client _client;
  final TokenStore store;
  String baseUrl;
  VoidCallback? onUnauthorized;
  Future<void>? _refreshing;
  int _epoch = 0;
  bool _ending = false;
  int get epoch => _epoch;

  static const _defaultTimeout = Duration(seconds: 15);
  static const _uploadTimeout = Duration(seconds: 60);

  /// Lấy thông điệp lỗi từ body: hỗ trợ `message` (string/list), `error`,
  /// `errors` (list string hoặc list {message}).
  static String? _extractMessage(Object? decoded) {
    if (decoded is! Map) return null;
    String? fromValue(Object? v) {
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v is Map) return fromValue(v['message']);
      if (v is List) {
        final parts = v.map(fromValue).whereType<String>().toList();
        return parts.isEmpty ? null : parts.join('\n');
      }
      return null;
    }

    return fromValue(decoded['message']) ??
        fromValue(decoded['error']) ??
        fromValue(decoded['errors']);
  }

  static String _defaultMessage(int status) {
    if (status == 400 || status == 422) return 'Dữ liệu không hợp lệ.';
    if (status == 401) return 'Phiên đăng nhập đã hết hạn.';
    if (status == 403) return 'Bạn không có quyền thực hiện thao tác này.';
    if (status == 404) return 'Không tìm thấy dữ liệu yêu cầu.';
    if (status == 409) return 'Dữ liệu đã tồn tại hoặc bị xung đột.';
    if (status == 413) return 'Tệp tải lên quá lớn.';
    if (status == 429) {
      return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
    }
    if (status >= 500) return 'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.';
    return 'Yêu cầu thất bại.';
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token, {
    Map<String, dynamic>? query,
    Duration? timeout,
    UploadFile? file,
  }) async {
    try {
      var uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
      if (query != null && query.isNotEmpty) {
        uri = uri.replace(
          queryParameters: {
            ...uri.queryParameters,
            for (final e in query.entries)
              if (e.value != null) e.key: e.value.toString(),
          },
        );
      }
      final http.BaseRequest req;
      if (file != null) {
        final multipart = http.MultipartRequest(method, uri);
        body?.forEach((k, v) {
          if (v != null) multipart.fields[k] = v.toString();
        });
        multipart.files.add(
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
          ),
        );
        req = multipart;
      } else {
        final plain = http.Request(method, uri);
        plain.headers['Content-Type'] = 'application/json';
        if (body != null) plain.body = jsonEncode(body);
        req = plain;
      }
      req.headers['Accept'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      final response =
          await (() async => http.Response.fromStream(
            await _client.send(req),
          ))().timeout(
            timeout ?? (file != null ? _uploadTimeout : _defaultTimeout),
          );

      final raw = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      Object? decoded;
      var parsed = false;
      if (raw.isEmpty) {
        decoded = <String, dynamic>{};
        parsed = true;
      } else {
        try {
          decoded = jsonDecode(raw);
          parsed = true;
        } on FormatException {
          parsed = false;
        }
      }

      if (response.statusCode >= 400) {
        throw ApiException(
          (parsed ? _extractMessage(decoded) : null) ??
              _defaultMessage(response.statusCode),
          status: response.statusCode,
        );
      }
      if (!parsed) throw const FormatException();
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'data': decoded};
      throw const FormatException();
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'Kết nối hết thời gian. Vui lòng thử lại.',
        isNetwork: true,
      );
    } on FormatException {
      throw const ApiException('Máy chủ trả dữ liệu không hợp lệ.');
    } on Exception {
      // http.ClientException, SocketException, HandshakeException...
      throw const ApiException(
        'Không thể kết nối máy chủ. Kiểm tra mạng và địa chỉ API.',
        isNetwork: true,
      );
    }
  }

  /// Gửi request; GET được thử lại 1 lần nếu lỗi mạng (an toàn vì idempotent).
  Future<Map<String, dynamic>> _sendWithRetry(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token, {
    Map<String, dynamic>? query,
    Duration? timeout,
    UploadFile? file,
  }) async {
    try {
      return await _send(
        method,
        path,
        body,
        token,
        query: query,
        timeout: timeout,
        file: file,
      );
    } on ApiException catch (e) {
      if (e.isNetwork && method == 'GET') {
        return _send(method, path, body, token, query: query, timeout: timeout);
      }
      rethrow;
    }
  }

  Future<void> saveTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'];
    final refresh = data['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const ApiException('Máy chủ không trả đủ token.');
    }
    await store.write({'accessToken': access, 'refreshToken': refresh});
  }

  Future<void> endSession() async {
    if (_ending) return;
    _ending = true;
    try {
      try {
        await _refreshing;
      } catch (_) {
        /* Already invalidated. */
      }
      final tokens = await store.read();
      if (tokens?['refreshToken'] != null) {
        await _send('POST', '/auth/signout', {
          'refreshToken': tokens!['refreshToken'],
        }, null);
      }
    } finally {
      try {
        await clearSession();
      } finally {
        _ending = false;
      }
    }
  }

  Future<void> clearSession() async {
    _epoch++;
    try {
      await store.clear();
    } finally {
      onUnauthorized?.call();
    }
  }

  Future<void> _refresh(String? failedAccess) async {
    if (_refreshing != null) return _refreshing!;
    // Another request may already have refreshed while this request was in flight.
    final latest = await store.read();
    if (latest?['accessToken'] != null &&
        latest!['accessToken'] != failedAccess) {
      return;
    }
    if (_refreshing != null) return _refreshing!;
    final generation = _epoch;
    final task = () async {
      try {
        final tokens = await store.read();
        final refresh = tokens?['refreshToken'];
        if (refresh is! String) {
          throw const ApiException('Vui lòng đăng nhập lại.', status: 401);
        }
        final data = await _send('POST', '/auth/refresh', {
          'refreshToken': refresh,
        }, null);
        if (generation != _epoch) {
          throw const ApiException('Phiên đã kết thúc.', status: 401);
        }
        await saveTokens(data);
        if (generation != _epoch) {
          await store.clear();
          throw const ApiException('Phiên đã kết thúc.', status: 401);
        }
      } on ApiException catch (e) {
        // Chỉ kết thúc phiên khi server thực sự từ chối refresh token.
        // Mất mạng / timeout / 5xx thì giữ nguyên token để thử lại sau.
        final rejected = e.status == 400 || e.status == 401 || e.status == 403;
        if (!rejected) rethrow;
        if (generation == _epoch) await clearSession();
        throw const ApiException(
          'Phiên đã kết thúc. Vui lòng đăng nhập lại.',
          status: 401,
        );
      }
    }();
    _refreshing = task;
    try {
      await task;
    } finally {
      if (identical(_refreshing, task)) _refreshing = null;
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool protected = false,
    Duration? timeout,
    UploadFile? file,
  }) async {
    if (protected && _ending) {
      throw const ApiException('Đang đăng xuất.', status: 401);
    }
    final generation = _epoch;
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final firebaseToken = protected && firebaseUser != null
        ? await firebaseUser.getIdToken()
        : null;
    final token = protected
        ? (firebaseToken ?? ((await store.read())?['accessToken'] as String?))
        : null;
    try {
      return await _sendWithRetry(
        method,
        path,
        body,
        token,
        query: query,
        timeout: timeout,
        file: file,
      );
    } on ApiException catch (e) {
      if (!protected || (e.status != 401 && e.status != 403)) rethrow;
      if (generation != _epoch) {
        throw const ApiException('Phiên đã kết thúc.', status: 401);
      }

      // Firebase-authenticated app modules use Firebase ID tokens. The API
      // backend must verify these tokens with Firebase Admin SDK.
      if (firebaseUser != null) {
        if (e.status == 403) rethrow;
        final refreshed = await firebaseUser.getIdToken(true);
        return _send(
          method,
          path,
          body,
          refreshed,
          query: query,
          timeout: timeout,
          file: file,
        );
      }

      // Legacy fallback for non-Firebase sessions only.
      await _refresh(token);
      if (generation != _epoch) {
        throw const ApiException('Phiên đã kết thúc.', status: 401);
      }
      final renewed = (await store.read())?['accessToken'] as String?;
      try {
        return await _send(
          method,
          path,
          body,
          renewed,
          query: query,
          timeout: timeout,
          file: file,
        );
      } on ApiException catch (retry) {
        if (retry.status == 401) await clearSession();
        rethrow;
      }
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool protected = true,
  }) => request('GET', path, query: query, protected: protected);
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool protected = true,
  }) => request('POST', path, body: body, protected: protected);
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool protected = true,
  }) => request('PUT', path, body: body, protected: protected);
  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool protected = true,
  }) => request('PATCH', path, body: body, protected: protected);
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool protected = true,
  }) => request('DELETE', path, body: body, protected: protected);

  void close() => _client.close();
}
