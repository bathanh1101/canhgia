/// Row of `vip_tiers`.
class VipTier {
  const VipTier({required this.code, required this.name, required this.minGmvVnd, required this.bonusBps});

  static const columns = 'code,name,min_gmv_12m_vnd,bonus_bps';

  final String code;
  final String name;
  final int minGmvVnd;

  /// Share of the COMMISSION added for this tier (500 = +5% hoa hồng).
  final int bonusBps;

  factory VipTier.fromJson(Map<String, dynamic> j) => VipTier(
        code: j['code'] as String,
        name: (j['name'] as String?) ?? (j['code'] as String),
        minGmvVnd: (j['min_gmv_12m_vnd'] as num?)?.toInt() ?? 0,
        bonusBps: (j['bonus_bps'] as num?)?.toInt() ?? 0,
      );

  /// "+5% hoa hồng" (bps / 100, no trailing ".0").
  String get bonusLabel {
    final pct = bonusBps / 100;
    return '+${pct == pct.roundToDouble() ? pct.round() : pct}% hoa hồng';
  }
}

/// Row of `daily_checkins`.
class Checkin {
  const Checkin({required this.day, required this.coins, required this.streak});

  static const columns = 'day,coins,streak';

  /// Date-only (Vietnam calendar day) as a UTC midnight [DateTime].
  final DateTime day;
  final int coins;
  final int streak;

  factory Checkin.fromJson(Map<String, dynamic> j) {
    final d = DateTime.parse(j['day'] as String);
    return Checkin(day: DateTime.utc(d.year, d.month, d.day), coins: (j['coins'] as num).toInt(), streak: (j['streak'] as num).toInt());
  }
}

/// `get_mission_progress()` row joined with `missions.kind`.
class Mission {
  const Mission({
    required this.code,
    required this.title,
    required this.progress,
    required this.target,
    required this.rewardKind,
    required this.rewardAmount,
    required this.claimed,
    required this.kind,
  });

  final String code;
  final String title;
  final int progress;
  final int target;
  final String rewardKind; // vnd | coins
  final int rewardAmount;
  final bool claimed;
  final String kind; // orders_in_week | share_link | invite_signup

  factory Mission.fromJson(Map<String, dynamic> j, String kind) => Mission(
        code: j['code'] as String,
        title: j['title'] as String,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        target: (j['target'] as num?)?.toInt() ?? 1,
        rewardKind: (j['reward_kind'] as String?) ?? 'coins',
        rewardAmount: (j['reward_amount'] as num?)?.toInt() ?? 0,
        claimed: j['claimed'] as bool? ?? false,
        kind: kind,
      );

  /// invite_signup is paid once through the referral bonus, never claimed here.
  bool get displayOnly => kind == 'invite_signup';
  bool get claimable => !displayOnly && !claimed && progress >= target;
  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();
}

class ReferralStats {
  const ReferralStats({this.invited = 0, this.bonusVnd = 0});
  final int invited;
  final int bonusVnd;
}
