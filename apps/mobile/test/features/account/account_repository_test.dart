import 'package:canhgia_mobile/features/account/data/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uuid = '3f2b8c1e-9d4a-4b6e-8f10-2a7c5d9e0b13';

  group('parseExtensionQr', () {
    test('accepts canhgia-ext:<uuid> and lowercases', () {
      expect(AccountRepository.parseExtensionQr('canhgia-ext:$uuid'), uuid);
      expect(AccountRepository.parseExtensionQr('canhgia-ext:${uuid.toUpperCase()}'), uuid);
    });

    test('rejects anything else (foreign QR, url, wrong prefix, bad uuid, null)', () {
      for (final bad in [
        null,
        '',
        uuid,
        'https://evil.example/$uuid',
        'canhgia-ext:',
        'canhgia-ext:not-a-uuid',
        'canhgia-ext:$uuid/extra',
        'canhgia:$uuid',
      ]) {
        expect(AccountRepository.parseExtensionQr(bad), isNull, reason: '$bad');
      }
    });
  });

  test('isValidCode guards the confirm route query parameter', () {
    expect(AccountRepository.isValidCode(uuid), isTrue);
    expect(AccountRepository.isValidCode(null), isFalse);
    expect(AccountRepository.isValidCode("'; drop table"), isFalse);
  });
}
