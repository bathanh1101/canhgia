import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../device/device_identity_service.dart';

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
