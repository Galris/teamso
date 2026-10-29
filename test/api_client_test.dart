import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teamup_app/services/api_client.dart';

import 'support.dart';

void main() {
  test('concurrent 401s refresh once, store both rotated tokens and replay bearer requests', () async {
    final store = MemoryTokenStore();
    await store.write({'accessToken': 'old', 'refreshToken': 'refresh-old'});
    int refreshes = 0;
    final ready = Completer<void>();
    int oldRequests = 0;
    final client = ApiClient(
      store: store,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/auth/refresh')) {
          refreshes++;
          expect(jsonDecode(r.body)['refreshToken'], 'refresh-old');
          return http.Response(
            jsonEncode({'accessToken': 'new', 'refreshToken': 'refresh-new'}),
            200,
          );
        }
        if (r.headers['Authorization'] == 'Bearer old') {
          oldRequests++;
          if (oldRequests == 2) ready.complete();
          await ready.future;
          return http.Response('{"message":"expired"}', 401);
        }
        expect(r.headers['Authorization'], 'Bearer new');
        return http.Response('{"ok":true}', 200);
      }),
    );
    await Future.wait([
      client.request('GET', '/users/me', protected: true),
      client.request('GET', '/users/me', protected: true),
    ]);
    expect(refreshes, 1);
    expect(store.data!['refreshToken'], 'refresh-new');
    client.close();
  });
  test(
    'failed refresh clears tokens, notifies root and does not loop',
    () async {
      final store = MemoryTokenStore();
      await store.write({'accessToken': 'old', 'refreshToken': 'expired'});
      int invalidations = 0, requests = 0;
      final client = ApiClient(
        store: store,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"message":"expired"}', 401);
        }),
      );
      client.onUnauthorized = () => invalidations++;
      await expectLater(
        client.request('GET', '/users/me', protected: true),
        throwsA(isA<ApiException>()),
      );
      expect(store.data, isNull);
      expect(invalidations, 1);
      expect(requests, 2);
      client.close();
    },
  );
}
