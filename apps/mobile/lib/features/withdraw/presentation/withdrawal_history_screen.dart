import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_pill.dart';
import '../application/withdraw_providers.dart';
import '../data/withdrawal.dart';
import 'widgets/bank_account_tile.dart';

/// Withdrawal requests with live status (Chờ xử lý / Đã chuyển / Từ chối).
class WithdrawalHistoryScreen extends ConsumerWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(banksProvider).value ?? const [];
    return Scaffold(
      appBar: const AppTopBar(title: 'Lịch sử rút tiền'),
      body: AsyncValueView(
        value: ref.watch(withdrawalsProvider),
        onRetry: () => ref.invalidate(withdrawalsProvider),
        data: (list) => list.isEmpty
            ? const EmptyState(message: 'Bạn chưa có yêu cầu rút tiền nào.', icon: Icons.account_balance_outlined)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (_, i) => _Row(w: list[i], bankName: bankNameOf(banks, list[i].bankBin)),
              ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.w, required this.bankName});
  final Withdrawal w;
  final String bankName;

  @override
  Widget build(BuildContext context) {
    final tail = w.accountNumber.length > 4 ? w.accountNumber.substring(w.accountNumber.length - 4) : w.accountNumber;
    final pill = switch (w.status) {
      'paid' => StatusPill(w.statusLabel, PillTone.success),
      'rejected' => StatusPill(w.statusLabel, PillTone.danger),
      _ => StatusPill(w.statusLabel, PillTone.pending),
    };
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$bankName •••• $tail', style: AppText.title.copyWith(fontSize: 15)),
          Text(formatDateTime(w.createdAt), style: AppText.caption),
          if (w.status == 'rejected' && w.rejectReason != null)
            Text('Lý do: ${w.rejectReason}', style: AppText.caption.copyWith(color: AppColors.error)),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [MoneyText(w.amount), const SizedBox(height: 4), pill]),
    ]);
  }
}
