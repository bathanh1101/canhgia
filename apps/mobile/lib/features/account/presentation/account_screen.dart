import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/widgets/app_button.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_providers.dart';
import '../data/account_repository.dart';
import 'widgets/account_header.dart';
import 'widgets/account_tile.dart';
import 'widgets/biometric_tile.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  String? _kycLabel(String? s) =>
      switch (s) { 'verified' => '✓ Đã xác thực', 'pending' => 'Đang chờ duyệt', 'rejected' => 'Bị từ chối', _ => 'Chưa xác thực' };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final wallet = ref.watch(walletProvider).value;
    final stats = ref.watch(accountStatsProvider).value ?? const AccountStats();
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final hasPin = profile?.hasPin ?? false;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(accountStatsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AccountHeader(profile: profile, wallet: wallet, stats: stats),
              AccountGroup(title: 'Tài khoản', children: [
                AccountTile(icon: Icons.person_outline, title: 'Thông tin cá nhân', onTap: () => context.push(RoutePaths.accountInfo)),
                AccountTile(
                  icon: Icons.badge_outlined,
                  title: 'Xác thực định danh (KYC)',
                  value: _kycLabel(stats.kycStatus),
                  onTap: () => context.push(RoutePaths.kyc),
                ),
                AccountTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Tài khoản ngân hàng & ví',
                  value: '${stats.bankAccounts} tài khoản',
                  onTap: () => context.push(RoutePaths.kycStep(2)),
                ),
              ]),
              AccountGroup(title: 'Bảo mật', children: [
                AccountTile(
                  icon: Icons.pin_outlined,
                  title: 'Mã PIN rút tiền',
                  value: hasPin ? 'Đã bật' : 'Chưa đặt',
                  onTap: () => context.push(RoutePaths.pinFor(hasPin ? 'change' : 'create')),
                ),
                BiometricTile(hasPin: hasPin),
                AccountTile(
                  icon: Icons.devices_outlined,
                  title: 'Thiết bị đăng nhập',
                  value: '${stats.devices} thiết bị',
                  onTap: () => context.push(RoutePaths.accountDevices),
                ),
                AccountTile(
                  icon: Icons.qr_code_scanner,
                  title: 'Đăng nhập tiện ích Chrome',
                  onTap: () => context.push(RoutePaths.accountExtensionLogin),
                ),
              ]),
              AccountGroup(title: 'Hỗ trợ', children: [
                AccountTile(
                  icon: Icons.support_agent,
                  title: 'Báo đơn bị thiếu / lỗi',
                  onTap: () => context.push(RoutePaths.missingOrder),
                ),
                AccountTile(
                  icon: Icons.notifications_none,
                  title: 'Cài đặt thông báo',
                  onTap: () => context.push(RoutePaths.accountNotificationSettings),
                ),
              ]),
              const SizedBox(height: 24),
              AppButton(
                label: 'Đăng xuất',
                kind: AppButtonKind.outline,
                loading: signingOut,
                onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
