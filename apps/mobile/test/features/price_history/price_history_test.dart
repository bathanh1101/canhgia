import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/features/price_history/application/price_history_providers.dart';
import 'package:canhgia_mobile/features/price_history/data/price_history_repository.dart';
import 'package:canhgia_mobile/features/price_history/presentation/price_history_screen.dart';
import 'package:canhgia_mobile/features/price_history/presentation/widgets/target_price_sheet.dart';
import 'package:canhgia_mobile/features/watchlist/application/watchlist_providers.dart';
import 'package:canhgia_mobile/features/watchlist/data/watchlist_repository.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockHistory extends Mock implements PriceHistoryRepository {}

class _MockWatch extends Mock implements WatchlistRepository {}

PricePoint _p(int dayOffset, int price) => PricePoint(DateTime(2026, 1, 1).add(Duration(days: dayOffset)), price);

void main() {
  test('downsampleWeekly keeps the min per 7-day bucket, in order', () {
    final pts = [_p(0, 100), _p(3, 80), _p(6, 90), _p(7, 70), _p(13, 75), _p(20, 60)];
    final out = downsampleWeekly(pts);
    expect(out.map((p) => p.minPriceVnd), [80, 70, 60]);
    expect(out.first.day, DateTime(2026, 1, 1));
    expect(downsampleWeekly(const []), isEmpty);
  });

  test('chartPoints downsamples only for 6 months and above', () {
    final pts = [for (var i = 0; i < 30; i++) _p(i, 100 + i)];
    expect(chartPoints(pts, 90).length, 30);
    expect(chartPoints(pts, 180).length, lessThan(30));
  });

  test('PriceStats and priceInsight', () {
    final s = PriceStats.of([_p(0, 100), _p(1, 200), _p(2, 300)])!;
    expect((s.min, s.max, s.avg), (100, 300, 200));
    expect(PriceStats.of(const []), isNull);
    expect(priceInsight(188, s, 90), 'Giá đang thấp hơn 6% so với trung bình 90 ngày');
    expect(priceInsight(220, s, 30), 'Giá đang cao hơn 10% so với trung bình 30 ngày');
    expect(priceInsight(200, s, 90), 'Giá đang ngang mức trung bình 90 ngày');
    expect(priceInsight(1, null, 90), isNull);
  });

  test('suggestedTarget is 5% under, rounded down to 1.000đ, never below 1.000đ', () {
    expect(suggestedTarget(6290000), 5975000);
    expect(suggestedTarget(1500), 1000);
    expect(suggestedTarget(0), 1000);
  });

  test('parseVndInput accepts separators, rejects empty/zero/absurd', () {
    expect(parseVndInput('5.900.000đ'), 5900000);
    expect(parseVndInput('5900000'), 5900000);
    for (final bad in ['', '0', 'abc', '99999999999999']) {
      expect(parseVndInput(bad), isNull, reason: bad);
    }
  });

  test('cheapestPerGroup picks the lowest priced offer per group and skips unpriced/ungrouped rows', () {
    Map<String, dynamic> r(int? g, int? price, String m) => {'product_group_id': g, 'price': price, 'name': 'n$m', 'merchant_id': m, 'image_url': null};
    final out = cheapestPerGroup([r(1, 300, 'a'), r(1, 200, 'b'), r(2, 50, 'c'), r(null, 1, 'd'), r(3, null, 'e')]);
    expect(out.keys, unorderedEquals([1, 2]));
    expect(out[1]!.merchantId, 'b');
  });

  test('repository maps get_price_history and sends days', () async {
    final db = MockSupabaseClient();
    when(() => db.rpc<dynamic>('get_price_history', params: any(named: 'params'))).thenAnswer((_) => FakeBuilder<dynamic>([
          {'day': '2026-07-25', 'min_price_vnd': 5690000},
        ]));
    final r = await PriceHistoryRepository(db).history(7, 90);
    expect(verify(() => db.rpc<dynamic>('get_price_history', params: captureAny(named: 'params'))).captured.single, {'p_group_id': 7, 'p_days': 90});
    expect(r.single.minPriceVnd, 5690000);
    expect(r.single.day, DateTime(2026, 7, 25));
  });

  group('PriceHistoryScreen', () {
    late _MockHistory history;
    late _MockWatch watch;
    WatchItem? watching;

    Widget app() => routerApp(const PriceHistoryScreen(groupId: '7'), overrides: [
          priceHistoryRepositoryProvider.overrideWithValue(history),
          watchlistRepositoryProvider.overrideWithValue(watch),
          currentUserIdProvider.overrideWithValue('u1'),
        ]);

    setUp(() {
      // Tall viewport: the screen is one lazy ListView and the alert card sits below the fold.
      final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
      view.physicalSize = const Size(800, 2200);
      view.devicePixelRatio = 1;
      addTearDown(view.resetPhysicalSize);
      addTearDown(view.resetDevicePixelRatio);
      history = _MockHistory();
      watch = _MockWatch();
      watching = null;
      when(() => history.history(7, any())).thenAnswer((_) async => [_p(0, 7490000), _p(1, 5690000), _p(2, 6290000)]);
      when(() => history.groupInfos(any())).thenAnswer((_) async => {
            7: const GroupInfo(groupId: 7, name: 'Tai nghe Sony WH-1000XM5', priceVnd: 6290000, merchantId: 'shopee'),
          });
      when(() => watch.find('u1', 7)).thenAnswer((_) async => watching);
    });

    testWidgets('shows stats, insight and the chart', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Tai nghe Sony WH-1000XM5'), findsOneWidget);
      expect(find.text('5.690.000đ'), findsOneWidget);
      expect(find.text('7.490.000đ'), findsOneWidget);
      expect(find.text('6.290.000đ'), findsOneWidget);
      expect(find.textContaining('so với trung bình 90 ngày'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
    });

    testWidgets('range chip refetches for that many days', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(ChoiceChip, '1 năm'));
      await t.pumpAndSettle();
      verify(() => history.history(7, 365)).called(1);
    });

    testWidgets('save target: sheet prefilled with a suggestion, saves through watchlist_items', (t) async {
      when(() => watch.setTarget('u1', 7, any())).thenAnswer((inv) async => WatchItem(id: 1, groupId: 7, targetPriceVnd: inv.positionalArguments[2] as int));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu theo dõi giá'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextField, '5975000'), findsOneWidget);
      await t.enterText(find.byType(TextField), '5900000');
      await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Lưu theo dõi giá')));
      await t.pumpAndSettle();
      verify(() => watch.setTarget('u1', 7, 5900000)).called(1);
      expect(find.textContaining('Đã đặt cảnh báo khi giá dưới 5.900.000đ'), findsOneWidget);
    });

    testWidgets('invalid target (0) is rejected in the sheet and nothing is written', (t) async {
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu theo dõi giá'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '0');
      await t.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Lưu theo dõi giá')));
      await t.pumpAndSettle();
      expect(find.text('Nhập mức giá lớn hơn 0'), findsOneWidget);
      verifyNever(() => watch.setTarget(any(), any(), any()));
    });

    testWidgets('already watching: shows the target and lets the user stop watching', (t) async {
      watching = const WatchItem(id: 4, groupId: 7, targetPriceVnd: 5900000);
      when(() => watch.remove(4)).thenAnswer((_) async {});
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.textContaining('dưới 5.900.000đ'), findsOneWidget);
      watching = null;
      await t.tap(find.text('Bỏ theo dõi'));
      await t.pumpAndSettle();
      verify(() => watch.remove(4)).called(1);
    });

    testWidgets('no snapshots -> empty message', (t) async {
      when(() => history.history(7, any())).thenAnswer((_) async => const []);
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.textContaining('Chưa có dữ liệu giá'), findsOneWidget);
    });

    testWidgets('failure -> retry', (t) async {
      when(() => history.history(7, any())).thenThrow(Exception('down'));
      await t.pumpWidget(app());
      await t.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
