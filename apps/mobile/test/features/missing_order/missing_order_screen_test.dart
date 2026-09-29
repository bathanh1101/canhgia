import 'dart:convert';

import 'package:canhgia_mobile/core/models/merchant.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/kyc/application/kyc_providers.dart';
import 'package:canhgia_mobile/features/kyc/data/photo.dart';
import 'package:canhgia_mobile/features/missing_order/application/missing_order_providers.dart';
import 'package:canhgia_mobile/features/missing_order/data/missing_order_repository.dart';
import 'package:canhgia_mobile/features/missing_order/presentation/missing_order_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MissingOrderRepository {}

final _png = toPhoto(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=='));

class _Picker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pickOne() async => _png;
  @override
  Future<List<PickedPhoto>> pickMany(int limit) async => [_png];
}

Merchant _m(String id, String name, String letter) =>
    Merchant(id: id, name: name, badgeLetter: letter, domains: const [], maxUserRateBps: 0, datafeedEnabled: false, extensionEnabled: false);

Widget _app(_MockRepo repo, {List<MissingReport> reports = const []}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        currentUserIdProvider.overrideWithValue('u1'),
        missingOrderRepositoryProvider.overrideWithValue(repo),
        photoPickerProvider.overrideWithValue(_Picker()),
        merchantsProvider.overrideWith((ref) async => [_m('shopee', 'Shopee', 'S'), _m('lazada', 'Lazada', 'L')]),
        myReportsProvider.overrideWith((ref) async => reports),
      ],
      child: MaterialApp(home: MissingOrderScreen(today: DateTime(2026, 9, 29))),
    );

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUpAll(() => registerFallbackValue(_png));

  testWidgets('shows merchant chips and recent reports with status pills', (t) async {
    _tall(t);
    await t.pumpWidget(_app(_MockRepo(), reports: [
      MissingReport(publicCode: 'KN-000231', merchantId: 'lazada', orderCode: 'Máy lọc', status: 'reviewing', createdAt: DateTime(2026, 9, 20)),
    ]));
    await t.pumpAndSettle();
    expect(find.text('Shopee'), findsOneWidget);
    expect(find.text('Lazada'), findsOneWidget);
    expect(find.text('Yêu cầu gần đây'), findsOneWidget);
    expect(find.text('#KN-000231 · Gửi 20/09'), findsOneWidget);
    expect(find.text('Đang kiểm tra'), findsOneWidget);
  });

  testWidgets('submitting an empty form shows the first validation message and calls nothing', (t) async {
    _tall(t);
    final repo = _MockRepo();
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Gửi yêu cầu'));
    await t.pump();
    expect(find.text('Chọn sàn mua hàng.'), findsOneWidget);
    verifyNever(() => repo.submit(
          uid: any(named: 'uid'),
          merchantId: any(named: 'merchantId'),
          orderCode: any(named: 'orderCode'),
          purchasedOn: any(named: 'purchasedOn'),
          valueVnd: any(named: 'valueVnd'),
          photos: any(named: 'photos'),
        ));
  });

  testWidgets('full happy path: chip, code, date, value, photo -> KN code toast', (t) async {
    _tall(t);
    final repo = _MockRepo();
    when(() => repo.submit(
          uid: any(named: 'uid'),
          merchantId: any(named: 'merchantId'),
          orderCode: any(named: 'orderCode'),
          purchasedOn: any(named: 'purchasedOn'),
          valueVnd: any(named: 'valueVnd'),
          photos: any(named: 'photos'),
        )).thenAnswer((_) async => 'KN-000240');
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Lazada'));
    await t.pump();
    await t.enterText(find.byType(TextField).at(0), '240920LZ41882');
    await t.enterText(find.byType(TextField).at(1), '3490000');
    await t.tap(find.text('Chọn ngày'));
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tải ảnh lên'));
    await t.pumpAndSettle();
    await t.tap(find.text('Gửi yêu cầu'));
    await t.pumpAndSettle();
    final args = verify(() => repo.submit(
          uid: 'u1',
          merchantId: 'lazada',
          orderCode: '240920LZ41882',
          purchasedOn: captureAny(named: 'purchasedOn'),
          valueVnd: 3490000,
          photos: any(named: 'photos'),
        )).captured;
    expect((args.single as DateTime).day, 28); // default = yesterday
    expect(find.textContaining('KN-000240'), findsOneWidget);
  });
}
