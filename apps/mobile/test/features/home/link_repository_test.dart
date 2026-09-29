import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../search/test_support.dart';

void main() {
  late MockSupabaseClient db;
  late MockFunctionsClient fn;
  late LinkRepository repo;

  setUp(() {
    db = MockSupabaseClient();
    fn = MockFunctionsClient();
    when(() => db.functions).thenReturn(fn);
    repo = LinkRepository(db);
  });

  test('resolve sends the trimmed url and parses offer + estimate', () async {
    when(() => fn.invoke('resolve-url', body: any(named: 'body'))).thenAnswer((_) async => FunctionResponse(status: 200, data: {
          'merchant_id': 'shopee',
          'resolved_url': 'https://shopee.vn/p',
          'datafeed_enabled': true,
          'offer': {'name': 'Tai nghe', 'price_vnd': 6490000, 'product_group_id': 7, 'cashback_eligible': true, 'image': null},
          'estimate': {'base_rate_bps': 600, 'vip_rate_bps': 100, 'cashback_vnd': 454300},
        }));
    final r = await repo.resolve('  https://shopee.vn/p  ');
    expect(verify(() => fn.invoke('resolve-url', body: captureAny(named: 'body'))).captured.single, {'url': 'https://shopee.vn/p'});
    expect(r.merchantId, 'shopee');
    expect(r.canCompare, isTrue);
    expect(r.estimate!.label('Vàng'), '6% + 1% hạng Vàng');
    expect(r.estimate!.cashbackVnd, 454300);
  });

  test('resolve tolerates null estimate/offer and blocks compare without datafeed', () {
    final r = ResolvedUrl.fromJson({'merchant_id': 'traveloka', 'datafeed_enabled': false, 'estimate': null});
    expect(r.estimate, isNull);
    expect(r.offer, isNull);
    expect(r.canCompare, isFalse);
    final noGroup = ResolvedUrl.fromJson({
      'merchant_id': 'shopee',
      'datafeed_enabled': true,
      'offer': {'name': 'x', 'price_vnd': 1},
    });
    expect(noGroup.canCompare, isFalse);
  });

  test('malformed responses raise a mapped failure instead of a cast error', () {
    expect(() => ResolvedUrl.fromJson('nope'), throwsA(isA<AppFailure>()));
    expect(() => ResolvedUrl.fromJson({'resolved_url': 'x'}), throwsA(isA<AppFailure>()));
    expect(() => CreatedLink.fromJson({'click_id': 1}), throwsA(isA<AppFailure>()));
    expect(() => CreatedLink.fromJson({'click_id': 1, 'aff_link': ''}), throwsA(isA<AppFailure>()));
  });

  test('create posts source app + device id, omits url for travel merchants', () async {
    when(() => fn.invoke('create-link', body: any(named: 'body'))).thenAnswer((_) async => FunctionResponse(status: 200, data: {
          'click_id': 42,
          'aff_link': 'https://go.example/a',
          'short_link': 'https://s.example/x',
          'merchant_id': 'traveloka',
          'activation_hours': 24,
          'estimate': null,
        }));
    final link = await repo.create(merchantId: 'traveloka', deviceId: 'dev1');
    expect(verify(() => fn.invoke('create-link', body: captureAny(named: 'body'))).captured.single,
        {'merchant_id': 'traveloka', 'source': 'app', 'device_id': 'dev1'});
    expect(link.clickId, '42');
    expect(link.shareUrl, 'https://s.example/x');
    expect(link.estimate, isNull);
    await repo.create(merchantId: 'shopee', deviceId: 'dev1', url: 'https://shopee.vn/p');
    expect(verify(() => fn.invoke('create-link', body: captureAny(named: 'body'))).captured.last['url'], 'https://shopee.vn/p');
  });

  test('edge error codes map to Vietnamese messages', () async {
    when(() => fn.invoke('create-link', body: any(named: 'body')))
        .thenThrow(FunctionException(status: 422, details: {'error': 'merchant_unavailable'}));
    await expectLater(
      repo.create(merchantId: 'x', deviceId: 'd'),
      throwsA(predicate((Object e) => mapErrorMessage(e) == errorMessagesVi['merchant_unavailable'])),
    );
  });

  test('recordShare calls the RPC with a numeric click id and ignores garbage ids', () async {
    when(() => db.rpc<dynamic>('record_link_share', params: any(named: 'params'))).thenAnswer((_) => FakeBuilder<dynamic>(null));
    await repo.recordShare('42');
    verify(() => db.rpc<dynamic>('record_link_share', params: {'p_click_id': 42})).called(1);
    await repo.recordShare('abc');
    verifyNever(() => db.rpc<dynamic>('record_link_share', params: {'p_click_id': 0}));
  });

  test('formatBps', () {
    expect(formatBps(600), '6%');
    expect(formatBps(650), '6,5%');
    expect(formatBps(1250), '12,5%');
  });
}
