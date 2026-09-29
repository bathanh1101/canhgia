import 'dart:math';

import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/withdraw/application/uuid_v4.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_validation.dart';
import 'package:canhgia_mobile/features/withdraw/data/bank_models.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdrawal.dart';
import 'package:flutter_test/flutter_test.dart';

Withdrawal _w(int amount, String status, DateTime at) =>
    Withdrawal(id: '$amount$status', amount: amount, status: status, bankBin: '970436', accountNumber: '0071001234', createdAt: at);

void main() {
  group('validateWithdrawAmount', () {
    test('below minimum', () {
      expect(validateWithdrawAmount(amount: 49000, available: 1000000, min: 50000), contains('50.000đ'));
    });
    test('above available balance', () {
      expect(validateWithdrawAmount(amount: 2000000, available: 1000000, min: 50000), 'Số dư khả dụng không đủ.');
    });
    test('above the remaining daily cap', () {
      final msg = validateWithdrawAmount(amount: 500000, available: 1000000, min: 50000, dailyRemaining: 300000);
      expect(msg, contains('300.000đ'));
    });
    test('valid at the boundaries', () {
      expect(validateWithdrawAmount(amount: 50000, available: 50000, min: 50000, dailyRemaining: 50000), isNull);
    });
  });

  test('parseAmount keeps digits only and guards absurd input', () {
    expect(parseAmount('500.000'), 500000);
    expect(parseAmount(''), 0);
    expect(parseAmount('abc'), 0);
    expect(parseAmount('9' * 20), 0);
  });

  group('withdrawErrorMessage', () {
    test('pin_invalid means the token expired', () {
      expect(withdrawErrorMessage(const AppFailure('pin_invalid')), contains('hết hạn'));
    });
    test('hold_active shows the until time from detail', () {
      final m = withdrawErrorMessage(const AppFailure('hold_active', detail: {'until': '2026-10-02T03:30:00Z'}));
      expect(m, contains('giữ rút tiền đến'));
      expect(m, contains('/10/2026'));
    });
    test('hold_active without detail falls back to the vocabulary message', () {
      expect(withdrawErrorMessage(const AppFailure('hold_active')), errorMessagesVi['hold_active']);
    });
    test('other vocabulary codes map through', () {
      for (final c in ['daily_cap', 'kyc_required', 'insufficient_balance', 'account_locked', 'invalid_input']) {
        expect(withdrawErrorMessage(AppFailure(c)), errorMessagesVi[c], reason: c);
      }
    });
  });

  test('dailyCapRemaining sums non-rejected withdrawals of the last 24h', () {
    final now = DateTime.utc(2026, 10, 5, 12);
    final list = [
      _w(1000000, 'pending', now.subtract(const Duration(hours: 2))),
      _w(500000, 'rejected', now.subtract(const Duration(hours: 3))),
      _w(700000, 'paid', now.subtract(const Duration(hours: 30))),
    ];
    expect(dailyCapRemaining(5000000, list, now), 4000000);
    expect(dailyCapRemaining(500000, list, now), 0);
  });

  test('PublicSettings parses jsonb numbers/strings and falls back to defaults', () {
    final s = PublicSettings.fromJson({'min_withdraw_vnd': 100000, 'withdraw_daily_cap_vnd': '3000000', 'withdraw_eta_text': ' Trong 2 ngày '});
    expect((s.minWithdrawVnd, s.dailyCapVnd, s.etaText), (100000, 3000000, 'Trong 2 ngày'));
    final d = PublicSettings.fromJson({'min_withdraw_vnd': null, 'withdraw_eta_text': ''});
    expect((d.minWithdrawVnd, d.etaText), (50000, 'Trong 1 ngày làm việc'));
    expect(d.referralBonusVnd, 30000);
  });

  test('withdrawal status labels', () {
    final now = DateTime.utc(2026);
    expect(_w(1, 'pending', now).statusLabel, 'Chờ xử lý');
    expect(_w(1, 'processing', now).statusLabel, 'Chờ xử lý');
    expect(_w(1, 'paid', now).statusLabel, 'Đã chuyển');
    expect(_w(1, 'rejected', now).statusLabel, 'Từ chối');
  });

  test('bank account mask and default pick', () {
    const a = BankAccount(id: '1', bankBin: '970436', accountNumber: '00711234567', accountName: 'A', isDefault: false);
    const b = BankAccount(id: '2', bankBin: '970407', accountNumber: '123', accountName: 'A', isDefault: true);
    expect(a.masked, '•••• 4567');
    expect(b.masked, '•••• 123');
    expect(pickDefaultAccount([a, b])!.id, '2');
    expect(pickDefaultAccount([a])!.id, '1');
    expect(pickDefaultAccount(const []), isNull);
  });

  test('uuidV4 has the v4 shape and is unique', () {
    final re = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 50; i++) uuidV4()};
    expect(ids.length, 50);
    expect(ids.every(re.hasMatch), isTrue);
    expect(uuidV4(Random(1)), uuidV4(Random(1)));
  });
}
