import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/env.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/supabase/postgrest_error_mapper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/presentation/widgets/turnstile_captcha.dart';

/// The first PIN needs a fresh email-OTP session (<= 10 min): send a code to the
/// account email, verify it, then [onVerified] retries storing the PIN.
class PinOtpPanel extends ConsumerStatefulWidget {
  const PinOtpPanel({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  ConsumerState<PinOtpPanel> createState() => _PinOtpPanelState();
}

class _PinOtpPanelState extends ConsumerState<PinOtpPanel> {
  final _code = TextEditingController();
  String? _captcha;
  var _sent = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {required bool advance}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      if (advance) {
        setState(() => _sent = true);
      } else {
        widget.onVerified();
      }
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(profileProvider).value?.email ?? '';
    final repo = ref.watch(authRepositoryProvider);
    final captchaOk = !Env.captchaRequired || _captcha != null;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        'Để tạo mã PIN, hãy xác minh email $email bằng mã 6 số (hiệu lực 10 phút).',
        style: AppText.body,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      if (!_sent) ...[
        TurnstileCaptcha(onToken: (t) => setState(() => _captcha = t)),
        AppButton(
          label: 'Gửi mã xác minh',
          onPressed: email.isEmpty || !captchaOk ? null : () => _run(() => repo.sendEmailOtp(email, captchaToken: _captcha), advance: true),
        ),
      ] else ...[
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        AppButton(label: 'Xác nhận', onPressed: () => _run(() => repo.verifyEmailOtp(email, _code.text), advance: false)),
      ],
    ]);
  }
}
