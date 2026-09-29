import 'package:supabase_flutter/supabase_flutter.dart';

/// `verify_pin` result. A wrong PIN is a normal return (counter committed server-side),
/// while an already locked account raises `pin_locked` (see AppFailure.detail).
class PinVerifyResult {
  const PinVerifyResult({required this.ok, required this.attemptsLeft, this.lockedUntil, this.pinToken});

  final bool ok;
  final int attemptsLeft;
  final DateTime? lockedUntil;

  /// 60 s single-use token accepted by `request_withdrawal` / `set_withdraw_pin`.
  final String? pinToken;

  factory PinVerifyResult.fromJson(Map<String, dynamic> j) => PinVerifyResult(
        ok: j['ok'] as bool? ?? false,
        attemptsLeft: (j['attempts_left'] as num?)?.toInt() ?? 0,
        lockedUntil: j['locked_until'] == null ? null : DateTime.parse(j['locked_until'] as String),
        pinToken: j['pin_token'] as String?,
      );
}

/// The PIN goes only to these two RPCs (TLS); it is never logged or stored here.
class PinRepository {
  PinRepository(this._db);
  final SupabaseClient _db;

  static final _shape = RegExp(r'^\d{6}$');

  Future<PinVerifyResult> verify(String pin) async {
    if (!_shape.hasMatch(pin)) throw ArgumentError('pin must be 6 digits');
    final rows = await _db.rpc('verify_pin', params: {'p_pin': pin}) as List;
    return PinVerifyResult.fromJson(rows.first as Map<String, dynamic>);
  }

  /// First PIN: no token (needs a fresh email-OTP session). Change: [pinToken] from [verify].
  Future<void> setPin(String pin, {String? pinToken}) async {
    if (!_shape.hasMatch(pin)) throw ArgumentError('pin must be 6 digits');
    await _db.rpc('set_withdraw_pin', params: {'p_new': pin, 'p_pin_token': pinToken});
  }
}
