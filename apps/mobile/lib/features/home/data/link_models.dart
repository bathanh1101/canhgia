import '../../../core/supabase/postgrest_error_mapper.dart';

/// 650 -> "6,5%", 600 -> "6%".
String formatBps(int bps) {
  if (bps % 100 == 0) return '${bps ~/ 100}%';
  return '${(bps / 100).toStringAsFixed(1).replaceAll('.', ',')}%';
}

Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;
int? _int(Object? v) => v is num ? v.toInt() : null;

/// `estimate` of resolve-url / create-link; the whole object may be null (no rate known).
class CashbackEstimate {
  const CashbackEstimate({required this.baseRateBps, required this.vipRateBps, this.cashbackVnd});

  final int baseRateBps;
  final int vipRateBps;
  final int? cashbackVnd;

  int get totalRateBps => baseRateBps + vipRateBps;

  /// "6% + 1% hạng Vàng" (tier label only when a VIP share exists); "ước tính" is added by the UI.
  String label([String? tierLabel]) => vipRateBps > 0
      ? '${formatBps(baseRateBps)} + ${formatBps(vipRateBps)}${tierLabel == null ? '' : ' hạng $tierLabel'}'
      : formatBps(baseRateBps);

  static CashbackEstimate? fromJson(Object? raw) {
    final j = _map(raw);
    if (j == null) return null;
    return CashbackEstimate(
      baseRateBps: _int(j['base_rate_bps']) ?? 0,
      vipRateBps: _int(j['vip_rate_bps']) ?? 0,
      cashbackVnd: _int(j['cashback_vnd']),
    );
  }
}

class ResolvedOffer {
  const ResolvedOffer({
    required this.name,
    required this.priceVnd,
    this.imageUrl,
    this.productGroupId,
    this.cashbackEligible = true,
  });

  final String name;
  final int priceVnd;
  final String? imageUrl;
  final int? productGroupId;
  final bool cashbackEligible;

  static ResolvedOffer? fromJson(Object? raw) {
    final j = _map(raw);
    if (j == null || j['name'] is! String) return null;
    return ResolvedOffer(
      name: j['name'] as String,
      priceVnd: _int(j['price_vnd']) ?? 0,
      imageUrl: j['image'] as String?,
      productGroupId: _int(j['product_group_id']),
      cashbackEligible: j['cashback_eligible'] as bool? ?? true,
    );
  }
}

/// Response of the `resolve-url` Edge function.
class ResolvedUrl {
  const ResolvedUrl({
    required this.merchantId,
    required this.resolvedUrl,
    required this.datafeedEnabled,
    this.offer,
    this.estimate,
  });

  final String merchantId;
  final String resolvedUrl;
  final bool datafeedEnabled;
  final ResolvedOffer? offer;
  final CashbackEstimate? estimate;

  /// Degrade spec: compare/history only for datafeed merchants with a grouped offer.
  bool get canCompare => datafeedEnabled && offer?.productGroupId != null;

  factory ResolvedUrl.fromJson(Object? raw) {
    final j = _map(raw);
    final id = j?['merchant_id'];
    if (j == null || id is! String) throw const AppFailure('unknown');
    return ResolvedUrl(
      merchantId: id,
      resolvedUrl: (j['resolved_url'] as String?) ?? '',
      datafeedEnabled: j['datafeed_enabled'] as bool? ?? false,
      offer: ResolvedOffer.fromJson(j['offer']),
      estimate: CashbackEstimate.fromJson(j['estimate']),
    );
  }
}

/// Response of `create-link` plus the product context we already know client-side.
class CreatedLink {
  const CreatedLink({
    required this.clickId,
    required this.affLink,
    required this.merchantId,
    required this.activationHours,
    required this.createdAt,
    this.shortLink,
    this.estimate,
    this.productName,
    this.productPriceVnd,
    this.imageUrl,
  });

  final String clickId;
  final String affLink;
  final String? shortLink;
  final String merchantId;
  final int activationHours;
  final DateTime createdAt;
  final CashbackEstimate? estimate;
  final String? productName;
  final int? productPriceVnd;
  final String? imageUrl;

  /// Link to copy/share: short link when the backend gave one.
  String get shareUrl => shortLink ?? affLink;

  Duration get activationWindow => Duration(hours: activationHours);

  CreatedLink withProduct({String? name, int? priceVnd, String? image}) => CreatedLink(
        clickId: clickId,
        affLink: affLink,
        shortLink: shortLink,
        merchantId: merchantId,
        activationHours: activationHours,
        createdAt: createdAt,
        estimate: estimate,
        productName: name ?? productName,
        productPriceVnd: priceVnd ?? productPriceVnd,
        imageUrl: image ?? imageUrl,
      );

  factory CreatedLink.fromJson(Object? raw, {DateTime? now}) {
    final j = _map(raw);
    final click = j?['click_id'];
    final aff = j?['aff_link'];
    if (j == null || click == null || aff is! String || aff.isEmpty) throw const AppFailure('unknown');
    return CreatedLink(
      clickId: '$click',
      affLink: aff,
      shortLink: j['short_link'] as String?,
      merchantId: (j['merchant_id'] as String?) ?? '',
      activationHours: _int(j['activation_hours']) ?? 0,
      createdAt: now ?? DateTime.now(),
      estimate: CashbackEstimate.fromJson(j['estimate']),
    );
  }
}
