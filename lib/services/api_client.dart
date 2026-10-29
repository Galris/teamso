import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
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
      return jsonDecode(raw) as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
  ) async {
    try {
      final req = http.Request(
        method,
        Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path'),
      );
      req.headers['Content-Type'] = 'application/json';
      if (token != null) req.headers['Authorization'] = 'Bearer $token';
      if (body != null) req.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await _client.send(req),
      ))().timeout(const Duration(seconds: 15));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode >= 400) {
        throw ApiException(
          decoded['message'] as String? ?? 'Yêu cầu thất bại.',
          status: response.statusCode,
        );
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Kết nối hết thời gian. Vui lòng thử lại.');
    } on FormatException {
      throw const ApiException('Máy chủ trả dữ liệu không hợp lệ.');
    } on http.ClientException {
      throw const ApiException(
        'Không thể kết nối máy chủ. Kiểm tra mạng và địa chỉ API.',
      );
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
      } catch (_) {
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
    bool protected = false,
  }) async {
    if (protected && _ending) {
      throw const ApiException('Đang đăng xuất.', status: 401);
    }
    final generation = _epoch;
    final token = protected
        ? ((await store.read())?['accessToken'] as String?)
        : null;
    try {
      return await _send(method, path, body, token);
    } on ApiException catch (e) {
      if (!protected || (e.status != 401 && e.status != 403)) rethrow;
      if (generation != _epoch) {
        throw const ApiException('Phiên đã kết thúc.', status: 401);
      }
      await _refresh(token);
      if (generation != _epoch) {
        throw const ApiException('Phiên đã kết thúc.', status: 401);
      }
      final renewed = (await store.read())?['accessToken'] as String?;
      try {
        return await _send(method, path, body, renewed);
      } on ApiException catch (retry) {
        if (retry.status == 401 || retry.status == 403) await clearSession();
        rethrow;
      }
    }
  }

  void close() => _client.close();
}
