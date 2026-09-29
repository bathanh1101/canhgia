import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_date.dart';
import '../../data/app_notification.dart';

IconData notificationIcon(String type) => switch (type) {
      'order' => Icons.receipt_long_outlined,
      'wallet' => Icons.account_balance_wallet_outlined,
      'promo' => Icons.local_offer_outlined,
      'referral' => Icons.card_giftcard_outlined,
      _ => Icons.notifications_none,
    };

/// hh:mm today / "3 giờ trước" style is overkill: show time for today, dd/mm otherwise.
String notificationTime(DateTime t, DateTime now) {
  final l = t.toLocal();
  final sameDay = l.year == now.year && l.month == now.month && l.day == now.day;
  return sameDay ? '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}' : formatDayMonth(t);
}

class NotificationTile extends StatelessWidget {
  const NotificationTile({super.key, required this.item, required this.now, required this.onTap});

  final AppNotification item;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          color: item.isRead ? null : AppColors.primaryTint,
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(backgroundColor: AppColors.primaryTintStrong, foregroundColor: AppColors.primary, child: Icon(notificationIcon(item.type), size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(item.title, style: AppText.title.copyWith(fontSize: 15))),
                  Text(notificationTime(item.createdAt, now), style: AppText.caption),
                  if (!item.isRead)
                    Container(margin: const EdgeInsets.only(left: 6), width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ]),
                if (item.body != null) Text(item.body!, style: AppText.body.copyWith(color: AppColors.textMuted)),
              ]),
            ),
          ]),
        ),
      );
}
