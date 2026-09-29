import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/compare/application/compare_providers.dart';
import 'package:canhgia_mobile/features/compare/data/compare_repository.dart';
import 'package:canhgia_mobile/features/price_history/application/price_history_providers.dart';
import 'package:canhgia_mobile/features/price_history/data/price_history_repository.dart';
import 'package:canhgia_mobile/features/watchlist/application/watchlist_providers.dart';
import 'package:canhgia_mobile/features/watchlist/data/watchlist_repository.dart';
import 'package:canhgia_mobile/features/watchlist/presentation/watchlist_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockWatch extends Mock implements WatchlistRepository {}

class _MockHistory extends Mock implements PriceHistoryRepository {}

class _MockCompare extends Mock implements CompareRepository {}

GroupInfo _info(int g, String name, int price) => GroupInfo(groupId: g, name: name, priceVnd: price, merchantId: 'shopee');

void main() {
  late _MockWatch watch;
  late _MockHistory history;
  late _MockCompare compare;

  List<Override> overrides() => [
        watchlistRepositoryProvider.overrideWithValue(watch),
        priceHistoryRepositoryProvider.overrideWithValue(history),
        compareRepositoryProvider.overrideWithValue(compare),
        currentUserIdProvider.overrideWithValue('u1'),
        merchantsProvider.overrideWith((_) async => [shopee]),
      ];

  setUp(() {
    watch = _MockWatch();
    history = _MockHistory();
    compare = _MockCompare();
    when(() => history.groupInfos(any())).thenAnswer((_) async => {
          1: _info(1, 'Tai nghe Sony', 5800000),
          2: _info(2, 'Nồi chiên Philips', 2090000),
        });
    when(() => watch.list('u1')).thenAnswer((_) async => const [
          WatchItem(id: 10, groupId: 1, targetPriceVnd: 5900000),
          WatchItem(id: 11, groupId: 2, targetPriceVnd: 1990000),
        ]);
  });

  test('WatchEntry: reached when current <= target; gap in percent', () {
    const item = WatchItem(id: 1, groupId: 1, targetPriceVnd: 1000);
    expect(const WatchEntry(item: item, currentVnd: 1000).reached, isTrue);
    expect(const WatchEntry(item: item, currentVnd: 1200).gapPercent, 20);
    expect(const WatchEntry(item: item).reached, isFalse);
    expect(const WatchEntry(item: item).gapPercent, isNull);
  });

  test('watchlistProvider compares the raw cheapest price (as the server job) with one batched query', () async {
    final c = ProviderContainer(retry: (_, _) => null, overrides: overrides());
    addTearDown(c.dispose);
    final list = await c.read(watchlistProvider.future);
    expect(list[0].currentVnd, 5800000);
    expect(list[0].reached, isTrue);
    expect(list[1].currentVnd, 2090000);
    verify(() => history.groupInfos(any())).called(1);
    verifyNever(() => compare.compare(any()));
  });

  test('WatchlistRepository.setTarget rejects non-positive targets before touching the backend', () async {
    expect(() => WatchlistRepository(MockSupabaseClient()).setTarget('u', 1, 0), throwsArgumentError);
  });

  testWidgets('list shows current vs target, reached banner and filter', (t) async {
    await t.pumpWidget(routerApp(const WatchlistScreen(), overrides: overrides()));
    await t.pumpAndSettle();
    expect(find.text('Tai nghe Sony'), findsOneWidget);
    expect(find.text('1 sản phẩm đã chạm giá mục tiêu của bạn'), findsOneWidget);
    expect(find.text('Đã đạt mục tiêu'), findsOneWidget);
    expect(find.text('Mục tiêu 5.900.000đ ✎'), findsOneWidget);
    expect(find.text('Cao hơn mục tiêu 5%'), findsOneWidget); // 2.090.000 vs 1.990.000
    await t.tap(find.widgetWithText(ChoiceChip, 'Đạt mục tiêu'));
    await t.pumpAndSettle();
    expect(find.text('Nồi chiên Philips'), findsNothing);
  });

  testWidgets('tap opens price history; edit target writes through the repository', (t) async {
    when(() => watch.setTarget('u1', 1, 5500000)).thenAnswer((_) async => const WatchItem(id: 10, groupId: 1, targetPriceVnd: 5500000));
    await t.pumpWidget(routerApp(const WatchlistScreen(), overrides: overrides()));
    await t.pumpAndSettle();
    await t.tap(find.text('Mục tiêu 5.900.000đ ✎'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '5500000');
    await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Lưu theo dõi giá')));
    await t.pumpAndSettle();
    verify(() => watch.setTarget('u1', 1, 5500000)).called(1);
    await t.tap(find.text('Tai nghe Sony'));
    await t.pumpAndSettle();
    expect(find.text('HISTORY 1'), findsOneWidget);
  });

  testWidgets('swipe deletes the row through the repository', (t) async {
    when(() => watch.remove(11)).thenAnswer((_) async {});
    await t.pumpWidget(routerApp(const WatchlistScreen(), overrides: overrides()));
    await t.pumpAndSettle();
    await t.drag(find.text('Nồi chiên Philips'), const Offset(-600, 0));
    await t.pumpAndSettle();
    verify(() => watch.remove(11)).called(1);
  });

  testWidgets('empty state offers search', (t) async {
    when(() => watch.list('u1')).thenAnswer((_) async => const []);
    await t.pumpWidget(routerApp(const WatchlistScreen(), overrides: overrides()));
    await t.pumpAndSettle();
    expect(find.textContaining('chưa theo dõi sản phẩm nào'), findsOneWidget);
    expect(find.text('Tìm sản phẩm'), findsOneWidget);
  });

  testWidgets('load error shows retry', (t) async {
    when(() => watch.list('u1')).thenThrow(Exception('down'));
    await t.pumpWidget(routerApp(const WatchlistScreen(), overrides: overrides()));
    await t.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
