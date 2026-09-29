import 'dart:typed_data';

import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/kyc/application/kyc_logic.dart';
import 'package:canhgia_mobile/features/kyc/data/kyc_repository.dart';
import 'package:canhgia_mobile/features/kyc/data/photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../wallet/fake_supabase.dart';

class _MockUploader extends Mock implements PhotoUploader {}

KycProfile _p(String status) => KycProfile(status: status, fullName: 'Nguyễn Văn Minh', last4: '1234');

final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]);

void main() {
  setUpAll(() => registerFallbackValue(toPhoto(_jpeg)));

  test('id number: 9 or 12 digits only', () {
    for (final ok in ['079123456789', '123456789']) {
      expect(isValidIdNumber(ok), isTrue, reason: ok);
    }
    for (final bad in ['', '12345678', '1234567890', '07912345678a', '0791234567890', ' 079123456789']) {
      expect(isValidIdNumber(bad), isFalse, reason: bad);
    }
  });

  test('account number: 6-19 digits, spaces tolerated', () {
    expect(isValidAccountNumber('0071 0012 3456 789'), isTrue);
    expect(isValidAccountNumber('12345'), isFalse);
    expect(isValidAccountNumber('1' * 20), isFalse);
    expect(isValidAccountNumber('12345a'), isFalse);
  });

  test('name match ignores diacritics, case and spacing', () {
    expect(nameMatchesCccd('NGUYEN  VAN MINH', 'Nguyễn Văn Minh'), isTrue);
    expect(nameMatchesCccd('nguyen van minh', 'Nguyễn Văn Minh'), isTrue);
    expect(nameMatchesCccd('NGUYEN VAN MINHH', 'Nguyễn Văn Minh'), isFalse);
    expect(nameMatchesCccd('', ''), isFalse);
  });

  test('resume step follows kyc status, bank accounts and pin', () {
    expect(kycResumeStep(profile: null, bankAccounts: 0, hasPin: false), 1);
    expect(kycResumeStep(profile: _p('pending'), bankAccounts: 0, hasPin: false), 1);
    expect(kycResumeStep(profile: _p('rejected'), bankAccounts: 0, hasPin: false), 1);
    expect(kycResumeStep(profile: _p('verified'), bankAccounts: 0, hasPin: false), 2);
    expect(kycResumeStep(profile: _p('verified'), bankAccounts: 1, hasPin: false), 3);
    expect(kycResumeStep(profile: _p('verified'), bankAccounts: 1, hasPin: true), 3);
  });

  group('photos', () {
    test('sniffImage recognises JPEG and PNG by magic bytes only', () {
      expect(sniffImage(_jpeg)!.ext, 'jpg');
      expect(sniffImage(_png)!.mime, 'image/png');
      expect(sniffImage(Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0, 0, 0])), isNull); // gif
      expect(sniffImage(Uint8List(0)), isNull);
    });

    test('toPhoto rejects non-images and oversized files with invalid_input', () {
      expect(() => toPhoto(Uint8List.fromList([1, 2, 3, 4, 5])), throwsA(isA<AppFailure>()));
      final big = Uint8List(maxPhotoBytes + 1)..setAll(0, _jpeg);
      expect(() => toPhoto(big), throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'invalid_input')));
      expect(toPhoto(_jpeg).mime, 'image/jpeg');
    });
  });

  group('KycRepository.submit', () {
    late MockSupabase db;
    late _MockUploader up;
    setUp(() {
      db = MockSupabase();
      up = _MockUploader();
    });

    test('uploads front then back under the uid prefix, then submit_kyc with those paths', () async {
      var n = 0;
      when(() => up.upload(bucket: any(named: 'bucket'), uid: any(named: 'uid'), name: any(named: 'name'), photo: any(named: 'photo')))
          .thenAnswer((i) async => '${i.namedArguments[#uid]}/${i.namedArguments[#name]}.jpg#${++n}');
      stubRpc(db, 'submit_kyc', 'pending');
      await KycRepository(db, up).submit(
        uid: 'u1',
        fullName: 'Nguyễn Văn Minh',
        idNumber: '079123456789',
        front: toPhoto(_jpeg),
        back: toPhoto(_png),
      );
      final p = lastRpcParams(db, 'submit_kyc')!;
      expect(p['p_full_name'], 'Nguyễn Văn Minh');
      expect(p['p_id_number'], '079123456789');
      expect(p['p_front_path'], allOf(startsWith('u1/front-'), endsWith('#1')));
      expect(p['p_back_path'], allOf(startsWith('u1/back-'), endsWith('#2')));
      verify(() => up.upload(bucket: 'kyc', uid: 'u1', name: any(named: 'name'), photo: any(named: 'photo'))).called(2);
    });

    test('an upload failure means submit_kyc is never called', () async {
      when(() => up.upload(bucket: any(named: 'bucket'), uid: any(named: 'uid'), name: any(named: 'name'), photo: any(named: 'photo')))
          .thenThrow(const StorageException('boom'));
      await expectLater(
        KycRepository(db, up).submit(uid: 'u1', fullName: 'A B', idNumber: '079123456789', front: toPhoto(_jpeg), back: toPhoto(_jpeg)),
        throwsA(isA<StorageException>()),
      );
      verifyNever(() => db.rpc<dynamic>('submit_kyc', params: any(named: 'params'), get: any(named: 'get')));
    });

    test('addBank passes bin/number/name and returns the id', () async {
      stubRpc(db, 'add_bank_account', 'bank-uuid');
      final id = await KycRepository(db, up).addBank(bankBin: '970436', accountNumber: '0071001234', accountName: 'NGUYEN VAN MINH');
      expect(id, 'bank-uuid');
      expect(lastRpcParams(db, 'add_bank_account'), {
        'p_bank_bin': '970436',
        'p_account_number': '0071001234',
        'p_account_name': 'NGUYEN VAN MINH',
      });
    });
  });

  test('KycProfile.fromJson', () {
    final p = KycProfile.fromJson({'status': 'rejected', 'full_name': 'A', 'id_number_last4': '9999', 'reject_reason': 'Ảnh mờ', 'submitted_at': '2026-10-01T00:00:00Z'});
    expect((p.isRejected, p.rejectReason, p.last4), (true, 'Ảnh mờ', '9999'));
  });
}
