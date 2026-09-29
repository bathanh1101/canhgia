import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/search/application/search_providers.dart';
import 'package:canhgia_mobile/features/search/data/search_repository.dart';
import 'package:canhgia_mobile/features/search/presentation/search_results_screen.dart';
import 'package:canhgia_mobile/features/search/presentation/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search_providers_test.dart' show hit;
import 'test_support.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

class _MockRepo extends Mock implements SearchRepository {}

void main() {
  const args = (q: 'tai nghe', merchant: '', sort: 'relevance');
  late _MockRepo repo;

  setUpAll(() => registerFallbackValue(args));
  setUp(() => repo = _MockRepo());

  Future<List<Override>> overrides() async {
    SharedPreferences.setMockInitialValues({
      'recent_searches_v1': ['iphone 16 pro', 'kem chống nắng'],
    });
    return [
      searchRepositoryProvider.overrideWithValue(repo),
      sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
      merchantsProvider.overrideWith((_) async => [shopee, traveloka]),
    ];
  }

  testWidgets('search: recent searches list, tap runs the search, Xóa clears', (t) async {
    await t.pumpWidget(routerApp(const SearchScreen(), overrides: await overrides()));
    await t.pumpAndSettle();
    expect(find.text('Tìm kiếm gần đây'), findsOneWidget);
    expect(find.text('iphone 16 pro'), findsOneWidget);
    await t.tap(find.text('kem chống nắng'));
    await t.pumpAndSettle();
    expect(find.text('RESULTS q=kem+ch%E1%BB%91ng+n%E1%BA%AFng'), findsOneWidget);
  });

  testWidgets('search: Xóa empties the recent list', (t) async {
    await t.pumpWidget(routerApp(const SearchScreen(), overrides: await overrides()));
    await t.pumpAndSettle();
    await t.tap(find.text('Xóa'));
    await t.pumpAndSettle();
    expect(find.text('iphone 16 pro'), findsNothing);
    expect(find.textContaining('Nhập tên sản phẩm'), findsOneWidget);
  });

  testWidgets('search: typing shows suggestions after the 300ms debounce (one backend call)', (t) async {
    when(() => repo.search(any(), limit: 5)).thenAnswer((_) async => [hit(1)]);
    await t.pumpWidget(routerApp(const SearchScreen(), overrides: await overrides()));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'ta');
    await t.enterText(find.byType(TextField), 'tai');
    await t.pump(const Duration(milliseconds: 100));
    verifyNever(() => repo.search(any(), limit: 5));
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    verify(() => repo.search(any(), limit: 5)).called(1);
    expect(find.text('Tìm "tai"'), findsOneWidget);
    expect(find.text('p1'), findsOneWidget);
  });

  testWidgets('results: grouped tile (effective price, N sàn), datafeed-only merchant chips, sort chips', (t) async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => [
          OfferHit.fromJson({
            'offer_id': 1,
            'product_group_id': 5,
            'merchant_id': 'shopee',
            'name': 'Tai nghe Sony WH-1000XM5',
            'price_vnd': 6490000,
            'rate_bps': 700,
            'est_cashback_vnd': 454300,
            'offers_in_group': 4,
          }),
        ]);
    await t.pumpWidget(routerApp(const SearchResultsScreen(args: args), overrides: await overrides()));
    await t.pumpAndSettle();
    expect(find.text('Tai nghe Sony WH-1000XM5'), findsOneWidget);
    expect(find.text('6.035.700đ'), findsOneWidget); // price - est. cashback
    expect(find.text('4 sàn'), findsOneWidget);
    expect(find.text('Hoàn 7% · 454.300đ'), findsOneWidget);
    expect(find.text('Shopee'), findsOneWidget);
    expect(find.text('Traveloka'), findsNothing); // no datafeed -> not a filter option
    expect(find.text('Hoàn tiền cao'), findsOneWidget);
    await t.tap(find.text('Tai nghe Sony WH-1000XM5'));
    await t.pumpAndSettle();
    expect(find.text('COMPARE 5'), findsOneWidget);
  });

  testWidgets('results: empty and error states', (t) async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => []);
    await t.pumpWidget(routerApp(const SearchResultsScreen(args: args), overrides: await overrides()));
    await t.pumpAndSettle();
    expect(find.textContaining('Không tìm thấy sản phẩm'), findsOneWidget);

    when(() => repo.search(any(), limit: 20, offset: 0)).thenThrow(Exception('boom'));
    await t.pumpWidget(routerApp(const SearchResultsScreen(args: (q: 'khac', merchant: '', sort: 'relevance')), overrides: await overrides()));
    await t.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('results: single-offer group opens price history, ungrouped shows the degrade note', (t) async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => [
          OfferHit.fromJson({'offer_id': 1, 'product_group_id': 8, 'merchant_id': 'shopee', 'name': 'A', 'price_vnd': 100, 'offers_in_group': 1}),
          OfferHit.fromJson({'offer_id': 2, 'merchant_id': 'shopee', 'name': 'B', 'price_vnd': 100, 'offers_in_group': 1}),
        ]);
    await t.pumpWidget(routerApp(const SearchResultsScreen(args: args), overrides: await overrides()));
    await t.pumpAndSettle();
    await t.tap(find.text('B'));
    await t.pump();
    expect(find.text('Chưa hỗ trợ so sánh cho sản phẩm này'), findsOneWidget);
    await t.tap(find.text('A'));
    await t.pumpAndSettle();
    expect(find.text('HISTORY 8'), findsOneWidget);
  });
}
