import 'package:supabase_flutter/supabase_flutter.dart';

/// One row of `get_compare` (offers of one product group; effective = price - est. cashback).
class CompareOffer {
  const CompareOffer({
    required this.offerId,
    required this.merchantId,
    required this.name,
    required this.priceVnd,
    required this.estCashbackVnd,
    required this.effectivePriceVnd,
    required this.isMall,
    required this.cashbackEligible,
    this.shopName,
    this.url,
    this.imageUrl,
    this.listPriceVnd,
  });

  final int offerId;
  final String merchantId;
  final String? shopName;
  final String name;
  final String? url;
  final String? imageUrl;
  final int priceVnd;
  final int? listPriceVnd;
  final int estCashbackVnd;
  final int effectivePriceVnd;
  final bool isMall;
  final bool cashbackEligible;

  factory CompareOffer.fromJson(Map<String, dynamic> j) {
    final price = (j['price_vnd'] as num).toInt();
    final cb = (j['est_cashback_vnd'] as num?)?.toInt() ?? 0;
    return CompareOffer(
      offerId: (j['offer_id'] as num).toInt(),
      merchantId: j['merchant_id'] as String,
      shopName: j['shop_name'] as String?,
      name: j['name'] as String,
      url: j['url'] as String?,
      imageUrl: j['image_url'] as String?,
      priceVnd: price,
      listPriceVnd: (j['list_price_vnd'] as num?)?.toInt(),
      estCashbackVnd: cb,
      effectivePriceVnd: (j['effective_price_vnd'] as num?)?.toInt() ?? price - cb,
      isMall: j['is_mall'] as bool? ?? false,
      cashbackEligible: j['cashback_eligible'] as bool? ?? true,
    );
  }
}

/// Sort chips: effective price (default), list price, highest cashback.
const compareSorts = {'effective': 'Giá thực trả', 'list': 'Giá niêm yết', 'cashback': 'Hoàn tiền cao'};

/// Client-side sort/filter of the fetched offers (ties keep server order: effective price, id).
List<CompareOffer> sortCompare(List<CompareOffer> offers, String sort, {bool mallOnly = false}) {
  final list = [for (final o in offers) if (!mallOnly || o.isMall) o];
  int by(CompareOffer a, CompareOffer b) => switch (sort) {
        'list' => a.priceVnd.compareTo(b.priceVnd),
        'cashback' => b.estCashbackVnd.compareTo(a.estCashbackVnd),
        _ => a.effectivePriceVnd.compareTo(b.effectivePriceVnd),
      };
  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])]
    ..sort((a, b) => by(a.$2, b.$2) != 0 ? by(a.$2, b.$2) : a.$1.compareTo(b.$1));
  return [for (final e in indexed) e.$2];
}

/// Offer with the lowest effective price (null when empty).
CompareOffer? cheapestOffer(List<CompareOffer> offers) {
  CompareOffer? best;
  for (final o in offers) {
    if (best == null || o.effectivePriceVnd < best.effectivePriceVnd) best = o;
  }
  return best;
}

class CompareRepository {
  CompareRepository(this._db);
  final SupabaseClient _db;

  /// Empty when the group has fewer than 2 priced offers (server rule).
  Future<List<CompareOffer>> compare(int groupId) async {
    final rows = await _db.rpc('get_compare', params: {'p_group_id': groupId}) as List;
    return [for (final r in rows) CompareOffer.fromJson(r as Map<String, dynamic>)];
  }
}
