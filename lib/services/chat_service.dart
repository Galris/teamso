import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ChatService {
  ChatService(this.api);
  final ApiClient api;

  // The backend uses the authenticated user's profile, not client-supplied identity.
  Future<void> sendMessage(String text) async {
    await api.request(
      'POST',
      '/messages',
      protected: true,
      body: {'text': text},
    );
  }

  StreamSubscription<List<Map<String, dynamic>>> listenToMessages(
    void Function(List<Map<String, dynamic>>) callback, {
    required void Function(Object) onError,
  }) {
    var cancelled = false;
    http.Client? connection;
    final generation = api.epoch;
    late final StreamController<List<Map<String, dynamic>>> events;
    Future<void> run() async {
      while (!cancelled && generation == api.epoch) {
        try {
          // Uses the existing single-flight refresh logic before opening each stream.
          await api.request('GET', '/users/me', protected: true);
          if (cancelled || generation != api.epoch) break;
          final token = (await api.store.read())?['accessToken'];
          if (token is! String) {
            throw const ApiException('Vui lòng đăng nhập.', status: 401);
          }
          final client = http.Client();
          connection = client;
          final request = http.Request(
            'GET',
            Uri.parse(
              '${api.baseUrl.replaceAll(RegExp(r'/$'), '')}/messages/stream',
            ),
          );
          request.headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          });
          final response = await client
              .send(request)
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) {
            throw ApiException(
              'Không thể kết nối chat (${response.statusCode}).',
              status: response.statusCode,
            );
          }
          await for (final line
              in response.stream
                  .transform(utf8.decoder)
                  .transform(const LineSplitter())
                  .timeout(const Duration(seconds: 40))) {
            if (cancelled || generation != api.epoch) break;
            if (!line.startsWith('data: ')) continue;
            final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            if (data['error'] != null) {
              throw const ApiException('Mất kết nối Firestore. Đang thử lại…');
            }
            final messages = (data['messages'] as List)
                .cast<Map<String, dynamic>>();
            if (!events.isClosed) events.add(messages);
          }
        } catch (error) {
          if (!cancelled && generation == api.epoch && !events.isClosed) {
            events.addError(error);
          }
        } finally {
          connection?.close();
          connection = null;
        }
        if (!cancelled && generation == api.epoch) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      if (!events.isClosed) await events.close();
    }

    events = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        unawaited(run());
      },
      onCancel: () {
        cancelled = true;
        connection?.close();
      },
    );
    return events.stream.listen(callback, onError: onError);
  }
}
