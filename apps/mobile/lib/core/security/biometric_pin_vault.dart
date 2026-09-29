import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/auth_session_provider.dart';

/// Keeps the withdrawal PIN in the platform keystore behind a biometric prompt.
/// Convenience only: the server still verifies the PIN (`verify_pin`) every time.
/// Only an app-level gate (Keystore-wrapped, not bound to biometric enrolment);
/// the server-side `verify_pin`, 24h hold and pin_locked are the real controls.
/// Any PIN change/reset flow MUST call [disable] (the stored PIN goes stale).
/// Entries are per user id so an account switch never exposes another user's PIN.
class BiometricPinVault {
  BiometricPinVault(this._uid, {LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked_this_device),
            );

  final String? _uid;
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static final _pinShape = RegExp(r'^\d{6}$');
  String get _key => 'pin_vault_v1:$_uid';

  /// Device has enrolled biometrics (toggle is disabled otherwise).
  Future<bool> isSupported() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> isEnabled() async => _uid != null && await _storage.containsKey(key: _key);

  /// Stores an already server-verified [pin]. Returns false when the user
  /// cancels/fails the biometric prompt (nothing is stored).
  Future<bool> enable(String pin) async {
    if (_uid == null || !_pinShape.hasMatch(pin)) throw ArgumentError('pin must be 6 digits');
    if (!await _prompt('Xác nhận để bật mở khóa bằng sinh trắc học')) return false;
    await _storage.write(key: _key, value: pin);
    return true;
  }

  Future<void> disable() async {
    if (_uid != null) await _storage.delete(key: _key);
  }

  /// Returns the stored PIN after a successful biometric check, else null.
  Future<String?> readPinWithBiometric() async {
    if (!await isEnabled()) return null;
    if (!await _prompt('Xác thực để dùng mã PIN đã lưu')) return null;
    return _storage.read(key: _key);
  }

  Future<bool> _prompt(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true);
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}

/// For the PIN screen (06) and the account toggle (04).
final biometricPinVaultProvider =
    Provider<BiometricPinVault>((ref) => BiometricPinVault(ref.watch(currentUserIdProvider)));
