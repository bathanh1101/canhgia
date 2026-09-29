import 'package:canhgia_mobile/core/security/biometric_pin_vault.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuth extends Mock implements LocalAuthentication {}

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockAuth auth;
  late _MockStorage storage;
  late BiometricPinVault vault;

  setUp(() {
    auth = _MockAuth();
    storage = _MockStorage();
    vault = BiometricPinVault('user-1', auth: auth, storage: storage);
    when(() => storage.write(key: any(named: 'key'), value: any(named: 'value'))).thenAnswer((_) async {});
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  void prompt(bool ok) => when(() => auth.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: any(named: 'biometricOnly'),
      )).thenAnswer((_) async => ok);

  test('enable stores the PIN under a per-user key after a successful prompt', () async {
    prompt(true);
    expect(await vault.enable('123456'), isTrue);
    verify(() => storage.write(key: 'pin_vault_v1:user-1', value: '123456')).called(1);
  });

  test('enable stores nothing when the biometric prompt fails or is cancelled', () async {
    prompt(false);
    expect(await vault.enable('123456'), isFalse);
    verifyNever(() => storage.write(key: any(named: 'key'), value: any(named: 'value')));
  });

  test('platform error during prompt counts as not authenticated', () async {
    when(() => auth.authenticate(
          localizedReason: any(named: 'localizedReason'),
          biometricOnly: any(named: 'biometricOnly'),
        )).thenThrow(PlatformException(code: 'NotAvailable'));
    expect(await vault.enable('123456'), isFalse);
  });

  test('enable validates the PIN shape', () {
    for (final bad in ['', '12345', '1234567', 'abcdef']) {
      expect(() => vault.enable(bad), throwsArgumentError, reason: bad);
    }
    verifyNever(() => auth.authenticate(localizedReason: any(named: 'localizedReason')));
  });

  test('readPinWithBiometric returns null unless enabled and authenticated', () async {
    when(() => storage.containsKey(key: 'pin_vault_v1:user-1')).thenAnswer((_) async => false);
    expect(await vault.readPinWithBiometric(), isNull);

    when(() => storage.containsKey(key: 'pin_vault_v1:user-1')).thenAnswer((_) async => true);
    when(() => storage.read(key: 'pin_vault_v1:user-1')).thenAnswer((_) async => '654321');
    prompt(false);
    expect(await vault.readPinWithBiometric(), isNull);
    prompt(true);
    expect(await vault.readPinWithBiometric(), '654321');
  });

  test('disable deletes the entry; signed-out vault is inert', () async {
    await vault.disable();
    verify(() => storage.delete(key: 'pin_vault_v1:user-1')).called(1);

    final out = BiometricPinVault(null, auth: auth, storage: storage);
    expect(await out.isEnabled(), isFalse);
    await out.disable();
    verifyNoMoreInteractions(storage);
  });
}
