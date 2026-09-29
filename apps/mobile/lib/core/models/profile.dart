/// Row of `profiles` (own row, RLS).
class Profile {
  const Profile({
    required this.id,
    required this.referralCode,
    this.displayName,
    this.email,
    this.vipTierCode,
    this.coinBalance = 0,
    this.hasPin = false,
    this.lockedAt,
    this.onboardedAt,
    this.withdrawalHoldUntil,
    this.notificationPrefs = const {},
  });

  final String id;
  final String referralCode;
  final String? displayName;
  final String? email;
  final String? vipTierCode;
  final int coinBalance;
  final bool hasPin;
  final DateTime? lockedAt;
  final DateTime? onboardedAt;
  final DateTime? withdrawalHoldUntil;
  final Map<String, bool> notificationPrefs;

  bool get isLocked => lockedAt != null;

  String get shownName {
    final n = displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return email?.split('@').first ?? 'Bạn';
  }

  factory Profile.fromJson(Map<String, dynamic> j) {
    DateTime? ts(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    final prefs = j['notification_prefs'];
    return Profile(
      id: j['id'] as String,
      referralCode: (j['referral_code'] as String?) ?? '',
      displayName: j['display_name'] as String?,
      email: j['email'] as String?,
      vipTierCode: j['vip_tier_code'] as String?,
      coinBalance: (j['coin_balance'] as num?)?.toInt() ?? 0,
      hasPin: j['has_pin'] as bool? ?? false,
      lockedAt: ts('locked_at'),
      onboardedAt: ts('onboarded_at'),
      withdrawalHoldUntil: ts('withdrawal_hold_until'),
      notificationPrefs: prefs is Map
          ? {for (final e in prefs.entries) '${e.key}': e.value == true}
          : const {},
    );
  }
}
