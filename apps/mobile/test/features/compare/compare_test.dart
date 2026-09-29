import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/compare/application/compare_providers.dart';
import 'package:canhgia_mobile/features/compare/data/compare_repository.dart';
import 'package:canhgia_mobile/features/compare/presentation/compare_screen.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockCompare extends Mock implements CompareRepository {}

class _MockLinks extends Mock implements LinkRepository {}

Map<String, dynamic> _row(int id, String merchant, int price, int cb, {bool mall = false, bool eligible = true, int? list}) => {
      'offer_id': id,
      'merchant_id': merchant,
      'shop_name': mall ? '$merchant Mall' : 'Shop $id',
      'name': 'Tai nghe Sony WH-1000XM5',
      'url': 'https://$merchant.vn/p$id',
      'image_url': null,
      'price_vnd': price,
      'list_price_vnd': list,
      'est_cashback_vnd': cb,
      'effective_price_vnd': price - cb,
      'is_mall': mall,
      'cashback_eligible': eligible,
    };

final _offers = [
  for (final r in [
    _row(1, 'shopee', 6490000, 454300, list: 6990000),
    _row(2, 'lazada', 6290000, 408900, mall: true),
    _row(3, 'tiki', 6160000, 0, eligible: false),
  ])
    CompareOffer.fromJson(r),
];

void main() {
  test('sortCompare: effective (default), list price, cashback; ties keep server order', () {
    expect(sortCompare(_offers, 'effective').map((o) => o.offerId), [2, 1, 3]);
    expect(sortCompare(_offers, 'list').map((o) => o.offerId), [3, 2, 1]);
    expect(sortCompare(_offers, 'cashback').map((o) => o.offerId), [1, 2, 3]);
    final tie = [CompareOffer.fromJson(_row(9, 'a', 100, 0)), CompareOffer.fromJson(_row(8, 'b', 100, 0))];
    expect(sortCompare(tie, 'effective').map((o) => o.offerId), [9, 8]);
  });

  test('mallOnly filters and cheapestOffer follows the filtered list', () {
    final mall = sortCompare(_offers, 'effective', mallOnly: true);
    expect(mall.map((o) => o.offerId), [2]);
    expect(cheapestOffer(_offers)!.offerId, 2);
    expect(cheapestOffer(mall)!.offerId, 2);
    expect(cheapestOffer(const []), isNull);
  });

  test('effective price falls back to price - cashback when the server omits it', () {
    final o = CompareOffer.fromJson({..._row(1, 'shopee', 1000, 100), 'effective_price_vnd': null});
    expect(o.effectivePriceVnd, 900);
  });

  test('CompareRepository maps get_compare rows and passes the group id', () async {
    final db = MockSupabaseClient();
    when(() => db.rpc<dynamic>('get_compare', params: any(named: 'params')))
        .thenAnswer((_) => FakeBuilder<dynamic>([_row(1, 'shopee', 100, 10), _row(2, 'lazada', 90, 5)]));
    final r = await CompareRepository(db).compare(7);
    expect(verify(() => db.rpc<dynamic>('get_compare', params: captureAny(named: 'params'))).captured.single, {'p_group_id': 7});
    expect(r.length, 2);
  });

  group('CompareScreen', () {
    late _MockCompare repo;
    late _MockLinks links;

    Widget app() => routerApp(const CompareScreen(groupId: '7'), overrides: [
          compareRepositoryProvider.overrideWithValue(repo),
          linkRepositoryProvider.overrideWithValue(links),
          merchantsProvider.overrideWith((_) async => [shopee, traveloka]),
          deviceIdProvider.overrideWithValue('dev'),
        ]);

    setUp(() {
      repo = _MockCompare();
      links = _MockLinks();
    });

    testWidgets('sorted by effective price, cheapest highlighted, bar buys the cheapest with create-link', (t) async {
      when(() => repo.compare(7)).thenAnswer((_) async => _offers);
      when(() => links.create(merchantId: 'lazada', deviceId: 'dev', url: 'https://lazada.vn/p2')).thenAnswer((_) async =>
          CreatedLink.fromJson({'click_id': 3, 'aff_link': 'https://go.example/a', 'merchant_id': 'lazada', 'activation_hours': 24}));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Tìm thấy 3 shop'), findsOneWidget);
      expect(find.text('Rẻ nhất'), findsOneWidget);
      expect(find.text('Không hoàn tiền'), findsOneWidget);
      double y(String text) => t.getTopLeft(find.text(text)).dy;
      expect(y('5.881.100đ') < y('6.035.700đ'), isTrue); // lazada before shopee
      expect(y('6.035.700đ') < y('6.160.000đ'), isTrue); // shopee before tiki (no cashback)
      await t.tap(find.text('Mua ở lazada · Hoàn 408.900đ'));
      await t.pumpAndSettle();
      verify(() => links.create(merchantId: 'lazada', deviceId: 'dev', url: 'https://lazada.vn/p2')).called(1);
      expect(find.text('LINK 3'), findsOneWidget);
    });

    testWidgets('Mall toggle narrows the list and the buy bar follows', (t) async {
      when(() => repo.compare(7)).thenAnswer((_) async => _offers);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.byType(Switch));
      await t.pumpAndSettle();
      expect(find.text('6.035.700đ'), findsNothing);
      expect(find.text('5.881.100đ'), findsOneWidget);
    });

    testWidgets('fewer than 2 offers -> "Chưa hỗ trợ so sánh" with a history shortcut', (t) async {
      when(() => repo.compare(7)).thenAnswer((_) async => const []);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Chưa hỗ trợ so sánh'), findsOneWidget);
      await t.tap(find.text('Xem lịch sử giá'));
      await t.pumpAndSettle();
      expect(find.text('HISTORY 7'), findsOneWidget);
    });

    testWidgets('create-link error shows the mapped message and stays on the screen', (t) async {
      when(() => repo.compare(7)).thenAnswer((_) async => _offers);
      when(() => links.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url')))
          .thenThrow(const AppFailure('merchant_unavailable'));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Mua ở lazada'));
      await t.pumpAndSettle();
      expect(find.text(errorMessagesVi['merchant_unavailable']!), findsOneWidget);
    });

    testWidgets('load error shows retry', (t) async {
      when(() => repo.compare(7)).thenThrow(Exception('down'));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
