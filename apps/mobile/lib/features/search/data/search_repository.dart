import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/route_paths.dart';

/// One row of `search_offers` (offers grouped by product_group_id on the server).
class OfferHit {
  const OfferHit({
    required this.offerId,
    required this.merchantId,
    required this.name,
    required this.priceVnd,
    required this.rateBps,
    required this.estCashbackVnd,
    required this.offersInGroup,
    this.groupId,
    this.imageUrl,
  });

  final int offerId;
  final int? groupId;
  final String merchantId;
  final String name;
  final String? imageUrl;
  final int priceVnd;
  final int rateBps;
  final int estCashbackVnd;
  final int offersInGroup;

  /// Price after estimated cashback ("giá thực trả").
  int get effectivePriceVnd => priceVnd - estCashbackVnd;

  /// Compare needs >= 2 offers of one product group.
  bool get canCompare => groupId != null && offersInGroup >= 2;

  factory OfferHit.fromJson(Map<String, dynamic> j) => OfferHit(
        offerId: (j['offer_id'] as num).toInt(),
        groupId: (j['product_group_id'] as num?)?.toInt(),
        merchantId: j['merchant_id'] as String,
        name: j['name'] as String,
        imageUrl: j['image_url'] as String?,
        priceVnd: (j['price_vnd'] as num?)?.toInt() ?? 0,
        rateBps: (j['rate_bps'] as num?)?.toInt() ?? 0,
        estCashbackVnd: (j['est_cashback_vnd'] as num?)?.toInt() ?? 0,
        offersInGroup: (j['offers_in_group'] as num?)?.toInt() ?? 1,
      );
}

/// `p_sort` values accepted by search_offers, with chip labels.
const searchSorts = {
  'relevance': 'Liên quan',
  'price_asc': 'Giá thấp',
  'price_desc': 'Giá cao',
  'cashback_desc': 'Hoàn tiền cao',
};

/// Query, optional merchant id filter ('' = all), sort key. Records compare by value (provider family key).
typedef SearchArgs = ({String q, String merchant, String sort});

String searchResultsLocation(String q, {String merchant = '', String sort = 'relevance'}) => Uri(
      path: RoutePaths.searchResults,
      queryParameters: {'q': q, if (merchant.isNotEmpty) 'm': merchant, if (sort != 'relevance') 'sort': sort},
    ).toString();

class SearchRepository {
  SearchRepository(this._db);
  final SupabaseClient _db;

  Future<List<OfferHit>> search(SearchArgs a, {int limit = 20, int offset = 0}) async {
    final rows = await _db.rpc('search_offers', params: {
      'p_q': a.q,
      'p_merchants': a.merchant.isEmpty ? null : [a.merchant],
      'p_sort': searchSorts.containsKey(a.sort) ? a.sort : 'relevance',
      'p_limit': limit,
      'p_offset': offset,
    }) as List;
    return [for (final r in rows) OfferHit.fromJson(r as Map<String, dynamic>)];
  }
}

/// Recent queries in SharedPreferences: newest first, case-insensitive dedupe, max 10.
class RecentSearchStore {
  RecentSearchStore(this._prefs);
  final SharedPreferences _prefs;

  static const _key = 'recent_searches_v1';
  static const max = 10;

  List<String> read() => _prefs.getStringList(_key) ?? const [];

  Future<List<String>> add(String q) async {
    final t = q.trim();
    if (t.isEmpty) return read();
    final next = [t, ...read().where((e) => e.toLowerCase() != t.toLowerCase())].take(max).toList();
    await _prefs.setStringList(_key, next);
    return next;
  }

  Future<List<String>> remove(String q) async {
    final next = read().where((e) => e != q).toList();
    await _prefs.setStringList(_key, next);
    return next;
  }

  Future<void> clear() => _prefs.remove(_key);
}
