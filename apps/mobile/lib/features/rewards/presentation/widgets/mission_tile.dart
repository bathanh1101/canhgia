import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../data/rewards_models.dart';

String rewardLabel(Mission m) =>
    m.rewardKind == 'vnd' ? '+${formatVnd(m.rewardAmount)}' : '+${formatVnd(m.rewardAmount).replaceAll('đ', '')} xu';

/// Weekly mission row: title, progress bar, reward chip / claim button.
class MissionTile extends StatelessWidget {
  const MissionTile({super.key, required this.mission, required this.onClaim, this.claiming = false});

  final Mission mission;
  final VoidCallback onClaim;
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.title, style: AppText.title.copyWith(fontSize: 15)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: m.fraction, minHeight: 6, backgroundColor: AppColors.border, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Text('${m.progress}/${m.target}', style: AppText.caption),
            ]),
            if (m.displayOnly) Text('Thưởng được cộng khi bạn bè hoàn thành đơn đầu tiên.', style: AppText.caption),
          ]),
        ),
        const SizedBox(width: 12),
        if (m.claimable)
          FilledButton(
            onPressed: claiming ? null : onClaim,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text('Nhận ${rewardLabel(m)}'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primaryTintStrong, borderRadius: BorderRadius.circular(999)),
            child: Text(
              m.claimed ? 'Đã nhận' : rewardLabel(m),
              style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
      ]),
    );
  }
}
