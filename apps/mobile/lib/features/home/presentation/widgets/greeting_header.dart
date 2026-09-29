import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/profile.dart';

/// Greeting + tier, bell with unread badge, and the search entry (opens /search).
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.profile, required this.unread});

  final Profile? profile;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final tier = profile?.vipTierCode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Xin chào, ${profile?.shownName ?? 'bạn'} 👋', style: AppText.h2),
            if (tier != null && tier.isNotEmpty)
              Text('★ Hạng ${tier[0].toUpperCase()}${tier.substring(1)}',
                  style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(
          tooltip: 'Thông báo',
          onPressed: () => context.push(RoutePaths.notifications),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 99 ? '99+' : '$unread'),
            child: const Icon(Icons.notifications_none),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(RoutePaths.search),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            const Icon(Icons.search, color: AppColors.textMuted),
            const SizedBox(width: 8),
            Text('Tìm sản phẩm, so sánh giá…', style: AppText.body.copyWith(color: AppColors.textMuted)),
          ]),
        ),
      ),
    ]);
  }
}
