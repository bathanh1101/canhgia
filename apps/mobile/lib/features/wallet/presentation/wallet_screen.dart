import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import 'widgets/order_history.dart';
import 'widgets/wallet_header.dart';
import 'widgets/wallet_stats.dart';

/// Screen 03 - "Ví của tôi" tab: balances, note and live order history.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(
          title: const Text('Ví của tôi'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: context.push,
              itemBuilder: (_) => const [
                PopupMenuItem(value: '${RoutePaths.withdraw}/history', child: Text('Lịch sử rút tiền')),
                PopupMenuItem(value: RoutePaths.missingOrder, child: Text('Báo đơn bị thiếu')),
                PopupMenuItem(value: RoutePaths.kyc, child: Text('Tài khoản nhận tiền')),
              ],
            ),
          ],
        ),
        body: AsyncValueView(
          value: ref.watch(walletProvider),
          onRetry: () => ref.invalidate(walletProvider),
          data: (w) => ListView(padding: const EdgeInsets.all(16), children: [
            WalletHeader(wallet: w),
            const SizedBox(height: 12),
            WalletStats(wallet: w),
            const SizedBox(height: 20),
            OrderHistory(now: now),
          ]),
        ),
      );
}
