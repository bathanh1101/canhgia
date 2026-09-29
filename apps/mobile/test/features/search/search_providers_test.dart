import 'package:canhgia_mobile/features/search/application/search_providers.dart';
import 'package:canhgia_mobile/features/search/data/search_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements SearchRepository {}

OfferHit hit(int id) => OfferHit.fromJson({
      'offer_id': id,
      'product_group_id': id,
      'merchant_id': 'shopee',
      'name': 'p$id',
      'price_vnd': 100,
      'rate_bps': 0,
      'est_cashback_vnd': 0,
      'offers_in_group': 1,
    });

void main() {
  const args = (q: 'tai nghe', merchant: '', sort: 'relevance');
  late _MockRepo repo;
  late ProviderContainer c;

  setUpAll(() => registerFallbackValue(args));
  setUp(() {
    repo = _MockRepo();
    c = ProviderContainer(retry: (_, _) => null, overrides: [searchRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
  });

  test('first page of 20 -> hasMore; loadMore appends with the right offset; short page ends paging', () async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => [for (var i = 0; i < 20; i++) hit(i)]);
    when(() => repo.search(any(), limit: 20, offset: 20)).thenAnswer((_) async => [for (var i = 20; i < 25; i++) hit(i)]);
    final first = await c.read(searchResultsProvider(args).future);
    expect(first.items.length, 20);
    expect(first.hasMore, isTrue);
    await c.read(searchResultsProvider(args).notifier).loadMore();
    final all = c.read(searchResultsProvider(args)).value!;
    expect(all.items.length, 25);
    expect(all.hasMore, isFalse);
    await c.read(searchResultsProvider(args).notifier).loadMore(); // no-op at the end
    verify(() => repo.search(any(), limit: 20, offset: 20)).called(1);
  });

  test('loadMore failure keeps the items and flags a retry; duplicates across pages are dropped', () async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => [for (var i = 0; i < 20; i++) hit(i)]);
    when(() => repo.search(any(), limit: 20, offset: 20)).thenThrow(Exception('boom'));
    await c.read(searchResultsProvider(args).future);
    await c.read(searchResultsProvider(args).notifier).loadMore();
    var s = c.read(searchResultsProvider(args)).value!;
    expect(s.items.length, 20);
    expect(s.loadMoreFailed, isTrue);
    expect(s.loadingMore, isFalse);
    await c.read(searchResultsProvider(args).notifier).loadMore(); // scroll tick after failure: no new request
    verify(() => repo.search(any(), limit: 20, offset: 20)).called(1);
    when(() => repo.search(any(), limit: 20, offset: 20)).thenAnswer((_) async => [hit(19), hit(20)]);
    await c.read(searchResultsProvider(args).notifier).loadMore(retry: true);
    s = c.read(searchResultsProvider(args)).value!;
    expect(s.items.length, 21);
    expect(s.loadMoreFailed, isFalse);
  });

  test('offset follows server rows, not the de-duplicated count (all-duplicate page cannot loop)', () async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenAnswer((_) async => [for (var i = 0; i < 20; i++) hit(i)]);
    when(() => repo.search(any(), limit: 20, offset: 20)).thenAnswer((_) async => [for (var i = 0; i < 20; i++) hit(i)]);
    when(() => repo.search(any(), limit: 20, offset: 40)).thenAnswer((_) async => [hit(50)]);
    await c.read(searchResultsProvider(args).future);
    await c.read(searchResultsProvider(args).notifier).loadMore();
    var s = c.read(searchResultsProvider(args)).value!;
    expect((s.items.length, s.fetched), (20, 40));
    await c.read(searchResultsProvider(args).notifier).loadMore();
    s = c.read(searchResultsProvider(args)).value!;
    expect((s.items.length, s.fetched, s.hasMore), (21, 41, false));
  });

  test('first-page failure surfaces as AsyncError', () async {
    when(() => repo.search(any(), limit: 20, offset: 0)).thenThrow(Exception('boom'));
    await expectLater(c.read(searchResultsProvider(args).future), throwsException);
  });

  test('suggestions: under 2 chars do not hit the backend; otherwise top 5', () async {
    when(() => repo.search(any(), limit: 5)).thenAnswer((_) async => [hit(1)]);
    expect(await c.read(searchSuggestionsProvider('t').future), isEmpty);
    verifyNever(() => repo.search(any(), limit: 5));
    expect((await c.read(searchSuggestionsProvider('tai').future)).length, 1);
  });
}
