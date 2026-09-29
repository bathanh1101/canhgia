import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/env.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../application/rewards_providers.dart';
import '../../data/rewards_models.dart';

/// Public referral link `<APP_BASE_URL>/r/<code>`.
String referralLink(String code) => '${Env.appBaseUrl}/r/$code';

/// "Mời bạn, nhận đến 30.000đ": code, copy/share, stats, enter someone else's code.
class ReferralCard extends ConsumerWidget {
  const ReferralCard({super.key, required this.code, required this.stats, required this.bonusVnd});

  final String code;
  final ReferralStats stats;

  /// `referral_bonus_vnd` public setting (upper bound of the reward).
  final int bonusVnd;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(const SnackBar(content: Text('Đã sao chép mã giới thiệu')));
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SharePlus.instance.share(ShareParams(text: 'Mua sắm được hoàn tiền cùng CanhGia! Dùng mã $code: ${referralLink(code)}'));
    } on Object {
      messenger.showSnackBar(const SnackBar(content: Text('Không mở được chia sẻ. Vui lòng thử lại.')));
    }
  }

  Future<void> _bind(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(rewardsRepositoryProvider); // read before awaiting: `ref` is unusable once the card is gone
    final ctrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập mã giới thiệu'),
        content: TextField(controller: ctrl, textCapitalization: TextCapitalization.characters, maxLength: 12),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Xác nhận')),
        ],
      ),
    );
    ctrl.dispose();
    if (entered == null || entered.isEmpty) return;
    try {
      await repo.bindReferral(entered);
      messenger.showSnackBar(const SnackBar(content: Text('Đã áp dụng mã giới thiệu.')));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(bindReferralMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const white = TextStyle(color: Colors.white);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(AppRadius.xl)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mời bạn, nhận đến ${formatVnd(bonusVnd)}', style: AppText.h2.merge(white)),
        const SizedBox(height: 4),
        Text('Khi bạn bè mua đơn đầu tiên từ 200.000đ qua CanhGia; thưởng về ví sau 30 ngày.', style: AppText.body.merge(white.copyWith(color: Colors.white70))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Expanded(child: Text(code, style: AppText.h2.merge(white).copyWith(letterSpacing: 2))),
            IconButton(tooltip: 'Sao chép', onPressed: code.isEmpty ? null : () => _copy(context), icon: const Icon(Icons.copy, color: Colors.white)),
            IconButton(tooltip: 'Chia sẻ', onPressed: code.isEmpty ? null : () => _share(context), icon: const Icon(Icons.share, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 8),
        Text('Đã mời ${stats.invited} bạn · Thưởng nhận được ${formatVnd(stats.bonusVnd)}', style: AppText.body.merge(white)),
        TextButton(
          onPressed: () => _bind(context, ref),
          style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: const Text('Bạn có mã giới thiệu?'),
        ),
      ]),
    );
  }
}
