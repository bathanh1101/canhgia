import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_form.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdraw_repository.dart';
import 'package:canhgia_mobile/core/supabase/supabase_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wallet/fake_supabase.dart';

void main() {
  late MockSupabase db;
  setUp(() => db = MockSupabase());

  test('request sends the exact RPC params and parses the table row', () async {
    stubRpc(db, 'request_withdrawal', [
      {'withdrawal_id': 'w-1', 'status': 'pending'}
    ]);
    final r = await WithdrawRepository(db).request(requestKey: 'k', amount: 100000, bankAccountId: 'b', pinToken: 't');
    expect(r, (id: 'w-1', status: 'pending'));
    expect(lastRpcParams(db, 'request_withdrawal'), {
      'p_request_key': 'k',
      'p_amount': 100000,
      'p_bank_account_id': 'b',
      'p_pin_token': 't',
    });
  });

  test('publicSettings tolerates a non-object payload', () async {
    stubRpc(db, 'get_public_settings', null);
    expect((await WithdrawRepository(db).publicSettings()).minWithdrawVnd, 50000);
  });

  group('WithdrawForm', () {
    ProviderContainer container() {
      final c = ProviderContainer(overrides: [supabaseProvider.overrideWithValue(db)]);
      addTearDown(c.dispose);
      return c;
    }

    test('retry after a failure reuses the same request_key, then success stores the result', () async {
      final c = container();
      final sub = c.listen(withdrawFormProvider, (_, _) {});
      final form = c.read(withdrawFormProvider.notifier)
        ..setAmount(100000)
        ..selectBank('b');
      final key = c.read(withdrawFormProvider).requestKey;

      stubRpc(db, 'request_withdrawal', null, error: const AppFailure('network'));
      await expectLater(form.submit('t1'), throwsA(isA<AppFailure>()));
      expect(c.read(withdrawFormProvider).submitting, isFalse);
      expect(c.read(withdrawFormProvider).result, isNull);

      stubRpc(db, 'request_withdrawal', [
        {'withdrawal_id': 'w-1', 'status': 'pending'}
      ]);
      final r = await form.submit('t2');
      expect(r!.id, 'w-1');
      final keys = verify(() => db.rpc<dynamic>('request_withdrawal', params: captureAny(named: 'params'), get: any(named: 'get')))
          .captured
          .map((p) => (p as Map)['p_request_key']);
      expect(keys.toSet(), {key});
      expect(c.read(withdrawFormProvider).result, isNotNull);
      sub.close();
    });

    test('ignores submit without amount or bank, and while already submitting', () async {
      final c = container();
      final sub = c.listen(withdrawFormProvider, (_, _) {});
      final form = c.read(withdrawFormProvider.notifier);
      expect(await form.submit('t'), isNull);
      form
        ..setAmount(100000)
        ..selectBank('b');
      stubRpc(db, 'request_withdrawal', [
        {'withdrawal_id': 'w', 'status': 'pending'}
      ]);
      final a = form.submit('t');
      final b = form.submit('t'); // double tap
      expect(await b, isNull);
      expect(await a, isNotNull);
      verify(() => db.rpc<dynamic>('request_withdrawal', params: any(named: 'params'), get: any(named: 'get'))).called(1);
      sub.close();
    });
  });
}
