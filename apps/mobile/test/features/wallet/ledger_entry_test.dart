import 'package:canhgia_mobile/features/wallet/data/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 5);

  LedgerEntry e(String type, int amount, {DateTime? available, DateTime? promoted}) => LedgerEntry.fromJson({
        'id': 1,
        'entry_type': type,
        'amount_vnd': amount,
        'created_at': '2026-10-01T00:00:00Z',
        'available_at': available?.toIso8601String(),
        'promoted_at': promoted?.toIso8601String(),
        'note': null,
      });

  test('labels cover every ledger_entry_type', () {
    const types = {
      'cashback_credit': 'Hoàn tiền đơn hàng',
      'cashback_reversal': 'Thu hồi hoàn tiền',
      'withdrawal_debit': 'Rút tiền',
      'withdrawal_refund': 'Hoàn lại tiền rút',
      'referral_bonus': 'Thưởng mời bạn',
      'referral_reversal': 'Thu hồi thưởng mời bạn',
      'mission_bonus': 'Thưởng nhiệm vụ',
      'manual_credit': 'Cộng tiền',
      'manual_reversal': 'Trừ tiền',
      'admin_adjustment': 'Điều chỉnh',
    };
    for (final t in types.entries) {
      expect(e(t.key, 1).label, t.value, reason: t.key);
    }
  });

  test('heldNote only for positive, unpromoted credits with a future available_at', () {
    expect(e('cashback_credit', 100, available: DateTime.utc(2026, 10, 31, 3)).heldNote(now), 'khả dụng từ 31/10');
    expect(e('cashback_credit', 100, available: DateTime.utc(2026, 10, 1)).heldNote(now), isNull);
    expect(e('cashback_credit', 100, available: DateTime.utc(2026, 10, 31), promoted: DateTime.utc(2026, 10, 2)).heldNote(now), isNull);
    expect(e('withdrawal_debit', -100, available: DateTime.utc(2026, 10, 31)).heldNote(now), isNull);
    expect(e('cashback_credit', 100).heldNote(now), isNull);
  });
}
