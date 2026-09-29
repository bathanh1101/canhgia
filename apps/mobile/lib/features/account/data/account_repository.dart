import 'package:supabase_flutter/supabase_flutter.dart';

class AccountStats {
  const AccountStats({
    this.orders = 0,
    this.referrals = 0,
    this.bankAccounts = 0,
    this.devices = 0,
    this.kycStatus,
    this.tierName,
  });

  final int orders;
  final int referrals;
  final int bankAccounts;
  final int devices;

  /// `pending | verified | rejected`, null = never submitted.
  final String? kycStatus;
  final String? tierName;
}

class UserDevice {
  const UserDevice({required this.platform, required this.lastSeenAt, this.model});
  final String platform;
  final String? model;
  final DateTime lastSeenAt;
}

class ExtensionLoginRequest {
  const ExtensionLoginRequest({required this.userAgent, required this.ipMasked, required this.expiresAt});
  final String? userAgent;
  final String ipMasked;
  final DateTime expiresAt;
}

/// Supabase access for the account area (all RLS-scoped to the caller).
class AccountRepository {
  AccountRepository(this._db);
  final SupabaseClient _db;

  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static const _qrPrefix = 'canhgia-ext:';

  /// Extension QR payload `canhgia-ext:<uuid>` -> uuid, or null if it is anything else.
  static String? parseExtensionQr(String? raw) {
    if (raw == null || !raw.startsWith(_qrPrefix)) return null;
    final code = raw.substring(_qrPrefix.length).trim();
    return _uuid.hasMatch(code) ? code.toLowerCase() : null;
  }

  static bool isValidCode(String? code) => code != null && _uuid.hasMatch(code);

  Future<AccountStats> stats(String uid, {String? tierCode}) async {
    final r = await Future.wait<Object?>([
      // orders has column-level grants: `count()` alone sends select=* and gets 42501.
      _db.from('orders').select('id').eq('user_id', uid).count(CountOption.exact).then((r) => r.count),
      _db.from('referrals').count().eq('referrer_id', uid),
      _db.from('bank_accounts').count().eq('user_id', uid),
      _db.from('user_devices').count().eq('user_id', uid),
      _db.from('kyc_profiles').select('status').eq('user_id', uid).maybeSingle(),
      tierCode == null
          ? Future<Object?>.value(null)
          : _db.from('vip_tiers').select('name').eq('code', tierCode).maybeSingle(),
    ]);
    return AccountStats(
      orders: r[0]! as int,
      referrals: r[1]! as int,
      bankAccounts: r[2]! as int,
      devices: r[3]! as int,
      kycStatus: (r[4] as Map<String, dynamic>?)?['status'] as String?,
      tierName: (r[5] as Map<String, dynamic>?)?['name'] as String?,
    );
  }

  Future<List<UserDevice>> devices(String uid) async {
    final rows = await _db.from('user_devices').select().eq('user_id', uid).order('last_seen_at', ascending: false);
    return [
      for (final r in rows)
        UserDevice(
          platform: r['platform'] as String,
          model: r['model'] as String?,
          lastSeenAt: DateTime.parse(r['last_seen_at'] as String),
        ),
    ];
  }

  Future<void> updateProfile({String? displayName, Map<String, bool>? notificationPrefs}) =>
      _db.rpc('update_profile', params: {'p_display_name': displayName, 'p_notification_prefs': notificationPrefs});

  Future<ExtensionLoginRequest> getExtensionLoginRequest(String code) async {
    final rows = await _db.rpc('get_extension_login_request', params: {'p_code': code}) as List;
    final r = rows.first as Map<String, dynamic>;
    return ExtensionLoginRequest(
      userAgent: r['user_agent'] as String?,
      ipMasked: r['ip_masked'] as String,
      expiresAt: DateTime.parse(r['expires_at'] as String),
    );
  }

  Future<void> approveExtensionLogin(String code) => _db.rpc('approve_extension_login', params: {'p_code': code});
}
