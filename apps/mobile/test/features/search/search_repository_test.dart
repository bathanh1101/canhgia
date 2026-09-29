import 'package:canhgia_mobile/features/search/data/search_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

Map<String, dynamic> row(int id, {int? group = 1, int inGroup = 3, int price = 1000, int cb = 100}) => {
      'offer_id': id,
      'product_group_id': group,
      'merchant_id': 'shopee',
      'name': 'Tai nghe $id',
      'image_url': null,
      'price_vnd': price,
      'rate_bps': 700,
      'est_cashback_vnd': cb,
      'offers_in_group': inGroup,
    };

void main() {
  test('search calls search_offers with merchant filter, sort, limit and offset', () async {
    final db = MockSupabaseClient();
    when(() => db.rpc<dynamic>('search_offers', params: any(named: 'params'))).thenAnswer((_) => FakeBuilder<dynamic>([row(1), row(2)]));
    final hits = await SearchRepository(db).search((q: 'tai nghe', merchant: 'shopee', sort: 'price_asc'), limit: 20, offset: 40);
    expect(verify(() => db.rpc<dynamic>('search_offers', params: captureAny(named: 'params'))).captured.single, {
      'p_q': 'tai nghe',
      'p_merchants': ['shopee'],
      'p_sort': 'price_asc',
      'p_limit': 20,
      'p_offset': 40,
    });
    expect(hits.map((h) => h.offerId), [1, 2]);
    expect(hits.first.effectivePriceVnd, 900);
  });

  test('all merchants -> null filter; unknown sort falls back to relevance', () async {
    final db = MockSupabaseClient();
    when(() => db.rpc<dynamic>('search_offers', params: any(named: 'params'))).thenAnswer((_) => FakeBuilder<dynamic>(<dynamic>[]));
    await SearchRepository(db).search((q: 'x', merchant: '', sort: 'DROP'));
    final p = verify(() => db.rpc<dynamic>('search_offers', params: captureAny(named: 'params'))).captured.single as Map;
    expect(p['p_merchants'], isNull);
    expect(p['p_sort'], 'relevance');
  });

  test('OfferHit.canCompare needs a group with >= 2 offers; missing group is tolerated', () {
    expect(OfferHit.fromJson(row(1)).canCompare, isTrue);
    expect(OfferHit.fromJson(row(1, inGroup: 1)).canCompare, isFalse);
    expect(OfferHit.fromJson(row(1, group: null, inGroup: 1)).groupId, isNull);
  });

  test('searchResultsLocation encodes the query and drops defaults', () {
    expect(searchResultsLocation('tai nghe sony'), '/search/results?q=tai+nghe+sony');
    expect(searchResultsLocation('a&b', merchant: 'shopee', sort: 'cashback_desc'), '/search/results?q=a%26b&m=shopee&sort=cashback_desc');
  });

  group('RecentSearchStore', () {
    late RecentSearchStore store;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = RecentSearchStore(await SharedPreferences.getInstance());
    });

    test('newest first, case-insensitive dedupe, blank ignored', () async {
      await store.add('iphone');
      await store.add('Tai nghe');
      expect(await store.add('IPHONE'), ['IPHONE', 'Tai nghe']);
      expect(await store.add('   '), ['IPHONE', 'Tai nghe']);
    });

    test('keeps at most 10 and supports remove/clear', () async {
      for (var i = 0; i < 14; i++) {
        await store.add('q$i');
      }
      expect(store.read().length, 10);
      expect(store.read().first, 'q13');
      expect(await store.remove('q13'), isNot(contains('q13')));
      await store.clear();
      expect(store.read(), isEmpty);
    });
  });
}
