import 'package:canhgia_mobile/core/providers/referral_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/http_capture.dart';

void main() {
  Future<ReferralStore> store([String? code]) async {
    SharedPreferences.setMockInitialValues({'pending_referral_code': ?code});
    return ReferralStore(await SharedPreferences.getInstance());
  }

  test('binds the pending code through bind_referral and clears it', () async {
    final s = await store('ABCD12');
    final c = capturingClient();
    await bindPendingReferral(c.client, s);
    expect(c.requests.single.url.path, endsWith('/rpc/bind_referral'));
    expect(c.requests.single.body, contains('"p_code":"ABCD12"'));
    expect(s.pending, isNull);
  });

  test('nothing pending means no request', () async {
    final c = capturingClient();
    await bindPendingReferral(c.client, await store());
    expect(c.requests, isEmpty);
  });
}
