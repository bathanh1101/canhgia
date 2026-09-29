import 'package:canhgia_mobile/core/security/biometric_pin_vault.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/pin/application/pin_controller.dart';
import 'package:canhgia_mobile/features/pin/application/pin_state.dart';
import 'package:canhgia_mobile/features/pin/data/pin_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PinRepository {}

class _MockVault extends Mock implements BiometricPinVault {}

void main() {
  late _MockRepo repo;
  late _MockVault vault;

  setUp(() {
    repo = _MockRepo();
    vault = _MockVault();
    when(() => vault.disable()).thenAnswer((_) async {});
  });

  ProviderContainer make(PinArgs args) {
    final c = ProviderContainer(overrides: [
      pinRepositoryProvider.overrideWithValue(repo),
      biometricPinVaultProvider.overrideWithValue(vault),
    ]);
    addTearDown(c.dispose);
    c.listen(pinControllerProvider(args), (_, _) {});
    return c;
  }

  Future<void> type(ProviderContainer c, PinArgs a, String pin) async {
    for (final d in pin.split('')) {
      c.read(pinControllerProvider(a).notifier).press(d);
    }
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  const vArgs = (mode: PinMode.verify, returnPin: false);
  const vPin = (mode: PinMode.verify, returnPin: true);
  const create = (mode: PinMode.create, returnPin: false);
  const change = (mode: PinMode.change, returnPin: false);

  PinVerifyResult ok([String token = 'tok']) => PinVerifyResult(ok: true, attemptsLeft: 5, pinToken: token);

  group('verify', () {
    test('correct PIN pops the pin_token', () async {
      when(() => repo.verify('123456')).thenAnswer((_) async => ok('tok-1'));
      final c = make(vArgs);
      await type(c, vArgs, '123456');
      expect(c.read(pinControllerProvider(vArgs)).result, 'tok-1');
    });

    test('return=pin pops the typed PIN instead of a token', () async {
      when(() => repo.verify('123456')).thenAnswer((_) async => ok());
      final c = make(vPin);
      await type(c, vPin, '123456');
      expect(c.read(pinControllerProvider(vPin)).result, '123456');
    });

    test('wrong PIN shows attempts left and clears the input', () async {
      when(() => repo.verify(any())).thenAnswer((_) async => const PinVerifyResult(ok: false, attemptsLeft: 3));
      final c = make(vArgs);
      await type(c, vArgs, '000000');
      final s = c.read(pinControllerProvider(vArgs));
      expect(s.message, 'Sai PIN, còn 3 lần thử.');
      expect(s.digits, isEmpty);
      expect(s.result, isNull);
      expect(s.lockedUntil, isNull);
    });

    test('5th wrong PIN returns locked_until: input is blocked', () async {
      final until = DateTime.now().add(const Duration(minutes: 15));
      when(() => repo.verify(any())).thenAnswer((_) async => PinVerifyResult(ok: false, attemptsLeft: 0, lockedUntil: until));
      final c = make(vArgs);
      await type(c, vArgs, '000000');
      expect(c.read(pinControllerProvider(vArgs)).lockedUntil, until);
      c.read(pinControllerProvider(vArgs).notifier).press('1');
      expect(c.read(pinControllerProvider(vArgs)).digits, isEmpty);
      verify(() => repo.verify(any())).called(1);
    });

    test('pin_locked raised by the server reads locked_until from detail', () async {
      final until = DateTime.now().add(const Duration(minutes: 9)).toUtc();
      when(() => repo.verify(any())).thenThrow(AppFailure('pin_locked', detail: {'locked_until': until.toIso8601String()}));
      final c = make(vArgs);
      await type(c, vArgs, '111111');
      final s = c.read(pinControllerProvider(vArgs));
      expect(s.lockedUntil!.difference(until).inSeconds.abs(), lessThan(1));
      expect(s.message, contains('Tạm khóa'));
    });

    test('unlock() re-enables typing after the window', () async {
      when(() => repo.verify(any())).thenAnswer((_) async => PinVerifyResult(ok: false, attemptsLeft: 0, lockedUntil: DateTime.now().subtract(const Duration(seconds: 1))));
      final c = make(vArgs);
      await type(c, vArgs, '000000');
      c.read(pinControllerProvider(vArgs).notifier)
        ..unlock()
        ..press('7');
      expect(c.read(pinControllerProvider(vArgs)).digits, '7');
    });

    test('PIN not set is explained', () async {
      when(() => repo.verify(any())).thenThrow(const AppFailure('pin_invalid', detail: {'reason': 'not_set'}));
      final c = make(vArgs);
      await type(c, vArgs, '123456');
      expect(c.read(pinControllerProvider(vArgs)).message, 'Bạn chưa tạo mã PIN rút tiền.');
    });

    test('backspace and digit cap', () async {
      final c = make(vArgs);
      final n = c.read(pinControllerProvider(vArgs).notifier)
        ..press('1')
        ..press('2')
        ..backspace()
        ..press('x');
      expect(c.read(pinControllerProvider(vArgs)).digits, '1');
      n.backspace();
      n.backspace();
      expect(c.read(pinControllerProvider(vArgs)).digits, isEmpty);
    });
  });

  group('biometric', () {
    test('vault PIN is verified server-side and yields a token', () async {
      when(() => vault.readPinWithBiometric()).thenAnswer((_) async => '123456');
      when(() => repo.verify('123456')).thenAnswer((_) async => ok('tok-b'));
      final c = make(vArgs);
      await c.read(pinControllerProvider(vArgs).notifier).useBiometric();
      expect(c.read(pinControllerProvider(vArgs)).result, 'tok-b');
      verifyNever(() => vault.disable());
    });

    test('stale vault PIN (server says wrong) disables the vault and falls back to manual entry', () async {
      when(() => vault.readPinWithBiometric()).thenAnswer((_) async => '123456');
      when(() => repo.verify(any())).thenAnswer((_) async => const PinVerifyResult(ok: false, attemptsLeft: 4));
      final c = make(vArgs);
      await c.read(pinControllerProvider(vArgs).notifier).useBiometric();
      verify(() => vault.disable()).called(1);
      final s = c.read(pinControllerProvider(vArgs));
      expect(s.result, isNull);
      expect(s.digits, isEmpty);
      expect(s.message, contains('còn 4 lần'));
    });

    test('pin_invalid raised for the vault PIN also disables the vault', () async {
      when(() => vault.readPinWithBiometric()).thenAnswer((_) async => '123456');
      when(() => repo.verify(any())).thenThrow(const AppFailure('pin_invalid'));
      final c = make(vArgs);
      await c.read(pinControllerProvider(vArgs).notifier).useBiometric();
      verify(() => vault.disable()).called(1);
    });

    test('cancelled biometric prompt does nothing; not offered for return=pin', () async {
      when(() => vault.readPinWithBiometric()).thenAnswer((_) async => null);
      final c = make(vArgs);
      await c.read(pinControllerProvider(vArgs).notifier).useBiometric();
      verifyNever(() => repo.verify(any()));
      clearInteractions(vault);
      final c2 = make(vPin);
      await c2.read(pinControllerProvider(vPin).notifier).useBiometric();
      verifyNever(() => vault.readPinWithBiometric());
    });
  });

  group('create', () {
    test('two matching entries store the PIN, then the stale vault entry is dropped', () async {
      when(() => repo.setPin('246810', pinToken: null)).thenAnswer((_) async {});
      final c = make(create);
      await type(c, create, '246810');
      expect(c.read(pinControllerProvider(create)).phase, PinPhase.confirm);
      await type(c, create, '246810');
      expect(c.read(pinControllerProvider(create)).result, 'ok');
      verify(() => vault.disable()).called(1);
    });

    test('mismatch restarts from the first entry and stores nothing', () async {
      final c = make(create);
      await type(c, create, '246810');
      await type(c, create, '246811');
      final s = c.read(pinControllerProvider(create));
      expect(s.phase, PinPhase.enter);
      expect(s.message, contains('không khớp'));
      verifyNever(() => repo.setPin(any(), pinToken: any(named: 'pinToken')));
    });

    test('first PIN without a fresh OTP session asks for email verification, then retries', () async {
      var calls = 0;
      when(() => repo.setPin('246810', pinToken: null)).thenAnswer((_) async {
        if (++calls == 1) throw const AppFailure('pin_invalid', detail: {'reason': 'otp_required'});
      });
      final c = make(create);
      await type(c, create, '246810');
      await type(c, create, '246810');
      expect(c.read(pinControllerProvider(create)).needsOtp, isTrue);
      await c.read(pinControllerProvider(create).notifier).retryCreate();
      expect(c.read(pinControllerProvider(create)).result, 'ok');
    });
  });

  group('change', () {
    test('old PIN -> token -> new PIN twice -> set_withdraw_pin(new, token) -> vault dropped', () async {
      when(() => repo.verify('111111')).thenAnswer((_) async => ok('old-tok'));
      when(() => repo.setPin('222222', pinToken: 'old-tok')).thenAnswer((_) async {});
      final c = make(change);
      expect(c.read(pinControllerProvider(change)).phase, PinPhase.old);
      await type(c, change, '111111');
      expect(c.read(pinControllerProvider(change)).phase, PinPhase.enter);
      await type(c, change, '222222');
      await type(c, change, '222222');
      expect(c.read(pinControllerProvider(change)).result, 'ok');
      verify(() => repo.setPin('222222', pinToken: 'old-tok')).called(1);
      verify(() => vault.disable()).called(1);
    });

    test('failed change keeps the vault untouched', () async {
      when(() => repo.verify(any())).thenAnswer((_) async => ok('t'));
      when(() => repo.setPin(any(), pinToken: any(named: 'pinToken'))).thenThrow(const AppFailure('pin_invalid'));
      final c = make(change);
      await type(c, change, '111111');
      await type(c, change, '222222');
      await type(c, change, '222222');
      expect(c.read(pinControllerProvider(change)).result, isNull);
      verifyNever(() => vault.disable());
    });
  });

  test('pin_state helpers', () {
    expect(PinMode.parse('create'), PinMode.create);
    expect(PinMode.parse('nope'), PinMode.verify);
    expect(PinMode.parse(null), PinMode.verify);
    final now = DateTime.utc(2026, 1, 1, 10);
    expect(lockRemaining(now.add(const Duration(minutes: 15)), now), const Duration(minutes: 15));
    expect(lockRemaining(now.subtract(const Duration(seconds: 5)), now), Duration.zero);
    expect(lockRemaining(null, now), Duration.zero);
    expect(formatCountdown(const Duration(minutes: 14, seconds: 59)), '14:59');
    expect(formatCountdown(const Duration(milliseconds: 500)), '00:01');
    expect(formatCountdown(Duration.zero), '00:00');
  });
}


