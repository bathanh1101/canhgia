import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuth extends Mock implements GoTrueClient {}

void main() {
  setUpAll(() => registerFallbackValue(OtpType.email));
  late _MockAuth auth;
  late AuthRepository repo;

  setUp(() {
    auth = _MockAuth();
    repo = AuthRepository(auth, googleTokens: (_) async => (idToken: 'id', accessToken: 'at'));
  });

  test('sendEmailOtp passes trimmed email, shouldCreateUser and captcha', () async {
    when(() => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
          captchaToken: any(named: 'captchaToken'),
        )).thenAnswer((_) async {});
    await repo.sendEmailOtp('  a@b.co ', captchaToken: 'cap');
    verify(() => auth.signInWithOtp(email: 'a@b.co', shouldCreateUser: true, captchaToken: 'cap')).called(1);
  });

  test('sendEmailOtp(createUser: false) never creates a user (PIN re-verification)', () async {
    when(() => auth.signInWithOtp(
          email: any(named: 'email'),
          shouldCreateUser: any(named: 'shouldCreateUser'),
          captchaToken: any(named: 'captchaToken'),
        )).thenAnswer((_) async {});
    await repo.sendEmailOtp('a@b.co', createUser: false);
    verify(() => auth.signInWithOtp(email: 'a@b.co', shouldCreateUser: false)).called(1);
  });

  test('sendEmailOtp rejects malformed email before hitting the network', () {
    for (final bad in ['', 'abc', 'a@b', '@b.co', 'a b@c.de']) {
      expect(() => repo.sendEmailOtp(bad), throwsA(isA<AppFailure>().having((f) => f.code, 'code', 'invalid_input')), reason: bad);
    }
    verifyZeroInteractions(auth);
  });

  test('verifyEmailOtp uses OtpType.email with a 6 digit code', () async {
    when(() => auth.verifyOTP(email: any(named: 'email'), token: any(named: 'token'), type: any(named: 'type')))
        .thenAnswer((_) async => AuthResponse());
    await repo.verifyEmailOtp('a@b.co', ' 123456 ');
    verify(() => auth.verifyOTP(email: 'a@b.co', token: '123456', type: OtpType.email)).called(1);
  });

  test('verifyEmailOtp rejects non 6-digit codes locally', () {
    for (final bad in ['', '12345', '1234567', 'abcdef', '12 456']) {
      expect(() => repo.verifyEmailOtp('a@b.co', bad), throwsA(isA<AppFailure>()), reason: bad);
    }
    verifyZeroInteractions(auth);
  });

  test('Google without a configured web client id fails cleanly (no native call)', () {
    expect(
      () => repo.signInWithGoogle(),
      throwsA(isA<AppFailure>().having((f) => f.code, 'code', 'google_not_configured')),
    );
  });

  group('Google nonce', () {
    test('hashNonce is sha256 hex (known vector)', () {
      expect(hashNonce('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
    });

    test('generateRawNonce is 64 hex chars and differs per call', () {
      final a = generateRawNonce();
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(generateRawNonce(), isNot(a));
    });
  });
}
