import 'package:supabase_flutter/supabase_flutter.dart';

import 'order.dart';

/// Reads the caller's own `orders` (RLS) with the explicit granted columns.
class OrdersRepository {
  OrdersRepository(this._db);
  final SupabaseClient _db;

  Future<List<Order>> list(String uid, {required DateTime month, required OrderTab tab, required int limit}) async {
    final b = monthBounds(month);
    var q = _db.from('orders').select(Order.columns).eq('user_id', uid).gte('order_time', b.from).lt('order_time', b.to);
    final states = tab.creditStates;
    if (states != null) q = q.inFilter('credit_state', states);
    final rows = await q.order('order_time', ascending: false).limit(limit);
    return [for (final r in rows) Order.fromJson(r)];
  }

  Future<Order?> get(String id) async {
    final row = await _db.from('orders').select(Order.columns).eq('id', id).maybeSingle();
    return row == null ? null : Order.fromJson(row);
  }

  Future<int> creditedCount(String uid) => _db.from('orders').count().eq('user_id', uid).eq('credit_state', 'credited');
}
