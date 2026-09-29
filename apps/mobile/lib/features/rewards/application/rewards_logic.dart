import '../data/rewards_models.dart';

/// Server day = Vietnam calendar day (UTC+7); returned as UTC-midnight date.
DateTime vnToday([DateTime? now]) {
  final v = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 7));
  return DateTime.utc(v.year, v.month, v.day);
}

DateTime weekStart(DateTime day) => day.subtract(Duration(days: day.weekday - DateTime.monday));

/// Mirrors `daily_checkin()` for display only: 500 xu on every 7th day of the streak, else 50.
int checkinCoinsForStreak(int streak) => streak > 0 && streak % 7 == 0 ? 500 : 50;

/// Streak counting today if already checked in, else up to yesterday, else 0.
int currentStreak(List<Checkin> rows, DateTime today) {
  Checkin? at(DateTime d) => rows.where((r) => r.day == d).firstOrNull;
  return at(today)?.streak ?? at(today.subtract(const Duration(days: 1)))?.streak ?? 0;
}

bool checkedInToday(List<Checkin> rows, DateTime today) => rows.any((r) => r.day == today);

enum CheckinCellState { done, today, upcoming, missed }

class CheckinCell {
  const CheckinCell(this.label, this.state, this.coins);
  final String label;
  final CheckinCellState state;
  final int coins;
}

const _labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// Monday..Sunday strip for the week containing [today].
List<CheckinCell> buildCheckinWeek(List<Checkin> rows, DateTime today) {
  final monday = weekStart(today);
  final done = checkedInToday(rows, today);
  final streak = currentStreak(rows, today);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final d = monday.add(Duration(days: i));
        final row = rows.where((r) => r.day == d).firstOrNull;
        if (row != null) return CheckinCell(_labels[i], CheckinCellState.done, row.coins);
        final ahead = d.difference(today).inDays; // <0 past, 0 today, >0 future
        final next = checkinCoinsForStreak(streak + (done ? 0 : 1) + (ahead > 0 ? ahead : 0));
        if (ahead < 0) return CheckinCell(_labels[i], CheckinCellState.missed, 0);
        return CheckinCell(_labels[i], ahead == 0 ? CheckinCellState.today : CheckinCellState.upcoming, next);
      }(),
  ];
}

class TierProgress {
  const TierProgress({required this.current, required this.next, required this.remainingVnd, required this.fraction});
  final VipTier current;
  final VipTier? next;
  final int remainingVnd;
  final double fraction;
}

/// Progress from [currentCode] toward the next tier given the trailing-12-month GMV.
TierProgress? tierProgress(List<VipTier> tiers, String? currentCode, int gmvVnd) {
  if (tiers.isEmpty) return null;
  final sorted = [...tiers]..sort((a, b) => a.minGmvVnd.compareTo(b.minGmvVnd));
  final cur = sorted.where((t) => t.code == currentCode).firstOrNull ?? sorted.first;
  final next = sorted.where((t) => t.minGmvVnd > cur.minGmvVnd).firstOrNull;
  if (next == null) return TierProgress(current: cur, next: null, remainingVnd: 0, fraction: 1);
  final span = next.minGmvVnd - cur.minGmvVnd;
  return TierProgress(
    current: cur,
    next: next,
    remainingVnd: (next.minGmvVnd - gmvVnd).clamp(0, next.minGmvVnd),
    fraction: span <= 0 ? 1 : ((gmvVnd - cur.minGmvVnd) / span).clamp(0, 1).toDouble(),
  );
}
