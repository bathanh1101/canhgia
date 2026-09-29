import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLinks extends Mock implements LinkRepository {}

CreatedLink _link({int hours = 24, DateTime? at}) => CreatedLink.fromJson(
      {'click_id': 5, 'aff_link': 'https://go.example/a', 'merchant_id': 'shopee', 'activation_hours': hours},
      now: at ?? DateTime(2026, 9, 29, 10),
    );

void main() {
  test('activationRemaining counts down from creation and never goes negative', () {
    final l = _link(hours: 2);
    expect(activationRemaining(l, DateTime(2026, 9, 29, 10)), const Duration(hours: 2));
    expect(activationRemaining(l, DateTime(2026, 9, 29, 11, 30)), const Duration(minutes: 30));
    expect(activationRemaining(l, DateTime(2026, 9, 29, 13)), Duration.zero);
  });

  test('formatCountdown', () {
    expect(formatCountdown(const Duration(hours: 23, minutes: 59, seconds: 7)), '23:59:07');
    expect(formatCountdown(const Duration(hours: 48, minutes: 5)), '2 ngày 00:05:00');
    expect(formatCountdown(Duration.zero), '00:00:00');
  });

  test('safeExternalUri only lets http(s) with a host through', () {
    expect(safeExternalUri('https://shopee.vn/x')?.host, 'shopee.vn');
    for (final bad in ['javascript:alert(1)', 'intent://x#Intent;end', 'file:///etc/passwd', 'https://', '', 'shopee.vn']) {
      expect(safeExternalUri(bad), isNull, reason: bad);
    }
  });

  group('CreateLinkController', () {
    late _MockLinks repo;
    late ProviderContainer c;
    setUp(() {
      repo = _MockLinks();
      c = ProviderContainer(retry: (_, _) => null, overrides: [
        linkRepositoryProvider.overrideWithValue(repo),
        deviceIdProvider.overrideWithValue('dev-9'),
      ]);
      addTearDown(c.dispose);
    });

    test('returns the link enriched with product context and sends the device id', () async {
      when(() => repo.create(merchantId: 'shopee', deviceId: 'dev-9', url: 'u')).thenAnswer((_) async => _link());
      final l = await c.read(createLinkControllerProvider.notifier).create(merchantId: 'shopee', url: 'u', name: 'Tai nghe', priceVnd: 100);
      expect(l!.productName, 'Tai nghe');
      expect(l.productPriceVnd, 100);
      expect(c.read(createLinkControllerProvider).value, l);
    });

    test('failure -> null and the failure code is kept in state', () async {
      when(() => repo.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url')))
          .thenThrow(const AppFailure('account_locked'));
      final l = await c.read(createLinkControllerProvider.notifier).create(merchantId: 'shopee');
      expect(l, isNull);
      expect(mapErrorMessage(c.read(createLinkControllerProvider).error!), errorMessagesVi['account_locked']);
    });

    test('a second tap while in flight is ignored', () async {
      when(() => repo.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url')))
          .thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return _link();
      });
      final n = c.read(createLinkControllerProvider.notifier);
      final first = n.create(merchantId: 'shopee');
      final second = await n.create(merchantId: 'shopee');
      expect(second, isNull);
      expect(await first, isNotNull);
      verify(() => repo.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url'))).called(1);
    });
  });
}
