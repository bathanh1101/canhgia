import 'package:supabase_flutter/supabase_flutter.dart';

class WatchItem {
  const WatchItem({required this.id, required this.groupId, required this.targetPriceVnd});
  final int id;
  final int groupId;
  final int targetPriceVnd;

  factory WatchItem.fromJson(Map<String, dynamic> j) => WatchItem(
        id: (j['id'] as num).toInt(),
        groupId: (j['product_group_id'] as num).toInt(),
        targetPriceVnd: (j['target_price_vnd'] as num).toInt(),
      );
}

const _cols = 'id,product_group_id,target_price_vnd';

/// watchlist_items CRUD (RLS: own rows). Target must be a positive VND integer.
class WatchlistRepository {
  WatchlistRepository(this._db);
  final SupabaseClient _db;

  Future<List<WatchItem>> list(String uid) async {
    final rows = await _db.from('watchlist_items').select(_cols).eq('user_id', uid).order('created_at', ascending: false);
    return [for (final r in rows) WatchItem.fromJson(r)];
  }

  Future<WatchItem?> find(String uid, int groupId) async {
    final row = await _db.from('watchlist_items').select(_cols).eq('user_id', uid).eq('product_group_id', groupId).maybeSingle();
    return row == null ? null : WatchItem.fromJson(row);
  }

  /// Insert or update the target for (user, group).
  Future<WatchItem> setTarget(String uid, int groupId, int targetVnd) async {
    if (targetVnd <= 0) throw ArgumentError.value(targetVnd, 'targetVnd', 'must be positive');
    final existing = await find(uid, groupId);
    final row = existing == null
        ? await _db.from('watchlist_items').insert({'user_id': uid, 'product_group_id': groupId, 'target_price_vnd': targetVnd}).select(_cols).single()
        : await _db.from('watchlist_items').update({'target_price_vnd': targetVnd}).eq('id', existing.id).select(_cols).single();
    return WatchItem.fromJson(row);
  }

  Future<void> remove(int id) => _db.from('watchlist_items').delete().eq('id', id);
}
