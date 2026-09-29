import 'package:supabase_flutter/supabase_flutter.dart';

class PricePoint {
  const PricePoint(this.day, this.minPriceVnd);
  final DateTime day;
  final int minPriceVnd;

  factory PricePoint.fromJson(Map<String, dynamic> j) =>
      PricePoint(DateTime.parse(j['day'] as String), (j['min_price_vnd'] as num).toInt());
}

/// Range chips: days -> label.
const priceRanges = {30: '30 ngày', 90: '90 ngày', 180: '6 tháng', 365: '1 năm'};

/// Weekly buckets (min price per 7 days from the first point) for long ranges; keeps the chart readable.
List<PricePoint> downsampleWeekly(List<PricePoint> pts) {
  if (pts.isEmpty) return pts;
  final start = pts.first.day;
  final buckets = <int, PricePoint>{};
  for (final p in pts) {
    final k = p.day.difference(start).inDays ~/ 7;
    final cur = buckets[k];
    if (cur == null) {
      buckets[k] = p;
    } else if (p.minPriceVnd < cur.minPriceVnd) {
      buckets[k] = PricePoint(cur.day, p.minPriceVnd);
    }
  }
  return [for (final k in buckets.keys.toList()..sort()) buckets[k]!];
}

/// Points shown for [days]: weekly for 6 months and above.
List<PricePoint> chartPoints(List<PricePoint> pts, int days) => days >= 180 ? downsampleWeekly(pts) : pts;

class PriceStats {
  const PriceStats({required this.min, required this.max, required this.avg});
  final int min;
  final int max;
  final int avg;

  static PriceStats? of(List<PricePoint> pts) {
    if (pts.isEmpty) return null;
    var lo = pts.first.minPriceVnd, hi = lo, sum = 0;
    for (final p in pts) {
      if (p.minPriceVnd < lo) lo = p.minPriceVnd;
      if (p.minPriceVnd > hi) hi = p.minPriceVnd;
      sum += p.minPriceVnd;
    }
    return PriceStats(min: lo, max: hi, avg: (sum / pts.length).round());
  }
}

/// "Giá đang thấp hơn 6% so với trung bình 90 ngày"; null when there is nothing to compare.
String? priceInsight(int current, PriceStats? stats, int days) {
  if (stats == null || stats.avg <= 0) return null;
  final pct = ((stats.avg - current) / stats.avg * 100).round();
  if (pct == 0) return 'Giá đang ngang mức trung bình $days ngày';
  return 'Giá đang ${pct > 0 ? 'thấp' : 'cao'} hơn ${pct.abs()}% so với trung bình $days ngày';
}

/// Suggested alert target: 5% under the current price, rounded down to 1.000đ (never below 1.000đ).
int suggestedTarget(int currentVnd) {
  final t = (currentVnd * 95 ~/ 100) ~/ 1000 * 1000;
  return t < 1000 ? 1000 : t;
}

/// Cheapest offer of a product group (name/image for headers, price as the "current" fallback).
class GroupInfo {
  const GroupInfo({required this.groupId, required this.name, required this.priceVnd, required this.merchantId, this.imageUrl});
  final int groupId;
  final String name;
  final String? imageUrl;
  final int priceVnd;
  final String merchantId;
}

/// Reduces offer rows to the cheapest per group.
Map<int, GroupInfo> cheapestPerGroup(Iterable<Map<String, dynamic>> rows) {
  final out = <int, GroupInfo>{};
  for (final r in rows) {
    final g = (r['product_group_id'] as num?)?.toInt();
    final price = (r['price'] as num?)?.toInt();
    if (g == null || price == null) continue;
    final cur = out[g];
    if (cur == null || price < cur.priceVnd) {
      out[g] = GroupInfo(
        groupId: g,
        name: r['name'] as String,
        imageUrl: r['image_url'] as String?,
        priceVnd: price,
        merchantId: r['merchant_id'] as String,
      );
    }
  }
  return out;
}

class PriceHistoryRepository {
  PriceHistoryRepository(this._db);
  final SupabaseClient _db;

  Future<List<PricePoint>> history(int groupId, int days) async {
    final rows = await _db.rpc('get_price_history', params: {'p_group_id': groupId, 'p_days': days}) as List;
    return [for (final r in rows) PricePoint.fromJson(r as Map<String, dynamic>)];
  }

  Future<Map<int, GroupInfo>> groupInfos(Iterable<int> groupIds) async {
    final ids = groupIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await _db
        .from('offers')
        .select('product_group_id,name,image_url,price,merchant_id')
        .inFilter('product_group_id', ids)
        .not('price', 'is', null);
    return cheapestPerGroup(rows);
  }
}
