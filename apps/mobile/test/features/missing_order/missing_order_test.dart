import 'dart:convert';

import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/core/supabase/supabase_providers.dart';
import 'package:canhgia_mobile/features/kyc/application/kyc_providers.dart';
import 'package:canhgia_mobile/features/kyc/data/photo.dart';
import 'package:canhgia_mobile/features/missing_order/application/missing_order_providers.dart';
import 'package:canhgia_mobile/features/missing_order/application/missing_order_validation.dart';
import 'package:canhgia_mobile/features/missing_order/data/missing_order_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../wallet/fake_supabase.dart';

class _MockUploader extends Mock implements PhotoUploader {}

final _png = toPhoto(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));
final _today = DateTime(2026, 9, 29);

String? _validate({String? m = 'shopee', String code = '240920LZ41882', DateTime? on, int v = 349000, int photos = 1}) => validateMissingOrder(
      merchantId: m,
      orderCode: code,
      purchasedOn: on ?? DateTime(2026, 9, 20),
      valueVnd: v,
      photoCount: photos,
      today: _today,
    );

void main() {
  setUpAll(() => registerFallbackValue(_png));

  group('validateMissingOrder mirrors the server checks', () {
    test('valid input', () => expect(_validate(), isNull));
    test('merchant required', () => expect(_validate(m: null), isNotNull));
    test('order code 4..40 alphanumerics', () {
      expect(_validate(code: 'A-1'), isNotNull);
      expect(_validate(code: '---- ----'), isNotNull);
      expect(_validate(code: 'A' * 41), isNotNull);
      expect(_validate(code: 'ab-12'), isNull);
    });
    test('purchase date: yesterday..60 days ago', () {
      expect(_validate(on: DateTime(2026, 9, 28)), isNull);
      expect(_validate(on: DateTime(2026, 9, 29)), isNotNull);
      expect(_validate(on: DateTime(2026, 7, 31)), isNull);
      expect(_validate(on: DateTime(2026, 7, 30)), isNotNull);
    });
    test('value bounds', () {
      expect(_validate(v: 0), isNotNull);
      expect(_validate(v: 1000000001), isNotNull);
      expect(_validate(v: 1000000000), isNull);
    });
    test('1..3 photos', () {
      expect(_validate(photos: 0), isNotNull);
      expect(_validate(photos: 4), isNotNull);
      expect(_validate(photos: 3), isNull);
    });
  });

  test('error messages for rate limit and duplicates', () {
    expect(missingOrderErrorMessage(const AppFailure('rate_limited')), contains('tối đa 5'));
    expect(missingOrderErrorMessage(const AppFailure('invalid_input', detail: {'reason': 'duplicate_order_code'})), contains('đã được báo'));
    expect(missingOrderErrorMessage(const AppFailure('invalid_input')), errorMessagesVi['invalid_input']);
  });

  group('repository.submit', () {
    test('uploads each photo to complaints/<uid>/..., then RPC with the paths and yyyy-MM-dd date; returns KN code', () async {
      final db = MockSupabase();
      final up = _MockUploader();
      var n = 0;
      when(() => up.upload(bucket: 'complaints', uid: 'u1', name: any(named: 'name'), photo: any(named: 'photo')))
          .thenAnswer((_) async => 'u1/img-${++n}.png');
      stubRpc(db, 'submit_missing_order', 'KN-000231');
      final code = await MissingOrderRepository(db, up).submit(
        uid: 'u1',
        merchantId: 'lazada',
        orderCode: ' 240920LZ41882 ',
        purchasedOn: DateTime(2026, 9, 5),
        valueVnd: 349000,
        photos: [_png, _png],
      );
      expect(code, 'KN-000231');
      expect(lastRpcParams(db, 'submit_missing_order'), {
        'p_merchant_id': 'lazada',
        'p_order_code': '240920LZ41882',
        'p_purchased_on': '2026-09-05',
        'p_value': 349000,
        'p_image_paths': ['u1/img-1.png', 'u1/img-2.png'],
      });
    });

    test('report row mapping and pill keys', () {
      MissingReport r(String s) =>
          MissingReport.fromJson({'public_code': 'KN-1', 'merchant_id': 'lazada', 'order_code': 'X', 'status': s, 'created_at': '2026-09-20T00:00:00Z'});
      expect(r('pending').pillKey, 'checking');
      expect(r('reviewing').pillKey, 'checking');
      expect(r('approved').pillKey, 'approved');
      expect(r('rejected').pillKey, 'rejected');
    });
  });

  group('MissingOrderForm', () {
    late MockSupabase db;
    late _MockUploader up;
    late ProviderContainer c;
    setUp(() {
      db = MockSupabase();
      up = _MockUploader();
      c = ProviderContainer(overrides: [
        supabaseProvider.overrideWithValue(db),
        photoUploaderProvider.overrideWithValue(up),
        myReportsProvider.overrideWith((ref) async => const []),
      ]);
      c.listen(missingOrderFormProvider, (_, _) {});
      addTearDown(c.dispose);
    });

    void fill(MissingOrderForm f, {int photos = 1}) => f
      ..setMerchant('shopee')
      ..setOrderCode('240920LZ41882')
      ..setDate(DateTime(2026, 9, 20))
      ..setValue(349000)
      ..addPhotos([for (var i = 0; i < photos; i++) _png]);

    test('photos are capped at 3 and removable', () {
      final f = c.read(missingOrderFormProvider.notifier)..addPhotos([_png, _png])..addPhotos([_png, _png]);
      expect(c.read(missingOrderFormProvider).photos.length, 3);
      f.removePhoto(0);
      expect(c.read(missingOrderFormProvider).photos.length, 2);
    });

    test('invalid form throws a Vietnamese invalid_input failure and makes no call', () async {
      final f = c.read(missingOrderFormProvider.notifier);
      await expectLater(f.submit('u1', today: _today), throwsA(isA<AppFailure>().having((e) => e.message, 'message', 'Chọn sàn mua hàng.')));
      verifyNever(() => up.upload(bucket: any(named: 'bucket'), uid: any(named: 'uid'), name: any(named: 'name'), photo: any(named: 'photo')));
    });

    test('success returns the code and clears the form; failure keeps the input and unlocks submit', () async {
      when(() => up.upload(bucket: any(named: 'bucket'), uid: any(named: 'uid'), name: any(named: 'name'), photo: any(named: 'photo')))
          .thenAnswer((_) async => 'u1/a.png');
      final f = c.read(missingOrderFormProvider.notifier);
      fill(f);
      stubRpc(db, 'submit_missing_order', null, error: const AppFailure('rate_limited'));
      await expectLater(f.submit('u1', today: _today), throwsA(isA<AppFailure>()));
      expect(c.read(missingOrderFormProvider).submitting, isFalse);
      expect(c.read(missingOrderFormProvider).orderCode, '240920LZ41882');

      stubRpc(db, 'submit_missing_order', 'KN-000232');
      expect(await f.submit('u1', today: _today), 'KN-000232');
      expect(c.read(missingOrderFormProvider).orderCode, isEmpty);
      expect(c.read(missingOrderFormProvider).photos, isEmpty);
    });
  });
}
