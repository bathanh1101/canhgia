import 'package:supabase_flutter/supabase_flutter.dart';

import 'rewards_models.dart';

class RewardsRepository {
  RewardsRepository(this._db);
  final SupabaseClient _db;

  Future<List<VipTier>> tiers() async {
    final rows = await _db.from('vip_tiers').select(VipTier.columns).order('min_gmv_12m_vnd');
    return [for (final r in rows) VipTier.fromJson(r)];
  }

  /// Rows from [since] (Vietnam date) onward.
  Future<List<Checkin>> checkins(String uid, DateTime since) async {
    final rows = await _db
        .from('daily_checkins')
        .select(Checkin.columns)
        .eq('user_id', uid)
        .gte('day', since.toIso8601String().substring(0, 10));
    return [for (final r in rows) Checkin.fromJson(r)];
  }

  /// Returns (coins earned, streak).
  Future<({int coins, int streak})> checkin() async {
    final rows = await _db.rpc('daily_checkin') as List;
    final r = rows.first as Map<String, dynamic>;
    return (coins: (r['coins'] as num).toInt(), streak: (r['streak'] as num).toInt());
  }

  Future<List<Mission>> missions() async {
    final res = await Future.wait<Object?>([_db.rpc('get_mission_progress'), _db.from('missions').select('code,kind')]);
    final kinds = {for (final m in res[1]! as List) (m as Map<String, dynamic>)['code'] as String: m['kind'] as String};
    return [
      for (final r in res[0]! as List)
        Mission.fromJson(r as Map<String, dynamic>, kinds[r['code']] ?? ''),
    ];
  }

  /// Reward amount paid (vnd or coins per mission).
  Future<int> claim(String code) async => ((await _db.rpc('claim_mission', params: {'p_code': code})) as num).toInt();

  Future<ReferralStats> referralStats(String uid) async {
    final rows = await _db.from('referrals').select('status,bonus_vnd').eq('referrer_id', uid);
    var bonus = 0;
    for (final r in rows) {
      if (r['status'] == 'rewarded' || r['status'] == 'held') bonus += (r['bonus_vnd'] as num?)?.toInt() ?? 0;
    }
    return ReferralStats(invited: rows.length, bonusVnd: bonus);
  }

  /// Estimated trailing-12-month credited GMV (same rule as `refresh_vip_tiers`); display only, the server tier is authoritative.
  Future<int> gmv12m(String uid, DateTime now) async {
    final since = DateTime(now.year - 1, now.month, now.day).toUtc().toIso8601String();
    final rows = await _db
        .from('orders')
        .select('value_vnd')
        .eq('user_id', uid)
        .eq('credit_state', 'credited')
        .or('order_time.gte.$since,and(order_time.is.null,created_at.gte.$since)') // coalesce(order_time, created_at)
        .limit(5000); // ponytail: heavier users are under-counted; move to a server RPC if that matters
    return rows.fold<int>(0, (s, r) => s + ((r['value_vnd'] as num?)?.toInt() ?? 0));
  }

  Future<void> bindReferral(String code) => _db.rpc('bind_referral', params: {'p_code': code});
}
