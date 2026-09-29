import 'package:canhgia_mobile/core/models/profile.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/features/rewards/application/rewards_providers.dart';
import 'package:canhgia_mobile/features/rewards/data/rewards_models.dart';
import 'package:canhgia_mobile/features/rewards/data/rewards_repository.dart';
import 'package:canhgia_mobile/features/rewards/presentation/rewards_screen.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_providers.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdrawal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements RewardsRepository {}

final _now = DateTime.utc(2026, 10, 2, 5); // Fri 12:00 VN
final _monday = DateTime.utc(2026, 9, 28);

const _tiers = [
  VipTier(code: 'dong', name: 'Đồng', minGmvVnd: 0, bonusBps: 0),
  VipTier(code: 'bac', name: 'Bạc', minGmvVnd: 2000000, bonusBps: 500),
  VipTier(code: 'vang', name: 'Vàng', minGmvVnd: 10000000, bonusBps: 1000),
];

Mission _mission(String code, String title, int p, int t, {bool claimed = false, String kind = 'orders_in_week', String rk = 'vnd', int amount = 10000}) =>
    Mission(code: code, title: title, progress: p, target: t, rewardKind: rk, rewardAmount: amount, claimed: claimed, kind: kind);

Widget _app(_MockRepo repo, {List<Checkin>? checkins, List<Mission>? missions}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        rewardsRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => const Profile(id: 'u', referralCode: 'ABCD1234', vipTierCode: 'bac', coinBalance: 2350)),
        vipTiersProvider.overrideWith((ref) async => _tiers),
        gmv12mProvider.overrideWith((ref) async => 3000000),
        checkinsThisWeekProvider.overrideWith((ref) async => checkins ?? const []),
        missionsProvider.overrideWith((ref) async => missions ?? const []),
        referralStatsProvider.overrideWith((ref) async => const ReferralStats(invited: 3, bonusVnd: 60000)),
        publicSettingsProvider.overrideWith((ref) async => const PublicSettings()),
      ],
      child: MaterialApp(home: RewardsScreen(now: _now)),
    );

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('coins, tier progress, ladder and referral card', (t) async {
    _tall(t);
    await t.pumpWidget(_app(_MockRepo()));
    await t.pumpAndSettle();
    expect(find.text('2.350 xu'), findsOneWidget);
    expect(find.text('★ HẠNG BẠC'), findsOneWidget);
    expect(find.text('Còn 7.000.000đ để lên Vàng'), findsOneWidget);
    expect(find.text('+10%'), findsOneWidget); // ladder, "hoa hồng" implied
    expect(find.text('Mời bạn, nhận đến 30.000đ'), findsOneWidget);
    expect(find.text('ABCD1234'), findsOneWidget);
    expect(find.text('Đã mời 3 bạn · Thưởng nhận được 60.000đ'), findsOneWidget);
  });

  testWidgets('check-in: button shows the reward, tap calls daily_checkin and refreshes', (t) async {
    _tall(t);
    final repo = _MockRepo();
    when(() => repo.checkin()).thenAnswer((_) async => (coins: 50, streak: 1));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    expect(find.text('Chuỗi 0 ngày'), findsOneWidget);
    await t.tap(find.text('Điểm danh nhận 50 xu'));
    await t.pumpAndSettle();
    verify(() => repo.checkin()).called(1);
    expect(find.textContaining('+50 xu · chuỗi 1 ngày'), findsOneWidget);
  });

  testWidgets('already checked in today: button disabled', (t) async {
    _tall(t);
    final rows = [for (var i = 0; i < 5; i++) Checkin(day: _monday.add(Duration(days: i)), coins: 50, streak: i + 1)];
    await t.pumpWidget(_app(_MockRepo(), checkins: rows));
    await t.pumpAndSettle();
    expect(find.text('Chuỗi 5 ngày'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.ancestor(of: find.text('Hôm nay bạn đã điểm danh'), matching: find.byType(FilledButton)));
    expect(btn.onPressed, isNull);
  });

  testWidgets('a failing check-in surfaces the mapped error and re-enables the button', (t) async {
    _tall(t);
    final repo = _MockRepo();
    when(() => repo.checkin()).thenThrow(Exception('boom'));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Điểm danh nhận 50 xu'));
    await t.pumpAndSettle();
    expect(find.text('Đã có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.ancestor(of: find.text('Điểm danh nhận 50 xu'), matching: find.byType(FilledButton)));
    expect(btn.onPressed, isNotNull);
  });

  testWidgets('missions: claim only when complete; invite mission is display-only', (t) async {
    _tall(t);
    final repo = _MockRepo();
    when(() => repo.claim('orders_2')).thenAnswer((_) async => 10000);
    await t.pumpWidget(_app(repo, missions: [
      _mission('orders_2', 'Mua 2 đơn trong tuần', 2, 2),
      _mission('share_1', 'Chia sẻ 1 link hoàn tiền', 0, 1, kind: 'share_link', rk: 'coins', amount: 200),
      _mission('invite_1', 'Mời 1 bạn đăng ký', 1, 1, kind: 'invite_signup', amount: 30000),
    ]));
    await t.pumpAndSettle();
    expect(find.text('+200 xu'), findsOneWidget);
    expect(find.text('+30.000đ'), findsOneWidget); // invite: chip, never a claim button
    expect(find.text('Nhận +10.000đ'), findsOneWidget);
    await t.tap(find.text('Nhận +10.000đ'));
    await t.pumpAndSettle();
    verify(() => repo.claim('orders_2')).called(1);
    verifyNever(() => repo.claim('invite_1'));
    expect(find.text('Đã nhận thưởng +10.000đ'), findsOneWidget);
  });
}
