import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/models/profile.dart';
import 'package:canhgia_mobile/core/models/wallet.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/core/providers/unread_notifications_provider.dart';
import 'package:canhgia_mobile/core/providers/wallet_provider.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/core/supabase/realtime_service.dart';
import 'package:canhgia_mobile/features/home/application/home_providers.dart';
import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/home/presentation/home_screen.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:canhgia_mobile/features/vouchers/application/voucher_providers.dart';
import 'package:canhgia_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockLinks extends Mock implements LinkRepository {}

ResolvedUrl _resolved({bool datafeed = true, int? group = 7, String merchant = 'shopee'}) => ResolvedUrl.fromJson({
      'merchant_id': merchant,
      'resolved_url': 'https://shopee.vn/p/1',
      'datafeed_enabled': datafeed,
      'offer': {'name': 'Tai nghe Sony WH-1000XM5', 'price_vnd': 6490000, 'product_group_id': group},
      'estimate': {'base_rate_bps': 600, 'vip_rate_bps': 100, 'cashback_vnd': 454300},
    });

void main() {
  late _MockLinks links;
  String? clip;

  Widget app() => routerApp(const HomeScreen(), overrides: [
        profileProvider.overrideWith((_) async => const Profile(id: 'u', referralCode: 'R', displayName: 'Minh', vipTierCode: 'gold')),
        walletProvider.overrideWith((_) => Stream.value(const Wallet(availableVnd: 1250000, pendingVnd: 320000, heldVnd: 0, totalEarnedVnd: 0))),
        unreadNotificationsProvider.overrideWith((_) async => 3),
        merchantsProvider.overrideWith((_) async => [shopee, traveloka]),
        realtimeEventsProvider.overrideWith((_) => const Stream<RealtimeEvent>.empty()),
        homeVouchersProvider.overrideWith((_) async => [const Voucher(id: 1, merchantId: 'shopee', discountText: 'Giảm 15% tối đa 80K')]),
        currentUserIdProvider.overrideWithValue(null),
        linkRepositoryProvider.overrideWithValue(links),
        clipboardReaderProvider.overrideWithValue(() async => clip),
        deviceIdProvider.overrideWithValue('dev-1'),
      ]);

  setUp(() {
    links = _MockLinks();
    clip = null;
  });

  testWidgets('shows greeting, tier, balance, merchant grid (max rate) and today vouchers', (t) async {
    t.view.physicalSize = const Size(800, 2600); // ListView is lazy: make the whole page visible
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text('Xin chào, Minh 👋'), findsOneWidget);
    expect(find.text('★ Hạng Gold'), findsOneWidget);
    expect(find.text('1.250.000đ'), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // unread badge
    expect(find.text('đến 10%'), findsOneWidget); // Shopee only; Traveloka has no known rate
    expect(find.text('Traveloka'), findsOneWidget);
    expect(find.text('Giảm 15% tối đa 80K'), findsOneWidget);
    expect(find.textContaining('Phát hiện link'), findsNothing);
  });

  testWidgets('clipboard link -> card with compare CTA; "Tạo link" creates a link and opens the link screen', (t) async {
    clip = 'https://shopee.vn/p/1';
    when(() => links.resolve(any())).thenAnswer((_) async => _resolved());
    when(() => links.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url'))).thenAnswer(
      (_) async => CreatedLink.fromJson({'click_id': 9, 'aff_link': 'https://go.example/a', 'merchant_id': 'shopee', 'activation_hours': 24}),
    );
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text('Phát hiện link Shopee vừa sao chép'), findsOneWidget);
    expect(find.text('So sánh giá ›'), findsOneWidget);
    expect(find.textContaining('Hoàn 6% + 1%'), findsOneWidget);
    await t.tap(find.text('Tạo link hoàn tiền'));
    await t.pumpAndSettle();
    verify(() => links.create(merchantId: 'shopee', deviceId: 'dev-1', url: 'https://shopee.vn/p/1')).called(1);
    expect(find.text('LINK 9'), findsOneWidget);
  });

  testWidgets('non-datafeed link degrades: no compare CTA, muted note instead', (t) async {
    clip = 'https://shopee.vn/p/1';
    when(() => links.resolve(any())).thenAnswer((_) async => _resolved(datafeed: false));
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text('Chưa hỗ trợ so sánh'), findsOneWidget);
    expect(find.text('So sánh giá ›'), findsNothing);
    await t.tap(find.text('Bỏ qua'));
    await t.pumpAndSettle();
    expect(find.textContaining('Phát hiện link'), findsNothing);
  });

  testWidgets('create-link failure shows the mapped message and keeps the card', (t) async {
    clip = 'https://shopee.vn/p/1';
    when(() => links.resolve(any())).thenAnswer((_) async => _resolved());
    when(() => links.create(merchantId: any(named: 'merchantId'), deviceId: any(named: 'deviceId'), url: any(named: 'url')))
        .thenThrow(const AppFailure('rate_limited'));
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo link hoàn tiền'));
    await t.pumpAndSettle();
    expect(find.text(errorMessagesVi['rate_limited']!), findsOneWidget);
    expect(find.text('Phát hiện link Shopee vừa sao chép'), findsOneWidget);
  });

  testWidgets('paste field: unsupported link shows error; supported link shows the card', (t) async {
    when(() => links.resolve('https://foo.example/x')).thenThrow(const AppFailure('unsupported_url'));
    when(() => links.resolve('https://shopee.vn/p/1')).thenAnswer((_) async => _resolved());
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'https://foo.example/x');
    await t.tap(find.byIcon(Icons.arrow_forward));
    await t.pumpAndSettle();
    expect(find.text(errorMessagesVi['unsupported_url']!), findsOneWidget);
    await t.enterText(find.byType(TextField), 'https://shopee.vn/p/1');
    await t.tap(find.byIcon(Icons.arrow_forward));
    await t.pumpAndSettle();
    expect(find.text('Phát hiện link Shopee vừa sao chép'), findsOneWidget);
  });
}
