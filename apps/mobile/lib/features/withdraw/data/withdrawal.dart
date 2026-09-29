/// `get_public_settings()` fields the withdraw flow needs.
class PublicSettings {
  const PublicSettings({
    this.minWithdrawVnd = 50000,
    this.dailyCapVnd = 5000000,
    this.referralBonusVnd = 30000,
    this.etaText = 'Trong 1 ngày làm việc',
  });

  final int minWithdrawVnd;
  final int dailyCapVnd;
  final int referralBonusVnd;
  final String etaText;

  factory PublicSettings.fromJson(Map<String, dynamic> j) {
    int? asInt(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
    final eta = j['withdraw_eta_text'];
    const d = PublicSettings();
    return PublicSettings(
      minWithdrawVnd: asInt(j['min_withdraw_vnd']) ?? d.minWithdrawVnd,
      dailyCapVnd: asInt(j['withdraw_daily_cap_vnd']) ?? d.dailyCapVnd,
      referralBonusVnd: asInt(j['referral_bonus_vnd']) ?? d.referralBonusVnd,
      etaText: eta is String && eta.trim().isNotEmpty ? eta.trim() : d.etaText,
    );
  }
}

/// Row of `withdrawals` (columns granted to the owner; no risk/claim fields).
class Withdrawal {
  const Withdrawal({
    required this.id,
    required this.amount,
    required this.status,
    required this.bankBin,
    required this.accountNumber,
    required this.createdAt,
    this.paidAt,
    this.rejectReason,
  });

  static const columns = 'id,amount,status,bank_bin,account_number,created_at,paid_at,reject_reason';

  final String id;
  final int amount;
  final String status;
  final String bankBin;
  final String accountNumber;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? rejectReason;

  factory Withdrawal.fromJson(Map<String, dynamic> j) => Withdrawal(
        id: j['id'] as String,
        amount: (j['amount'] as num).toInt(),
        status: j['status'] as String,
        bankBin: (j['bank_bin'] as String?) ?? '',
        accountNumber: (j['account_number'] as String?) ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        paidAt: j['paid_at'] == null ? null : DateTime.parse(j['paid_at'] as String),
        rejectReason: j['reject_reason'] as String?,
      );

  /// Label per phase spec: Chờ xử lý / Đã chuyển / Từ chối.
  String get statusLabel => switch (status) {
        'paid' => 'Đã chuyển',
        'rejected' => 'Từ chối',
        _ => 'Chờ xử lý',
      };
}

/// Result of `request_withdrawal`.
typedef WithdrawalResult = ({String id, String status});

/// Amount still withdrawable today (server window = rolling 24h, rejected requests excluded).
int dailyCapRemaining(int cap, Iterable<Withdrawal> recent, DateTime now) {
  final since = now.subtract(const Duration(hours: 24));
  final used = recent.where((w) => w.status != 'rejected' && w.createdAt.isAfter(since)).fold<int>(0, (s, w) => s + w.amount);
  return (cap - used).clamp(0, cap);
}
