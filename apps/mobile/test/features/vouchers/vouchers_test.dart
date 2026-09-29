import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:canhgia_mobile/features/vouchers/application/voucher_providers.dart';
import 'package:canhgia_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:canhgia_mobile/features/vouchers/presentation/vouchers_screen.dart';
import 'package:canhgia_mobile/features/vouchers/presentation/widgets/voucher_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockVouchers extends Mock implements VoucherRepository {}

class _MockLinks extends Mock implements LinkRepository {}

const _v1 = Voucher(id: 1, merchantId: 'shopee', code: 'SHOP15', discountText: 'Giảm 15% tối đa 80K', description: 'Toàn sàn', url: 'https://shopee.vn/v');
const _v2 = Voucher(id: 2, merchantId: 'traveloka', title: 'Giảm 8% khách sạn');

void main() {
  test('Voucher.fromJson + headline fallbacks + hasCode', () {
    final v = Voucher.fromJson({'id': 3, 'merchant_id': 'shopee', 'code': ' ', 'title': null, 'discount_text': null, 'ends_at': '2026-10-02T00:00:00Z'});
    expect(v.headline, 'Voucher');
    expect(v.hasCode, isFalse);
    expect(v.endsAt, isNotNull);
    expect(_v2.headline, 'Giảm 8% khách sạn');
    expect(_v1.hasCode, isTrue);
  });

  test('filterVouchers keeps only saved ids for the saved chip', () {
    expect(filterVouchers([_v1, _v2], voucherFilterSaved, {2}), [_v2]);
    expect(filterVouchers([_v1, _v2], voucherFilterAll, {2}), [_v1, _v2]);
    expect(filterVouchers([_v1, _v2], 'shopee', <int>{}), [_v1, _v2]); // merchant filter is server-side
  });

  test('voucherExpiryText', () {
    final now = DateTime(2026, 9, 29, 10);
    expect(voucherExpiryText(null, now), 'Không giới hạn');
    expect(voucherExpiryText(DateTime(2026, 9, 29, 23), now), 'Hết hạn hôm nay');
    expect(voucherExpiryText(DateTime(2026, 10, 1, 12), now), 'Còn 2 ngày');
    expect(voucherExpiryText(DateTime(2026, 10, 30, 12), now), 'HSD 30/10');
  });

  group('SavedVoucherIds', () {
    late _MockVouchers repo;
    late ProviderContainer c;
    setUp(() {
      repo = _MockVouchers();
      when(() => repo.savedIds('u1')).thenAnswer((_) async => {1});
      c = ProviderContainer(retry: (_, _) => null, overrides: [
        voucherRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue('u1'),
      ]);
      addTearDown(c.dispose);
    });

    test('toggle saves optimistically and unsaves an existing id', () async {
      when(() => repo.save('u1', 2)).thenAnswer((_) async {});
      when(() => repo.unsave('u1', 1)).thenAnswer((_) async {});
      await c.read(savedVoucherIdsProvider.future);
      await c.read(savedVoucherIdsProvider.notifier).toggle(2);
      expect(c.read(savedVoucherIdsProvider).value, {1, 2});
      await c.read(savedVoucherIdsProvider.notifier).toggle(1);
      expect(c.read(savedVoucherIdsProvider).value, {2});
      verify(() => repo.save('u1', 2)).called(1);
      verify(() => repo.unsave('u1', 1)).called(1);
    });

    test('write failure rolls back and rethrows', () async {
      when(() => repo.save('u1', 2)).thenThrow(Exception('rls'));
      await c.read(savedVoucherIdsProvider.future);
      await expectLater(c.read(savedVoucherIdsProvider.notifier).toggle(2), throwsException);
      expect(c.read(savedVoucherIdsProvider).value, {1});
    });
  });

  group('VouchersScreen', () {
    late _MockVouchers repo;
    late _MockLinks links;
    late List<String> copied;

    Widget app() => routerApp(const VouchersScreen(), overrides: [
          voucherRepositoryProvider.overrideWithValue(repo),
          linkRepositoryProvider.overrideWithValue(links),
          currentUserIdProvider.overrideWithValue('u1'),
          merchantsProvider.overrideWith((_) async => [shopee, traveloka]),
          deviceIdProvider.overrideWithValue('dev'),
          clipboardWriterProvider.overrideWithValue((s) async => copied.add(s)),
        ]);

    setUp(() {
      repo = _MockVouchers();
      links = _MockLinks();
      copied = [];
      when(() => repo.active(merchantId: null)).thenAnswer((_) async => [_v1, _v2]);
      when(() => repo.active(merchantId: 'shopee')).thenAnswer((_) async => [_v1]);
      when(() => repo.savedIds('u1')).thenAnswer((_) async => {2});
      when(() => repo.save('u1', 1)).thenAnswer((_) async {});
    });

    testWidgets('lists vouchers with saved count; merchant chip filters server-side', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Giảm 15% tối đa 80K'), findsOneWidget);
      expect(find.text('Giảm 8% khách sạn'), findsOneWidget);
      expect(find.text('1 mã đã lưu'), findsOneWidget);
      await t.tap(find.widgetWithText(ChoiceChip, 'Shopee'));
      await t.pumpAndSettle();
      verify(() => repo.active(merchantId: 'shopee')).called(1);
      expect(find.text('Giảm 8% khách sạn'), findsNothing);
    });

    testWidgets('saved chip shows only saved vouchers', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, 'Đã lưu'));
      await t.pumpAndSettle();
      expect(find.text('Giảm 8% khách sạn'), findsOneWidget);
      expect(find.text('Giảm 15% tối đa 80K'), findsNothing);
    });

    testWidgets('Lưu mã toggles to Đã lưu; copy puts the code on the clipboard', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu mã').first);
      await t.pumpAndSettle();
      verify(() => repo.save('u1', 1)).called(1);
      expect(find.text('2 mã đã lưu'), findsOneWidget);
      await t.tap(find.byTooltip('Sao chép mã'));
      await t.pumpAndSettle();
      expect(copied, ['SHOP15']);
    });

    testWidgets('Dùng ngay creates an attributed link for the voucher url', (t) async {
      when(() => links.create(merchantId: 'shopee', deviceId: 'dev', url: 'https://shopee.vn/v')).thenAnswer((_) async =>
          CreatedLink.fromJson({'click_id': 77, 'aff_link': 'https://go.example/a', 'merchant_id': 'shopee', 'activation_hours': 24}));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.text('Dùng ngay').first);
      await t.pumpAndSettle();
      expect(find.text('LINK 77'), findsOneWidget);
    });

    testWidgets('list error shows retry', (t) async {
      when(() => repo.active(merchantId: null)).thenThrow(Exception('down'));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
