import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'dart:async';

import 'package:canhgia_mobile/features/withdraw/application/withdraw_form.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_providers.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdrawal.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdraw_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../core/device/http_capture.dart';
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

  test('withdrawalByKey queries request_key and maps the row / null', () async {
    final c = capturingClient(body: '{"id":"w1","amount":70000,"status":"pending","bank_bin":"1","account_number":"2","created_at":"2026-10-05T00:00:00Z"}');
    final w = await WithdrawRepository(c.client).withdrawalByKey('k1');
    expect(c.requests.single.url.queryParameters['request_key'], 'eq.k1');
    expect((w!.id, w.amount), ('w1', 70000));
  });

  group('WithdrawForm', () {
    late _MockRepo repo;
    late ProviderContainer c;
    late ProviderSubscription<WithdrawFormState> sub;
    final keys = <String>[];

    Withdrawal row(int amount) =>
        Withdrawal(id: 'w-srv', amount: amount, status: 'pending', bankBin: '1', accountNumber: '2', createdAt: DateTime.utc(2026));

    setUp(() {
      keys.clear();
      repo = _MockRepo();
      c = ProviderContainer(overrides: [withdrawRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      sub = c.listen(withdrawFormProvider, (_, _) {});
      when(() => repo.withdrawalByKey(any())).thenAnswer((_) async => null);
    });
    tearDown(() => sub.close());

    void stubRequest(Future<WithdrawalResult> Function() answer) => when(() => repo.request(
          requestKey: any(named: 'requestKey'),
          amount: any(named: 'amount'),
          bankAccountId: any(named: 'bankAccountId'),
          pinToken: any(named: 'pinToken'),
        )).thenAnswer((i) {
          keys.add(i.namedArguments[#requestKey] as String);
          return answer();
        });

    WithdrawForm form() => c.read(withdrawFormProvider.notifier)
      ..setAmount(100000)
      ..selectBank('b');

    test('network error keeps the key beyond the screen; reopened form replays the same key', () async {
      stubRequest(() async => throw const AppFailure('network'));
      await expectLater(form().submit('t1'), throwsA(isA<AppFailure>()));
      expect(c.read(pendingWithdrawalProvider)!.requestKey, keys.single);

      // Screen closed: the autoDispose form is rebuilt, the pending attempt is not.
      sub.close();
      c.invalidate(withdrawFormProvider);
      sub = c.listen(withdrawFormProvider, (_, _) {});
      stubRequest(() async => (id: 'w-1', status: 'pending'));
      final r = await form().submit('t2');
      expect(r!.id, 'w-1');
      expect(keys, hasLength(2));
      expect(keys.first, keys.last);
      expect(c.read(pendingWithdrawalProvider), isNull);
      expect(c.read(withdrawFormProvider).resultAmount, 100000);
    });

    test('after an unknown outcome the server row is shown (with its amount) and nothing new is sent', () async {
      stubRequest(() async => throw const AppFailure('network'));
      await expectLater(form().submit('t1'), throwsA(isA<AppFailure>()));
      when(() => repo.withdrawalByKey(keys.first)).thenAnswer((_) async => row(100000));
      final f = form()..setAmount(250000); // edited after the failure
      final r = await f.submit('t2');
      expect(r!.id, 'w-srv');
      expect(keys, hasLength(1));
      expect(c.read(withdrawFormProvider).resultAmount, 100000); // server amount, not the edited 250000
      expect(c.read(pendingWithdrawalProvider), isNull);
    });

    test('unknown outcome, not found, edited amount -> fresh key', () async {
      stubRequest(() async => throw const AppFailure('network'));
      await expectLater(form().submit('t1'), throwsA(isA<AppFailure>()));
      stubRequest(() async => (id: 'w-2', status: 'pending'));
      form().setAmount(250000);
      await c.read(withdrawFormProvider.notifier).submit('t2');
      expect(keys.first, isNot(keys.last));
    });

    test('a definite server error drops the key', () async {
      stubRequest(() async => throw const AppFailure('daily_cap'));
      await expectLater(form().submit('t1'), throwsA(isA<AppFailure>()));
      expect(c.read(pendingWithdrawalProvider), isNull);
      expect(c.read(withdrawFormProvider).submitting, isFalse);
      expect(c.read(withdrawFormProvider).result, isNull);
    });

    test('ignores submit without amount or bank, and while already submitting', () async {
      final f = c.read(withdrawFormProvider.notifier);
      expect(await f.submit('t'), isNull);
      final gate = Completer<WithdrawalResult>();
      stubRequest(() => gate.future);
      form();
      final a = f.submit('t');
      expect(await f.submit('t'), isNull); // double tap
      gate.complete((id: 'w', status: 'pending'));
      expect(await a, isNotNull);
      verify(() => repo.request(
          requestKey: any(named: 'requestKey'), amount: any(named: 'amount'), bankAccountId: any(named: 'bankAccountId'), pinToken: any(named: 'pinToken'))).called(1);
    });
  });
}

class _MockRepo extends Mock implements WithdrawRepository {}
