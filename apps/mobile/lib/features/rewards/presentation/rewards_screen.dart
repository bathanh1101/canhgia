import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../withdraw/application/withdraw_providers.dart';
import '../../withdraw/data/withdrawal.dart';
import '../application/rewards_logic.dart';
import '../application/rewards_providers.dart';
import 'widgets/checkin_strip.dart';
import 'widgets/mission_tile.dart';
import 'widgets/referral_card.dart';
import 'widgets/tier_card.dart';

/// Screen 06 - tier, weekly check-in, missions and referral (tab "Mời bạn").
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  var _busy = false;

  /// Runs [action] once at a time; refreshes coin/mission/check-in data after it and shows errors.
  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final msg = await action();
      if (mounted) {
        ref
          ..invalidate(profileProvider)
          ..invalidate(checkinsThisWeekProvider)
          ..invalidate(missionsProvider);
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _load<T>(AsyncValue<T> v, Widget Function(T) data, VoidCallback retry) => v.when(
        skipLoadingOnRefresh: true,
        data: data,
        loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => AppCard(
          child: Column(children: [
            Text(mapErrorMessage(e), textAlign: TextAlign.center),
            AppButton(label: 'Thử lại', kind: AppButtonKind.outline, expand: false, onPressed: retry),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(rewardsRepositoryProvider);
    final profile = ref.watch(profileProvider).value;
    final today = vnToday(widget.now);
    final settings = ref.watch(publicSettingsProvider).value ?? const PublicSettings();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phần thưởng'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(999)),
              child: Text('${formatVnd(profile?.coinBalance ?? 0).replaceAll('đ', '')} xu', style: AppText.label.copyWith(color: AppColors.text)),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _load(
          ref.watch(vipTiersProvider),
          (tiers) {
            final gmv = ref.watch(gmv12mProvider).value ?? 0;
            final p = tierProgress(tiers, profile?.vipTierCode, gmv);
            return p == null ? const SizedBox.shrink() : TierCard(tiers: tiers, progress: p);
          },
          () => ref.invalidate(vipTiersProvider),
        ),
        const SizedBox(height: 12),
        _load(
          ref.watch(checkinsThisWeekProvider),
          (rows) {
            final streak = currentStreak(rows, today);
            final done = checkedInToday(rows, today);
            return CheckinStrip(
              cells: buildCheckinWeek(rows, today),
              streak: streak,
              checkedToday: done,
              todayCoins: checkinCoinsForStreak(streak + 1),
              busy: _busy,
              onCheckin: () => _run(() async {
                final r = await repo.checkin();
                return 'Điểm danh thành công +${r.coins} xu · chuỗi ${r.streak} ngày';
              }),
            );
          },
          () => ref.invalidate(checkinsThisWeekProvider),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Nhiệm vụ tuần'),
        const SizedBox(height: 8),
        _load(
          ref.watch(missionsProvider),
          (list) => AppCard(
            child: Column(children: [
              for (final m in list)
                MissionTile(
                  mission: m,
                  claiming: _busy,
                  onClaim: () => _run(() async {
                    await repo.claim(m.code);
                    return 'Đã nhận thưởng ${rewardLabel(m)}';
                  }),
                ),
            ]),
          ),
          () => ref.invalidate(missionsProvider),
        ),
        const SizedBox(height: 20),
        _load(
          ref.watch(referralStatsProvider),
          (stats) => ReferralCard(code: profile?.referralCode ?? '', stats: stats, bonusVnd: settings.referralBonusVnd),
          () => ref.invalidate(referralStatsProvider),
        ),
      ]),
    );
  }
}
