import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/models/profile.dart';
import '../../../../core/models/wallet.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../data/account_repository.dart';

class AccountHeader extends StatelessWidget {
  const AccountHeader({super.key, required this.profile, required this.wallet, required this.stats});

  final Profile? profile;
  final Wallet? wallet;
  final AccountStats stats;

  @override
  Widget build(BuildContext context) {
    final name = profile?.shownName ?? '';
    const white = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(children: [
        Row(children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white24,
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: white.copyWith(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: white.copyWith(fontSize: 20, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              if (profile?.email != null) Text(profile!.email!, style: white.copyWith(fontSize: 13, color: Colors.white70)),
              if (stats.tierName != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(999)),
                  child: Text('★ Hạng ${stats.tierName}', style: AppText.caption.copyWith(color: AppColors.text, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Row(children: [
            _Stat('${stats.orders}', 'Đơn hàng'),
            _Stat(formatVndCompact(wallet?.totalEarnedVnd ?? 0), 'Đã hoàn'),
            _Stat('${stats.referrals}', 'Bạn bè'),
          ]),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
}
