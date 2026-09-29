import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_date.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../application/wallet_providers.dart';

/// "Biến động số dư": every ledger movement with the hold note for pending credits.
class LedgerList extends ConsumerWidget {
  const LedgerList({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = now ?? DateTime.now();
    return ref.watch(ledgerProvider(50)).when(
          skipLoadingOnRefresh: true,
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (_, _) => Center(
            child: TextButton(onPressed: () => ref.invalidate(ledgerProvider), child: const Text('Không tải được. Thử lại')),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(message: 'Chưa có biến động số dư.', icon: Icons.receipt_long_outlined)
              : Column(children: [
                  for (final e in list)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.label, style: AppText.title.copyWith(fontSize: 15)),
                            Text(formatDateTime(e.createdAt), style: AppText.caption),
                            if (e.heldNote(at) != null) Text(e.heldNote(at)!, style: AppText.caption.copyWith(color: AppColors.warning)),
                          ]),
                        ),
                        MoneyText(e.amountVnd, signed: true, style: TextStyle(color: e.amountVnd < 0 ? AppColors.error : AppColors.primary)),
                      ]),
                    ),
                ]),
        );
  }
}
