import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/profile_provider.dart';
import '../theme/app_colors.dart';

/// Bottom navigation (Trang chủ / Ưu đãi / Ví tiền / Mời bạn / Tài khoản) and the
/// blocking banner for locked accounts.
class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(isAccountLockedProvider);
    return Scaffold(
      body: Column(children: [
        if (locked)
          Container(
            width: double.infinity,
            color: AppColors.errorTint,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 8, 16, 8),
            child: const Text(
              'Tài khoản của bạn đang bị khóa nên không thể rút tiền hay thực hiện giao dịch. Vui lòng liên hệ hỗ trợ.',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        Expanded(child: navigationShell),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.local_offer_outlined), selectedIcon: Icon(Icons.local_offer), label: 'Ưu đãi'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Ví tiền'),
          NavigationDestination(icon: Icon(Icons.card_giftcard_outlined), selectedIcon: Icon(Icons.card_giftcard), label: 'Mời bạn'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
