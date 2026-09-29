import 'package:canhgia_mobile/core/device/push_token_service.dart';
import 'package:canhgia_mobile/core/providers/referral_store.dart';
import 'package:canhgia_mobile/core/security/biometric_pin_vault.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/auth/application/auth_controller.dart';
import 'package:canhgia_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRepo extends Mock implements AuthRepository {}

class _MockPush extends Mock implements PushTokenService {}

class _MockReferral extends Mock implements ReferralStore {}

class _MockVault extends Mock implements BiometricPinVault {}

void main() {
  late _MockRepo repo;
  late _MockVault vault;
  late _MockPush push;
  late _MockReferral referral;
  late ProviderContainer c;

  setUp(() {
    repo = _MockRepo();
    vault = _MockVault();
    push = _MockPush();
    referral = _MockReferral();
    when(() => vault.disable()).thenAnswer((_) async {});
    when(() => push.unregister()).thenAnswer((_) async {});
    when(() => referral.clear()).thenAnswer((_) async {});
    c = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      biometricPinVaultProvider.overrideWithValue(vault),
      pushTokenServiceProvider.overrideWithValue(push),
      referralStoreProvider.overrideWithValue(referral),
    ]);
    addTearDown(c.dispose);
  });

  AuthController ctl() => c.read(authControllerProvider.notifier);

  test('initial state is idle', () {
    expect(c.read(authControllerProvider), const AsyncData<void>(null));
  });

  test('Google success ends idle and calls the repository once', () async {
    when(() => repo.signInWithGoogle()).thenAnswer((_) async => true);
    await ctl().signInWithGoogle();
    expect(c.read(authControllerProvider).hasError, isFalse);
    verify(() => repo.signInWithGoogle()).called(1);
  });

  test('Google cancelled by the user is not an error', () async {
    when(() => repo.signInWithGoogle()).thenAnswer((_) async => false);
    await ctl().signInWithGoogle();
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('Google unconfigured surfaces a Vietnamese message', () async {
    when(() => repo.signInWithGoogle()).thenThrow(const AppFailure('google_not_configured'));
    await ctl().signInWithGoogle();
    final s = c.read(authControllerProvider);
    expect(s.hasError, isTrue);
    expect(mapErrorMessage(s.error!), errorMessagesVi['google_not_configured']);
  });

  test('sendEmailOtp forwards email and captcha token', () async {
    when(() => repo.sendEmailOtp(any(), captchaToken: any(named: 'captchaToken'))).thenAnswer((_) async {});
    await ctl().sendEmailOtp('a@b.co', captchaToken: 'tok');
    verify(() => repo.sendEmailOtp('a@b.co', captchaToken: 'tok')).called(1);
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('verify failure keeps the auth error mapped (wrong code)', () async {
    when(() => repo.verifyEmailOtp(any(), any())).thenThrow(const AuthException('bad', code: 'otp_expired'));
    await ctl().verifyEmailOtp('a@b.co', '123456');
    expect(mapErrorMessage(c.read(authControllerProvider).error!), contains('hết hạn'));
  });

  test('a call in flight blocks a second tap', () async {
    var calls = 0;
    when(() => repo.signInWithGoogle()).thenAnswer((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return true;
    });
    final first = ctl().signInWithGoogle();
    expect(c.read(authControllerProvider).isLoading, isTrue);
    await ctl().signInWithGoogle();
    await first;
    expect(calls, 1);
  });

  test('a new attempt after an error clears it', () async {
    when(() => repo.signInWithGoogle()).thenThrow(const AppFailure('network'));
    await ctl().signInWithGoogle();
    expect(c.read(authControllerProvider).hasError, isTrue);
    when(() => repo.signInWithGoogle()).thenAnswer((_) async => true);
    await ctl().signInWithGoogle();
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('signOut cleans push token, vault, referral in order, then signs out', () async {
    when(() => repo.signOut()).thenAnswer((_) async {});
    await ctl().signOut();
    verifyInOrder([() => push.unregister(), () => vault.disable(), () => referral.clear(), () => repo.signOut()]);
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('signOut still runs when every cleanup step throws', () async {
    when(() => push.unregister()).thenThrow(Exception('fcm'));
    when(() => vault.disable()).thenThrow(Exception('keystore'));
    when(() => referral.clear()).thenThrow(Exception('prefs'));
    when(() => repo.signOut()).thenAnswer((_) async {});
    await ctl().signOut();
    verify(() => repo.signOut()).called(1);
    expect(c.read(authControllerProvider).hasError, isFalse);
  });
}
