import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../application/pin_controller.dart';
import '../application/pin_state.dart';
import 'widgets/lock_countdown.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_keypad.dart';
import 'widgets/pin_otp_panel.dart';

/// Screen 05 - PIN entry sheet for verify / create / change; `reset` explains the support path.
class PinScreen extends ConsumerWidget {
  const PinScreen({super.key, required this.args, this.hint});

  final PinArgs args;

  /// Context line for verify (e.g. "Xác nhận rút 500.000đ về ...").
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = pinControllerProvider(args);
    ref.listen(provider, (_, s) {
      if (s.result != null && context.canPop()) context.pop(s.result);
    });
    final s = ref.watch(provider);
    final ctl = ref.read(provider.notifier);
    final (title, subtitle) = pinHeading(args.mode, s.phase, verifyHint: hint);
    final biometric =
        args.mode == PinMode.verify &&
        !args.returnPin &&
        (ref.watch(pinBiometricAvailableProvider).value ?? false);
    final locked = s.lockedUntil != null;
    return Scaffold(
      backgroundColor: AppColors.text,
      appBar: AppBar(
        backgroundColor: AppColors.text,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              reverse: true,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  MediaQuery.paddingOf(context).bottom + 16,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: args.mode == PinMode.reset
                    ? const _ResetInfo()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryTintStrong,
                            child: Text(
                              '***',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(title, style: AppText.h2),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: AppText.body,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (s.needsOtp)
                            PinOtpPanel(onVerified: ctl.retryCreate)
                          else ...[
                            PinDots(filled: s.digits.length),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 40,
                              child: locked
                                  ? LockCountdown(
                                      until: s.lockedUntil!,
                                      onDone: ctl.unlock,
                                    )
                                  : Text(
                                      s.message ?? '',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                      ),
                                    ),
                            ),
                            PinKeypad(
                              enabled: !s.busy && !locked,
                              onDigit: ctl.press,
                              onBackspace: ctl.backspace,
                              leading: biometric
                                  ? TextButton(
                                      onPressed: s.busy || locked
                                          ? null
                                          : ctl.useBiometric,
                                      child: const Text('Sinh trắc học'),
                                    )
                                  : null,
                            ),
                            if (args.mode == PinMode.verify && !args.returnPin)
                              TextButton(
                                onPressed: () =>
                                    context.push(RoutePaths.pinFor('reset')),
                                child: const Text('Quên mã PIN?'),
                              ),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResetInfo extends StatelessWidget {
  const _ResetInfo();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.support_agent, size: 48, color: AppColors.primary),
      const SizedBox(height: 12),
      Text('Quên mã PIN?', style: AppText.h2),
      const SizedBox(height: 8),
      const Text(
        'Vì lý do an toàn, việc đặt lại mã PIN cần được hỗ trợ xác minh. Vui lòng liên hệ hỗ trợ CanhGia '
        'từ email đã đăng ký. Nếu nhớ PIN cũ, bạn có thể đổi trong Tài khoản > Đổi mã PIN.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
