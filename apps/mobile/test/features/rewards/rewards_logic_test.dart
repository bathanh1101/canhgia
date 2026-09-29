import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/rewards/application/rewards_logic.dart';
import 'package:canhgia_mobile/features/rewards/application/rewards_providers.dart';
import 'package:canhgia_mobile/features/rewards/data/rewards_models.dart';
import 'package:canhgia_mobile/features/rewards/data/rewards_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wallet/fake_supabase.dart';

Checkin _c(DateTime day, int streak, [int coins = 50]) => Checkin(day: day, coins: coins, streak: streak);

const _tiers = [
  VipTier(code: 'dong', name: 'Đồng', minGmvVnd: 0, bonusBps: 0),
  VipTier(code: 'bac', name: 'Bạc', minGmvVnd: 2000000, bonusBps: 500),
  VipTier(code: 'vang', name: 'Vàng', minGmvVnd: 10000000, bonusBps: 1000),
  VipTier(code: 'kim_cuong', name: 'Kim Cương', minGmvVnd: 30000000, bonusBps: 2000),
];

void main() {
  // Fri 2026-10-02 (VN), week = Mon 09-28 .. Sun 10-04
  final today = DateTime.utc(2026, 10, 2);
  final monday = DateTime.utc(2026, 9, 28);

  test('vnToday uses UTC+7 (late evening UTC is already tomorrow in Vietnam)', () {
    expect(vnToday(DateTime.utc(2026, 10, 1, 17, 30)), DateTime.utc(2026, 10, 2));
    expect(vnToday(DateTime.utc(2026, 10, 1, 16, 59)), DateTime.utc(2026, 10, 1));
  });

  test('weekStart is Monday', () {
    expect(weekStart(today), monday);
    expect(weekStart(monday), monday);
    expect(weekStart(DateTime.utc(2026, 10, 4)), monday);
  });

  test('coins: 500 on every 7th streak day, else 50', () {
    expect([1, 6, 7, 8, 14, 15].map(checkinCoinsForStreak), [50, 50, 500, 50, 500, 50]);
    expect(checkinCoinsForStreak(0), 50);
  });

  group('currentStreak / checkedInToday', () {
    test('counts today when checked in', () {
      final rows = [_c(today.subtract(const Duration(days: 1)), 3), _c(today, 4)];
      expect(currentStreak(rows, today), 4);
      expect(checkedInToday(rows, today), isTrue);
    });
    test('falls back to yesterday, else 0 (streak broken)', () {
      expect(currentStreak([_c(today.subtract(const Duration(days: 1)), 3)], today), 3);
      expect(checkedInToday([_c(today.subtract(const Duration(days: 1)), 3)], today), isFalse);
      expect(currentStreak([_c(today.subtract(const Duration(days: 2)), 9)], today), 0);
      expect(currentStreak(const [], today), 0);
    });
  });

  group('buildCheckinWeek', () {
    test('Mon-Thu done, Fri is today (not yet), Sat/Sun upcoming', () {
      final rows = [for (var i = 0; i < 4; i++) _c(monday.add(Duration(days: i)), i + 1)];
      final w = buildCheckinWeek(rows, today);
      expect(w.map((c) => c.label), ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']);
      expect(w.map((c) => c.state), [
        CheckinCellState.done, CheckinCellState.done, CheckinCellState.done, CheckinCellState.done,
        CheckinCellState.today, CheckinCellState.upcoming, CheckinCellState.upcoming,
      ]);
      expect(w[4].coins, 50); // streak 5
      expect(w[5].coins, 50); // streak 6
      expect(w[6].coins, 500); // streak 7
    });

    test('a skipped day is "missed"; after checking in today the cell turns done', () {
      final rows = [_c(monday, 1), _c(today, 1)];
      final w = buildCheckinWeek(rows, today);
      expect(w[1].state, CheckinCellState.missed);
      expect(w[4].state, CheckinCellState.done);
      expect(w[5].coins, 50);
    });
  });

  group('tierProgress', () {
    test('mid ladder', () {
      final p = tierProgress(_tiers, 'vang', 27200000)!;
      expect(p.current.code, 'vang');
      expect(p.next!.code, 'kim_cuong');
      expect(p.remainingVnd, 2800000);
      expect(p.fraction, closeTo(0.86, 0.001));
    });
    test('top tier has no next; unknown code falls to the lowest', () {
      final top = tierProgress(_tiers, 'kim_cuong', 99000000)!;
      expect((top.next, top.fraction, top.remainingVnd), (null, 1.0, 0));
      expect(tierProgress(_tiers, null, 0)!.current.code, 'dong');
      expect(tierProgress(const [], 'x', 0), isNull);
    });
    test('gmv below the current tier floor clamps to 0', () {
      expect(tierProgress(_tiers, 'bac', 1000)!.fraction, 0);
    });
  });

  test('VipTier bonus label is bps as a percent of commission', () {
    expect(_tiers.map((t) => t.bonusLabel), ['+0% hoa hồng', '+5% hoa hồng', '+10% hoa hồng', '+20% hoa hồng']);
    expect(const VipTier(code: 'x', name: 'x', minGmvVnd: 0, bonusBps: 250).bonusLabel, '+2.5% hoa hồng');
  });

  group('Mission', () {
    Mission m({int progress = 2, int target = 2, bool claimed = false, String kind = 'orders_in_week'}) => Mission.fromJson({
          'code': 'orders_2', 'title': 'Mua 2 đơn', 'progress': progress, 'target': target, 'reward_kind': 'vnd', 'reward_amount': 10000, 'claimed': claimed,
        }, kind);
    test('claimable only when complete, unclaimed and not invite_signup', () {
      expect(m().claimable, isTrue);
      expect(m(progress: 1).claimable, isFalse);
      expect(m(claimed: true).claimable, isFalse);
      expect(m(kind: 'invite_signup').claimable, isFalse);
      expect(m(kind: 'invite_signup').displayOnly, isTrue);
    });
    test('fraction is clamped', () {
      expect(m(progress: 1).fraction, 0.5);
      expect(m(progress: 5).fraction, 1);
    });
  });

  group('RewardsRepository via RPC', () {
    test('checkin returns coins and streak', () async {
      final db = MockSupabase();
      stubRpc(db, 'daily_checkin', [
        {'coins': 500, 'streak': 7}
      ]);
      expect(await RewardsRepository(db).checkin(), (coins: 500, streak: 7));
    });

    test('claim returns the reward and sends the code', () async {
      final db = MockSupabase();
      stubRpc(db, 'claim_mission', 10000);
      expect(await RewardsRepository(db).claim('orders_2'), 10000);
      expect(lastRpcParams(db, 'claim_mission'), {'p_code': 'orders_2'});
    });

    test('bindReferral sends p_code', () async {
      final db = MockSupabase();
      stubRpc(db, 'bind_referral', null);
      await RewardsRepository(db).bindReferral('ABCD1234');
      expect(lastRpcParams(db, 'bind_referral'), {'p_code': 'ABCD1234'});
    });
  });

  test('bindReferralMessage maps code_invalid reasons', () {
    String msg(Map<String, dynamic> d) => bindReferralMessage(AppFailure('code_invalid', detail: d));
    expect(msg({'reason': 'already_bound'}), contains('đã nhập'));
    expect(msg({'reason': 'expired'}), contains('7 ngày'));
    expect(msg({'reason': 'loop'}), contains('đã mời'));
    expect(msg({}), 'Mã giới thiệu không hợp lệ.');
    expect(bindReferralMessage(const AppFailure('rate_limited')), errorMessagesVi['rate_limited']);
  });
}
