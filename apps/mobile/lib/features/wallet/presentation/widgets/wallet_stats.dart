import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/wallet.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../orders/application/orders_providers.dart';
import '../../../withdraw/application/withdraw_providers.dart';

/// "Chờ duyệt" (pending + held), "Tổng đã hoàn" and the explanatory note.
class WalletStats extends ConsumerWidget {
  const WalletStats({super.key, required this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(creditedOrderCountProvider).value;
    final min = ref.watch(publicSettingsProvider).value?.minWithdrawVnd;
    Widget card(String title, int amount, Color color, String caption) => Expanded(
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppText.body),
              const SizedBox(height: 4),
              Text(formatVnd(amount), style: AppText.h2.copyWith(color: color)),
              const SizedBox(height: 2),
              Text(caption, style: AppText.caption),
            ]),
          ),
        );
    return Column(children: [
      Row(children: [
        card('Chờ duyệt', wallet?.awaitingVnd ?? 0, AppColors.warning,
            'Chờ sàn ${formatVnd(wallet?.pendingVnd ?? 0)} · Đang giữ ${formatVnd(wallet?.heldVnd ?? 0)}'),
        const SizedBox(width: 12),
        card('Tổng đã hoàn', wallet?.totalEarnedVnd ?? 0, AppColors.primary, count == null ? 'Từ các đơn đã duyệt' : 'Từ $count đơn hàng'),
      ]),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.infoTint, borderRadius: BorderRadius.circular(14)),
        child: Text(
          '${min == null ? '' : 'Rút tối thiểu ${formatVnd(min)}. '}Chờ duyệt gồm đơn sàn chưa đối soát và tiền đang trong '
          'thời gian giữ chống hoàn đơn (thường 30 ngày, theo sàn); tiền chuyển sang khả dụng khi hết hạn đổi trả.',
          style: AppText.body.copyWith(color: AppColors.info),
        ),
      ),
    ]);
  }
}
