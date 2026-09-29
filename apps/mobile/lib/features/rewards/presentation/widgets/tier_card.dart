import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../application/rewards_logic.dart';
import '../../data/rewards_models.dart';

/// VIP tier: current tier, progress toward the next, and the tier ladder.
class TierCard extends StatelessWidget {
  const TierCard({super.key, required this.tiers, required this.progress});

  final List<VipTier> tiers;
  final TierProgress progress;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.warning, AppColors.warningTint]),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('★ HẠNG ${progress.current.name.toUpperCase()}', style: AppText.title.copyWith(fontSize: 14)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999)),
            child: Text(progress.current.bonusLabel, style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          next == null ? 'Bạn đang ở hạng cao nhất' : 'Còn ước tính ${formatVnd(progress.remainingVnd)} để lên ${next.name}',
          style: AppText.h2.copyWith(fontSize: 17),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 10,
            backgroundColor: AppColors.surface,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          for (final t in tiers)
            Expanded(
              child: Column(children: [
                Text(
                  t.name,
                  style: AppText.caption.copyWith(
                    color: AppColors.text,
                    fontWeight: t.code == progress.current.code ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                Text(t.bonusLabel.replaceAll(' hoa hồng', ''), style: AppText.caption.copyWith(fontSize: 11)),
              ]),
            ),
        ]),
      ]),
    );
  }
}
