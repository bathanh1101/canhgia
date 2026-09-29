import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/wallet.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../withdraw/application/withdraw_providers.dart';
import '../../../withdraw/presentation/widgets/bank_account_tile.dart';

/// Gradient card: available balance, default bank pill, "Rút tiền".
class WalletHeader extends ConsumerWidget {
  const WalletHeader({super.key, required this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(defaultBankAccountProvider).value;
    final banks = ref.watch(banksProvider).value ?? const [];
    final locked = ref.watch(isAccountLockedProvider);
    const white = TextStyle(color: Colors.white);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Số dư khả dụng', style: white.copyWith(fontSize: 13, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(formatVnd(wallet?.availableVnd ?? 0), style: white.copyWith(fontSize: 34, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: bank == null ? () => context.push(RoutePaths.kyc) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  bank == null ? 'Liên kết ngân hàng' : '${bankNameOf(banks, bank.bankBin)} ${bank.masked}',
                  overflow: TextOverflow.ellipsis,
                  style: white.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: locked ? null : () => context.push(RoutePaths.withdraw),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
            child: const Text('Rút tiền', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }
}
