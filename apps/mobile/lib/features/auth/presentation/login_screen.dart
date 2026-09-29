import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/coming_soon_badge.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authControllerProvider, (_, s) {
      if (s.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapErrorMessage(s.error!))));
      }
    });
    final busy = ref.watch(authControllerProvider).isLoading;
    final maxBps = ref.watch(maxRateBpsProvider).value ?? 0;
    final upTo = maxBps > 0 ? ' tới ${_percent(maxBps)}' : '';
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(20)),
                child: const Text('₫', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 24),
              const Text('Chào mừng đến CanhGia', style: AppText.h1),
              const SizedBox(height: 8),
              Text(
                'Mua sắm qua Shopee, Lazada, TikTok Shop… và nhận hoàn tiền$upTo mỗi đơn.',
                style: AppText.body.copyWith(color: AppColors.textMuted, fontSize: 16),
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Tiếp tục với Google',
                loading: busy,
                onPressed: () => ref.read(authControllerProvider.notifier).signInWithGoogle(),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Tiếp tục với Email',
                kind: AppButtonKind.outline,
                onPressed: busy ? null : () => context.push(RoutePaths.loginEmailOtp),
              ),
              const SizedBox(height: 24),
              const Center(child: Text('hoặc tiếp tục với', style: AppText.caption)),
              const SizedBox(height: 12),
              const _DisabledProvider('Số điện thoại (OTP)'),
              const _DisabledProvider('Facebook'),
              const _DisabledProvider('Apple ID'),
              const SizedBox(height: 16),
              const Text(
                'Bằng việc tiếp tục, bạn đồng ý với Điều khoản sử dụng và Chính sách bảo mật của CanhGia.',
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 2000 bps -> "20%", 1250 -> "12,5%".
  static String _percent(int bps) {
    final v = bps / 100;
    return '${v == v.roundToDouble() ? v.round() : v.toString().replaceAll('.', ',')}%';
  }
}

class _DisabledProvider extends StatelessWidget {
  const _DisabledProvider(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Text(label, style: AppText.title.copyWith(color: AppColors.textMuted)),
            const Spacer(),
            const ComingSoonBadge(),
          ]),
        ),
      );
}
