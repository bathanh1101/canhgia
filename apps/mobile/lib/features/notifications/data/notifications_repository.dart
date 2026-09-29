import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_notification.dart';

class NotificationsRepository {
  NotificationsRepository(this._db);
  final SupabaseClient _db;

  Future<List<AppNotification>> list(String uid, {String? type, int limit = 100}) async {
    var q = _db.from('notifications').select(AppNotification.columns).eq('user_id', uid);
    if (type != null) q = q.eq('type', type);
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return [for (final r in rows) AppNotification.fromJson(r)];
  }

  /// [ids] null marks everything read. Returns the number of rows updated.
  Future<int> markRead([List<int>? ids]) async {
    final n = await _db.rpc('mark_notifications_read', params: ids == null ? null : {'p_ids': ids});
    return (n as num?)?.toInt() ?? 0;
  }
}
