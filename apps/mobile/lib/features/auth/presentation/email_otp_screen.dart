import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/env.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../application/auth_controller.dart';
import 'widgets/turnstile_captcha.dart';

/// Two steps on one screen: email (+ captcha) -> 6-digit code. Success = session
/// appears and the router redirects to /home.
class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  static const _cooldown = 60;
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _captcha;
  var _captchaEpoch = 0;
  var _codeStep = false;
  var _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 1) {
        t.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _send() async {
    await ref.read(authControllerProvider.notifier).sendEmailOtp(_email.text, captchaToken: _captcha);
    if (!mounted) return;
    if (ref.read(authControllerProvider).hasError) {
      // Turnstile tokens are single-use: force a fresh challenge for the retry.
      if (Env.captchaRequired) {
        setState(() {
          _captcha = null;
          _captchaEpoch++;
        });
      }
      return;
    }
    setState(() => _codeStep = true);
    _startCooldown();
  }

  /// Turnstile tokens are single-use: with a real captcha go back to step 1 for a fresh one.
  void _resend() {
    if (!Env.captchaRequired) {
      _send();
      return;
    }
    setState(() {
      _codeStep = false;
      _captcha = null;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, s) {
      if (s.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mapErrorMessage(s.error!))));
      }
    });
    final busy = ref.watch(authControllerProvider).isLoading;
    final captchaOk = !Env.captchaRequired || _captcha != null;
    return Scaffold(
      appBar: const AppTopBar(title: 'Đăng nhập bằng Email'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (!_codeStep) ...[
            const Text('Nhập email, chúng tôi sẽ gửi mã 6 số để đăng nhập.', style: AppText.body),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(hintText: 'ban@example.com'),
            ),
            const SizedBox(height: 16),
            TurnstileCaptcha(key: ValueKey(_captchaEpoch), onToken: (t) => setState(() => _captcha = t)),
            const SizedBox(height: 16),
            AppButton(label: 'Gửi mã', loading: busy, onPressed: captchaOk ? _send : null),
          ] else ...[
            Text('Đã gửi mã đến ${_email.text.trim()}', style: AppText.body),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: AppText.h1.copyWith(letterSpacing: 8),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'Xác nhận',
              loading: busy,
              onPressed: () => ref.read(authControllerProvider.notifier).verifyEmailOtp(_email.text, _code.text),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: _secondsLeft > 0 ? 'Gửi lại mã sau ${_secondsLeft}s' : 'Gửi lại mã',
              kind: AppButtonKind.text,
              onPressed: _secondsLeft > 0 || busy ? null : _resend,
            ),
          ],
        ],
      ),
    );
  }
}
