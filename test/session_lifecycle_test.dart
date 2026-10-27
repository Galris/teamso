import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teamup_app/services/api_client.dart';
import 'package:teamup_app/services/auth_service.dart';
import 'package:teamup_app/controllers/session_controller.dart';

import 'support.dart';

void main() {
  test(
    'logout waits for refresh and revokes rotated token, then clears storage',
    () async {
      final store = MemoryTokenStore();
      await store.write({'accessToken': 'old', 'refreshToken': 'refresh-old'});
      final refreshing = Completer<void>(), release = Completer<void>();
      String? revoked;
      final api = ApiClient(
        store: store,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/refresh')) {
            refreshing.complete();
            await release.future;
            return http.Response(
              '{"accessToken":"new","refreshToken":"refresh-new"}',
              200,
            );
          }
          if (r.url.path.endsWith('/signout')) {
            revoked = jsonDecode(r.body)['refreshToken'] as String;
            return http.Response('{}', 200);
          }
          return r.headers['Authorization'] == 'Bearer old'
              ? http.Response('{"message":"expired"}', 401)
              : http.Response('{}', 200);
        }),
      );
      final pending = api.request('GET', '/users/me', protected: true);
      await refreshing.future;
      final logout = AuthService(api).signOut();
      release.complete();
      await pending;
      await logout;
      expect(revoked, 'refresh-new');
      expect(store.data, isNull);
      api.close();
    },
  );
  test('restore reads profile from API, and unavailable server preserves tokens for retry', () async {
    final store = MemoryTokenStore();
    await store.write({'accessToken': 'access', 'refreshToken': 'refresh'});
    bool offline = false;
    final api = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (offline) throw http.ClientException('offline');
        return http.Response(jsonEncode({'user': sampleUser()}), 200);
      }),
    );
    final session = SessionController(client: api);
    await session.restore();
    expect(session.user!.username, 'nghi');
    offline = true;
    await session.restore();
    expect(session.startupError, isNotNull);
    expect(store.data, isNotNull);
    session.dispose();
  });
  test('offline signout still removes local credentials', () async {
    final store = MemoryTokenStore();
    await store.write({'accessToken': 'access', 'refreshToken': 'refresh'});
    final api = ApiClient(
      store: store,
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(AuthService(api).signOut(), throwsA(isA<ApiException>()));
    expect(store.data, isNull);
    api.close();
  });
}
