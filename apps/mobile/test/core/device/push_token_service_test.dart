import 'package:canhgia_mobile/core/device/push_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'http_capture.dart';

void main() {
  test('upsertToken deletes any existing row for the token, then inserts for the new user', () async {
    final c = capturingClient();
    await PushTokenService(c.client).upsertToken('uid-b', 'tok');
    expect(c.requests.map((r) => r.method), ['DELETE', 'POST']);
    expect(c.requests.first.url.queryParameters['token'], 'eq.tok');
    expect(c.requests.last.body, contains('"user_id":"uid-b"'));
  });

  test('unregister is a no-op without FCM (nothing sent)', () async {
    final c = capturingClient();
    await PushTokenService(c.client).unregister();
    expect(c.requests, isEmpty);
  });
}
