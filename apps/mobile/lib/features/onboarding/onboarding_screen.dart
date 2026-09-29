import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';
import 'onboarding_seen_provider.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  Future<void> _continue(BuildContext context, WidgetRef ref) async {
    await ref.read(onboardingSeenProvider.notifier).markSeen();
    if (context.mounted) context.go(RoutePaths.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const steps = [
      'Sao chép link sản phẩm yêu thích',
      'Mở CanhGia để tạo link hoàn tiền',
      'Mua hàng & nhận tiền về ví',
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _DemoCard(),
                const SizedBox(height: 32),
                Text('Mua sắm như thường,\nnhận lại tiền mỗi đơn',
                    style: AppText.h1.copyWith(color: Colors.white, fontSize: 26)),
                const SizedBox(height: 12),
                Text(
                  'Hoàn tiền khi mua trên Shopee, Lazada, TikTok Shop, Agoda và các đối tác khác.',
                  style: AppText.body.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                for (final (i, s) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white24,
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s, style: AppText.title.copyWith(color: Colors.white, fontSize: 15))),
                    ]),
                  ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _continue(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    ),
                    child: const Text('Bắt đầu ngay', style: AppText.button),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => _continue(context, ref),
                    child: const Text('Tôi đã có tài khoản · Đăng nhập',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Illustrative example only (not real data): shows what a cashback looks like.
class _DemoCard extends StatelessWidget {
  const _DemoCard();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ví dụ sản phẩm', style: AppText.title),
          const Text('Giá bán · Shopee', style: AppText.caption),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.primaryTintStrong, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(children: [
              const Text('Hoàn tiền', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('về ví của bạn', style: AppText.h2.copyWith(color: AppColors.primaryDark)),
            ]),
          ),
        ]),
      );
}
