import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';
import '../models/wallet.dart';
import '../utils/format_vnd.dart';

/// Green gradient card: available balance + awaiting amount. Data comes from `walletProvider`.
class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({super.key, required this.wallet, this.onTap});

  final Wallet? wallet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Số dư khả dụng', style: white.copyWith(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              formatVnd(wallet?.availableVnd ?? 0),
              style: white.copyWith(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Chờ duyệt ${formatVnd(wallet?.awaitingVnd ?? 0)}',
              style: white.copyWith(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
