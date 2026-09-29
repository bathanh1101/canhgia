import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/rewards_models.dart';
import '../data/rewards_repository.dart';
import 'rewards_logic.dart';

final rewardsRepositoryProvider = Provider<RewardsRepository>((ref) => RewardsRepository(ref.watch(supabaseProvider)));

final vipTiersProvider = FutureProvider<List<VipTier>>((ref) => ref.watch(rewardsRepositoryProvider).tiers());

/// Rows from the day before this week's Monday (so a Monday still sees Sunday's streak).
final checkinsThisWeekProvider = FutureProvider.autoDispose<List<Checkin>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final since = weekStart(vnToday()).subtract(const Duration(days: 1));
  return ref.watch(rewardsRepositoryProvider).checkins(uid, since);
});

/// Mission progress depends on orders (weekly count) -> refetch on `orders` events.
final missionsProvider = FutureProvider.autoDispose<List<Mission>>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value?.kind == 'orders' || e.value?.kind == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(rewardsRepositoryProvider).missions();
});

final referralStatsProvider = FutureProvider.autoDispose<ReferralStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? const ReferralStats() : ref.watch(rewardsRepositoryProvider).referralStats(uid);
});

final gmv12mProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? 0 : ref.watch(rewardsRepositoryProvider).gmv12m(uid, DateTime.now());
});

/// Vietnamese message for `bind_referral` failures (`code_invalid` + detail.reason).
String bindReferralMessage(Object e) {
  final f = AppFailure.from(e);
  if (f.code != 'code_invalid') return f.message;
  return switch (f.detail['reason']) {
    'already_bound' => 'Bạn đã nhập mã giới thiệu trước đó.',
    'expired' => 'Chỉ nhập được mã giới thiệu trong 7 ngày đầu sau khi đăng ký.',
    'loop' => 'Không thể dùng mã của người bạn đã mời.',
    _ => 'Mã giới thiệu không hợp lệ.',
  };
}
