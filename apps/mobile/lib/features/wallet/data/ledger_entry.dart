import '../../../core/utils/format_date.dart';

/// Row of `wallet_ledger` (owner-granted columns only).
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.entryType,
    required this.amountVnd,
    required this.createdAt,
    this.availableAt,
    this.promotedAt,
    this.note,
  });

  static const columns = 'id,entry_type,amount_vnd,order_id,withdrawal_id,available_at,promoted_at,note,created_at';

  final int id;
  final String entryType;
  final int amountVnd;
  final DateTime createdAt;
  final DateTime? availableAt;
  final DateTime? promotedAt;
  final String? note;

  factory LedgerEntry.fromJson(Map<String, dynamic> j) {
    DateTime? ts(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return LedgerEntry(
      id: (j['id'] as num).toInt(),
      entryType: j['entry_type'] as String,
      amountVnd: (j['amount_vnd'] as num).toInt(),
      createdAt: DateTime.parse(j['created_at'] as String),
      availableAt: ts('available_at'),
      promotedAt: ts('promoted_at'),
      note: j['note'] as String?,
    );
  }

  String get label => switch (entryType) {
        'cashback_credit' => 'Hoàn tiền đơn hàng',
        'cashback_reversal' => 'Thu hồi hoàn tiền',
        'withdrawal_debit' => 'Rút tiền',
        'withdrawal_refund' => 'Hoàn lại tiền rút',
        'referral_bonus' => 'Thưởng mời bạn',
        'referral_reversal' => 'Thu hồi thưởng mời bạn',
        'mission_bonus' => 'Thưởng nhiệm vụ',
        'manual_credit' => 'Cộng tiền',
        'manual_reversal' => 'Trừ tiền',
        _ => 'Điều chỉnh',
      };

  /// "khả dụng từ dd/mm" for a credit still held at [now].
  String? heldNote(DateTime now) =>
      amountVnd > 0 && promotedAt == null && availableAt != null && availableAt!.isAfter(now)
          ? 'khả dụng từ ${formatDayMonth(availableAt!)}'
          : null;
}
