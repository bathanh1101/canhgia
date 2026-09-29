import 'package:canhgia_mobile/features/pin/data/pin_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wallet/fake_supabase.dart';

void main() {
  late MockSupabase db;
  setUp(() => db = MockSupabase());

  test('verify parses the ok row with token', () async {
    stubRpc(db, 'verify_pin', [
      {'ok': true, 'attempts_left': 5, 'locked_until': null, 'pin_token': 'tok'}
    ]);
    final r = await PinRepository(db).verify('123456');
    expect((r.ok, r.pinToken, r.lockedUntil), (true, 'tok', null));
    expect(lastRpcParams(db, 'verify_pin'), {'p_pin': '123456'});
  });

  test('verify parses a failed row with attempts and lock', () async {
    stubRpc(db, 'verify_pin', [
      {'ok': false, 'attempts_left': 0, 'locked_until': '2026-10-05T10:15:00Z', 'pin_token': null}
    ]);
    final r = await PinRepository(db).verify('000000');
    expect((r.ok, r.attemptsLeft, r.pinToken), (false, 0, null));
    expect(r.lockedUntil, DateTime.utc(2026, 10, 5, 10, 15));
  });

  test('PIN shape is enforced before anything leaves the device', () async {
    final repo = PinRepository(db);
    for (final bad in ['12345', '1234567', 'abcdef', '12 456', '']) {
      expect(() => repo.verify(bad), throwsArgumentError, reason: bad);
      expect(() => repo.setPin(bad), throwsArgumentError, reason: bad);
    }
    verifyNever(() => db.rpc<dynamic>(any(), params: any(named: 'params'), get: any(named: 'get')));
  });

  test('setPin sends the new PIN and the optional token', () async {
    stubRpc(db, 'set_withdraw_pin', null);
    await PinRepository(db).setPin('654321', pinToken: 'tk');
    expect(lastRpcParams(db, 'set_withdraw_pin'), {'p_new': '654321', 'p_pin_token': 'tk'});
  });
}
