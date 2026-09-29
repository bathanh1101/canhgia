import 'package:canhgia_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/device/http_capture.dart';

void main() {
  test('save is a plain insert (no merge-duplicates upsert)', () async {
    final c = capturingClient();
    await VoucherRepository(c.client).save('u1', 7);
    final r = c.requests.single;
    expect(r.method, 'POST');
    expect(r.headers['Prefer'] ?? '', isNot(contains('resolution')));
    expect(r.url.queryParameters.containsKey('on_conflict'), isFalse);
  });

  SupabaseClient failing(int status, String code) => SupabaseClient('http://localhost', 'anon',
      httpClient: MockClient((r) async => http.Response('{"code":"$code","message":"x"}', status,
          request: r, headers: {'content-type': 'application/json'})));

  test('duplicate (23505) is treated as success', () async {
    await VoucherRepository(failing(409, '23505')).save('u1', 7);
  });

  test('other errors propagate', () async {
    expect(VoucherRepository(failing(403, '42501')).save('u1', 7), throwsA(isA<PostgrestException>()));
  });
}
