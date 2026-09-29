import 'package:supabase_flutter/supabase_flutter.dart';

import 'ledger_entry.dart';

class LedgerRepository {
  LedgerRepository(this._db);
  final SupabaseClient _db;

  Future<List<LedgerEntry>> list(String uid, {int limit = 50}) async {
    final rows = await _db
        .from('wallet_ledger')
        .select(LedgerEntry.columns)
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) LedgerEntry.fromJson(r)];
  }
}
