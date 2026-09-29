import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../device/device_identity_service.dart';
import '../supabase/postgrest_error_mapper.dart';

/// Referral code from a `<APP_BASE_URL>/r/<code>` deep link, kept until login
/// (then sent to `bind_referral`, which is the real validator).
class ReferralStore {
  ReferralStore(this._prefs);

  static const _key = 'pending_referral_code';
  static final _valid = RegExp(r'^[A-Za-z0-9]{4,16}$');
  final SharedPreferences _prefs;

  /// Returns false (and stores nothing) when [code] is not shaped like a referral code.
  Future<bool> save(String code) async {
    if (!_valid.hasMatch(code)) return false;
    return _prefs.setString(_key, code.toUpperCase());
  }

  String? get pending => _prefs.getString(_key);

  Future<void> clear() => _prefs.remove(_key);
}

final referralStoreProvider = Provider<ReferralStore>((ref) => ReferralStore(ref.watch(sharedPreferencesProvider)));

/// Sends the pending code to `bind_referral` (the real validator). Server
/// rejection drops it; a transient failure (network/unknown) keeps it and rethrows.
Future<void> bindPendingReferral(SupabaseClient client, ReferralStore store) async {
  final code = store.pending;
  if (code == null) return;
  try {
    await client.rpc('bind_referral', params: {'p_code': code});
    await store.clear();
  } on Object catch (e) {
    final c = errorCodeOf(e);
    if (c != 'network' && c != 'unknown') await store.clear();
    rethrow;
  }
}
