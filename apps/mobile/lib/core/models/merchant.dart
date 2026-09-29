/// Row returned by `get_merchant_rates()`.
class Merchant {
  const Merchant({
    required this.id,
    required this.name,
    required this.badgeLetter,
    required this.domains,
    required this.maxUserRateBps,
    required this.datafeedEnabled,
    required this.extensionEnabled,
  });

  final String id;
  final String name;
  final String badgeLetter;
  final List<String> domains;
  final int maxUserRateBps;
  final bool datafeedEnabled;
  final bool extensionEnabled;

  factory Merchant.fromJson(Map<String, dynamic> j) => Merchant(
        id: j['merchant_id'] as String,
        name: j['name'] as String,
        badgeLetter: (j['badge_letter'] as String?) ?? (j['name'] as String).substring(0, 1),
        domains: [for (final d in (j['domains'] as List? ?? const [])) '$d'],
        maxUserRateBps: (j['max_user_rate_bps'] as num?)?.toInt() ?? 0,
        datafeedEnabled: j['datafeed_enabled'] as bool? ?? false,
        extensionEnabled: j['extension_enabled'] as bool? ?? false,
      );
}
