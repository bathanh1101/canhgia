import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_pin_vault.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/pin_repository.dart';
import 'pin_state.dart';

final pinRepositoryProvider = Provider<PinRepository>((ref) => PinRepository(ref.watch(supabaseProvider)));

/// Convenience-unlock is offered on verify screens that issue a pin_token only.
final pinBiometricAvailableProvider =
    FutureProvider.autoDispose<bool>((ref) => ref.watch(biometricPinVaultProvider).isEnabled());

/// State machine for verify / create / change. The server owns the lockout
/// (5 wrong -> 15 min); this only mirrors it in the UI.
class PinController extends Notifier<PinState> {
  PinController(this.args);
  final PinArgs args;

  PinRepository get _repo => ref.read(pinRepositoryProvider);

  String? _firstEntry;
  String? _oldToken;

  @override
  PinState build() => PinState(phase: args.mode == PinMode.change ? PinPhase.old : PinPhase.enter);

  bool get _locked => state.lockedUntil != null && state.lockedUntil!.isAfter(DateTime.now());

  void press(String digit) {
    if (state.busy || _locked || state.digits.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) return;
    final digits = state.digits + digit;
    state = state.copyWith(digits: digits, message: null);
    if (digits.length == 6) _complete(digits);
  }

  void backspace() {
    if (state.busy || state.digits.isEmpty) return;
    state = state.copyWith(digits: state.digits.substring(0, state.digits.length - 1));
  }

  /// The lock window elapsed: allow typing again.
  void unlock() => state = state.copyWith(lockedUntil: null, message: null);

  Future<void> useBiometric() async {
    if (state.busy || _locked || args.mode != PinMode.verify || args.returnPin) return;
    final vault = ref.read(biometricPinVaultProvider);
    final pin = await vault.readPinWithBiometric();
    if (pin == null || !ref.mounted) return;
    await _verify(pin, fromBiometric: true);
  }

  /// After a fresh email-OTP session: retry storing the PIN typed earlier.
  Future<void> retryCreate() {
    final pin = _firstEntry;
    return pin == null ? Future.value() : _store(pin);
  }

  Future<void> _complete(String pin) async {
    switch (state.phase) {
      case PinPhase.old:
        await _verify(pin);
      case PinPhase.enter when args.mode == PinMode.verify:
        await _verify(pin);
      case PinPhase.enter:
        _firstEntry = pin;
        state = state.copyWith(phase: PinPhase.confirm, digits: '');
      case PinPhase.confirm:
        if (pin != _firstEntry) {
          _firstEntry = null;
          state = state.copyWith(phase: PinPhase.enter, digits: '', message: 'Mã PIN nhập lại không khớp. Vui lòng tạo lại.');
          return;
        }
        await _store(pin);
    }
  }

  Future<void> _verify(String pin, {bool fromBiometric = false}) async {
    state = state.copyWith(busy: true, digits: pin, message: null);
    try {
      final r = await _repo.verify(pin);
      if (!ref.mounted) return;
      if (r.ok) {
        if (args.mode == PinMode.change) {
          _oldToken = r.pinToken;
          state = state.copyWith(busy: false, phase: PinPhase.enter, digits: '');
        } else {
          state = state.copyWith(busy: false, result: args.returnPin ? pin : r.pinToken);
        }
        return;
      }
      if (fromBiometric) await _dropVault();
      if (!ref.mounted) return;
      final locked = r.lockedUntil;
      state = state.copyWith(
        busy: false,
        digits: '',
        lockedUntil: locked,
        message: locked != null
            ? 'Sai PIN quá nhiều lần. Tạm khóa xác thực PIN.'
            : 'Sai PIN, còn ${r.attemptsLeft} lần thử.',
      );
    } on Object catch (e) {
      if (fromBiometric && errorCodeOf(e) == 'pin_invalid') await _dropVault();
      _fail(e);
    }
  }

  /// A stored PIN that no longer matches would fail on every biometric unlock and burn attempts.
  Future<void> _dropVault() async {
    try {
      await ref.read(biometricPinVaultProvider).disable();
    } on Object {
      // Best effort: the server lockout still protects the account.
    }
  }

  Future<void> _store(String pin) async {
    state = state.copyWith(busy: true, message: null);
    try {
      await _repo.setPin(pin, pinToken: _oldToken);
      await _dropVault(); // PIN changed: any vaulted copy is stale
      if (!ref.mounted) return;
      state = state.copyWith(busy: false, result: 'ok');
    } on Object catch (e) {
      if (!ref.mounted) return;
      final f = AppFailure.from(e);
      if (f.code == 'pin_invalid' && f.detail['reason'] == 'otp_required') {
        state = state.copyWith(busy: false, needsOtp: true);
        return;
      }
      if (f.code == 'pin_invalid' && _oldToken != null) {
        // The 60 s single-use token from the current-PIN step expired/was consumed: verify again.
        _oldToken = null;
        _firstEntry = null;
        state = state.copyWith(
            busy: false, phase: PinPhase.old, digits: '', message: 'Phiên xác thực đã hết hạn, nhập lại PIN hiện tại.');
        return;
      }
      _fail(e);
    }
  }

  void _fail(Object e) {
    if (!ref.mounted) return;
    final f = AppFailure.from(e);
    final until = DateTime.tryParse('${f.detail['locked_until'] ?? ''}');
    final notSet = f.code == 'pin_invalid' && f.detail['reason'] == 'not_set';
    state = state.copyWith(
      busy: false,
      digits: '',
      lockedUntil: f.code == 'pin_locked' ? until : null,
      message: notSet ? 'Bạn chưa tạo mã PIN rút tiền.' : (f.code == 'pin_locked' ? 'Sai PIN quá nhiều lần. Tạm khóa xác thực PIN.' : f.message),
    );
  }
}

final pinControllerProvider =
    NotifierProvider.autoDispose.family<PinController, PinState, PinArgs>(PinController.new);
