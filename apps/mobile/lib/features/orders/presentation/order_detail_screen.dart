import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/orders_providers.dart';
import '../data/order.dart';
import 'widgets/order_timeline.dart';

/// Screen 09 - order detail with refund timeline.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.now});

  final String orderId;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(orderId));
    return Scaffold(
      appBar: const AppTopBar(title: 'Chi tiết đơn hàng'),
      body: AsyncValueView(
        value: async,
        onRetry: () => ref.invalidate(orderDetailProvider(orderId)),
        data: (o) => o == null
            ? const EmptyState(message: 'Không tìm thấy đơn hàng.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                _Header(order: o, now: now ?? DateTime.now()),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tiến trình hoàn tiền', style: AppText.title),
                    const SizedBox(height: 16),
                    OrderTimeline(steps: orderTimeline(o, now ?? DateTime.now())),
                  ]),
                ),
                const SizedBox(height: 12),
                _Facts(order: o, merchantName: _merchantName(ref, o)),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Báo lỗi / khiếu nại đơn hàng',
                  kind: AppButtonKind.outline,
                  onPressed: () => context.push(RoutePaths.missingOrder),
                ),
              ]),
      ),
    );
  }

  String _merchantName(WidgetRef ref, Order o) =>
      ref.watch(merchantsProvider).value?.where((m) => m.id == o.merchantId).firstOrNull?.name ?? o.merchantId;
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.now});
  final Order order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = order.isCancelled
        ? ('Đơn đã bị hủy', AppColors.error, AppColors.errorTint)
        : order.isCredited
            ? (order.holdActive(now) ? 'Đang trong thời gian giữ' : 'Đã cộng vào ví', AppColors.primaryDark, AppColors.primaryTint)
            : ('Đang chờ đối soát', AppColors.warning, AppColors.warningTint);
    final due = order.withdrawableAt;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.title.copyWith(color: fg)),
        Text(
          '${order.cashbackVnd > 0 ? '+' : ''}${formatVnd(order.cashbackVnd)}',
          style: AppText.h1.copyWith(color: fg),
        ),
        Text(
          '${order.title}${!order.isCancelled && due != null ? ' · Dự kiến khả dụng ${formatDate(due)}' : ''}',
          style: AppText.caption.copyWith(color: fg),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ]),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.order, required this.merchantName});
  final Order order;
  final String merchantName;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Text(k, style: AppText.body.copyWith(color: AppColors.textMuted)),
            const Spacer(),
            Flexible(child: Text(v, style: AppText.title.copyWith(fontSize: 14, color: color), textAlign: TextAlign.end)),
          ]),
        );
    return AppCard(
      child: Column(children: [
        row('Mã đơn hàng', order.transactionId ?? '--'),
        row('Sàn', order.source == 'manual' ? '$merchantName · Bổ sung thủ công' : merchantName),
        row('Giá trị đơn', formatVnd(order.valueVnd)),
        const Divider(),
        row('Tiền hoàn', formatVnd(order.cashbackVnd), color: order.isCancelled ? AppColors.error : AppColors.primary),
      ]),
    );
  }
}
