enum PinMode {
  verify,
  create,
  change,
  reset;

  static PinMode parse(String? v) => PinMode.values.where((m) => m.name == v).firstOrNull ?? PinMode.verify;
}

enum PinPhase { old, enter, confirm }

/// [returnPin]: `/pin?mode=verify&return=pin` pops the typed PIN instead of a pin_token.
typedef PinArgs = ({PinMode mode, bool returnPin});

class PinState {
  const PinState({
    required this.phase,
    this.digits = '',
    this.busy = false,
    this.message,
    this.lockedUntil,
    this.needsOtp = false,
    this.result,
  });

  final PinPhase phase;
  final String digits;
  final bool busy;
  final String? message;
  final DateTime? lockedUntil;

  /// Creating the first PIN requires a fresh email-OTP session (backend rule).
  final bool needsOtp;

  /// Set once the flow succeeded; the screen pops it (pin_token / PIN / 'ok').
  final String? result;

  PinState copyWith({
    PinPhase? phase,
    String? digits,
    bool? busy,
    Object? message = _keep,
    Object? lockedUntil = _keep,
    bool? needsOtp,
    String? result,
  }) =>
      PinState(
        phase: phase ?? this.phase,
        digits: digits ?? this.digits,
        busy: busy ?? this.busy,
        message: identical(message, _keep) ? this.message : message as String?,
        lockedUntil: identical(lockedUntil, _keep) ? this.lockedUntil : lockedUntil as DateTime?,
        needsOtp: needsOtp ?? this.needsOtp,
        result: result ?? this.result,
      );
}

const _keep = Object();

Duration lockRemaining(DateTime? until, DateTime now) {
  if (until == null) return Duration.zero;
  final d = until.difference(now);
  return d.isNegative ? Duration.zero : d;
}

/// 14:59 (rounded up so the display never shows 00:00 while still locked).
String formatCountdown(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

(String title, String subtitle) pinHeading(PinMode mode, PinPhase phase, {String? verifyHint}) => switch ((mode, phase)) {
      (PinMode.verify, _) => ('Nhập mã PIN', verifyHint ?? 'Nhập mã PIN 6 số để xác nhận.'),
      (PinMode.change, PinPhase.old) => ('Nhập PIN hiện tại', 'Xác nhận mã PIN đang dùng trước khi đổi.'),
      (_, PinPhase.confirm) => ('Nhập lại mã PIN', 'Nhập lại mã PIN vừa tạo để xác nhận.'),
      (PinMode.change, _) => ('Tạo PIN mới', 'Mã PIN mới gồm 6 chữ số.'),
      _ => ('Tạo mã PIN', 'Mã PIN gồm 6 chữ số dùng để xác nhận khi rút tiền.'),
    };
