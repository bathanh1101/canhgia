import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/merchants_provider.dart';
import '../../../../core/utils/format_date.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../data/order.dart';

/// One row of the order history: merchant badge, title, amount + status pill.
class OrderTile extends ConsumerWidget {
  const OrderTile({super.key, required this.order, this.now});

  final Order order;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    final m = merchants.where((x) => x.id == order.merchantId).firstOrNull;
    final name = m?.name ?? order.merchantId;
    final placed = order.placedAt;
    final hold = order.holdActive(now ?? DateTime.now());
    return InkWell(
      onTap: () => context.push(RoutePaths.orderDetailFor(order.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          MerchantBadge(m?.badgeLetter ?? name.substring(0, 1).toUpperCase()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 15)),
              Text(
                '$name · ${placed == null ? '--' : formatDayMonth(placed)} · Đơn ${formatVnd(order.valueVnd)}',
                style: AppText.caption,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            MoneyText(order.cashbackVnd, signed: true),
            const SizedBox(height: 4),
            StatusPill.forStatus(order.statusKey),
            if (hold)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'khả dụng từ ${formatDayMonth(order.withdrawableAt!)}',
                  style: AppText.caption.copyWith(color: AppColors.warning),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
