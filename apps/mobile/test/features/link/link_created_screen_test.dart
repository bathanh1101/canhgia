import 'package:canhgia_mobile/features/home/data/link_models.dart';
import 'package:canhgia_mobile/features/home/data/link_repository.dart';
import 'package:canhgia_mobile/features/link/application/link_providers.dart';
import 'package:canhgia_mobile/features/link/presentation/link_created_screen.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../search/test_support.dart';

class _MockLinks extends Mock implements LinkRepository {}

CreatedLink _link({Map<String, dynamic>? estimate = const {'base_rate_bps': 600, 'vip_rate_bps': 100, 'cashback_vnd': 454300}, String aff = 'https://go.example/aff'}) =>
    CreatedLink.fromJson({
      'click_id': 42,
      'aff_link': aff,
      'short_link': 'https://s.example/abc',
      'merchant_id': 'shopee',
      'activation_hours': 24,
      'estimate': estimate,
    }).withProduct(name: 'Tai nghe Sony', priceVnd: 6490000);

void main() {
  late _MockLinks links;
  late List<Uri> launched;
  late List<String> shared, copied;
  var launchOk = true;

  Widget app(CreatedLink? link) => plainApp(LinkCreatedScreen(link: link), overrides: [
        linkRepositoryProvider.overrideWithValue(links),
        merchantsProvider.overrideWith((_) async => [shopee]),
        profileProvider.overrideWith((_) async => null),
        merchantHoldDaysProvider.overrideWith((_) async => {'shopee': 30}),
        externalLauncherProvider.overrideWithValue((u) async {
          launched.add(u);
          return launchOk;
        }),
        shareTextProvider.overrideWithValue((s) async => shared.add(s)),
        clipboardWriterProvider.overrideWithValue((s) async => copied.add(s)),
      ]);

  setUp(() {
    links = _MockLinks();
    launched = [];
    shared = [];
    copied = [];
    launchOk = true;
    when(() => links.recordShare(any())).thenAnswer((_) async {});
  });

  testWidgets('shows product, estimate, payout + activation copy and countdown', (t) async {
    await t.pumpWidget(app(_link()));
    await t.pumpAndSettle();
    expect(find.text('Tai nghe Sony'), findsOneWidget);
    expect(find.text('454.300đ'), findsOneWidget);
    expect(find.text('6% + 1%'), findsOneWidget);
    expect(find.text('Về ví sau khi sàn đối soát + 30 ngày chờ'), findsOneWidget);
    expect(find.textContaining('Mua trong 24 giờ'), findsOneWidget);
    expect(find.textContaining('Còn 23:59:'), findsOneWidget);
    await t.pumpWidget(const SizedBox()); // dispose countdown timer
  });

  testWidgets('null estimate does not break the screen', (t) async {
    await t.pumpWidget(app(_link(estimate: null)));
    await t.pumpAndSettle();
    expect(find.textContaining('Chưa có mức hoàn tiền'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('Mua ngay opens aff_link externally; falls back to the short link when it cannot open', (t) async {
    await t.pumpWidget(app(_link()));
    await t.pumpAndSettle();
    await t.tap(find.text('Mở Shopee & mua ngay'));
    await t.pumpAndSettle();
    expect(launched.single.toString(), 'https://go.example/aff');
    launched.clear();
    launchOk = false;
    await t.tap(find.text('Mở Shopee & mua ngay'));
    await t.pumpAndSettle();
    expect(launched.map((u) => u.toString()), ['https://go.example/aff', 'https://s.example/abc']);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('non-http aff_link is never launched', (t) async {
    await t.pumpWidget(app(_link(aff: 'intent://evil#Intent;end')));
    await t.pumpAndSettle();
    await t.tap(find.text('Mở Shopee & mua ngay'));
    await t.pumpAndSettle();
    expect(launched, isEmpty);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('copy puts the short link on the clipboard; share records the mission share', (t) async {
    await t.pumpWidget(app(_link()));
    await t.pumpAndSettle();
    await t.tap(find.text('Sao chép'));
    await t.pump();
    expect(copied, ['https://s.example/abc']);
    await t.tap(find.text('Chia sẻ'));
    await t.pumpAndSettle();
    expect(shared, ['https://s.example/abc']);
    verify(() => links.recordShare('42')).called(1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('route restored without extra shows a way back instead of crashing', (t) async {
    await t.pumpWidget(app(null));
    expect(find.textContaining('Phiên tạo link đã hết'), findsOneWidget);
    expect(find.text('Về trang chủ'), findsOneWidget);
  });
}
