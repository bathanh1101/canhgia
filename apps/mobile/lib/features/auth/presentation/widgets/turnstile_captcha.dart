import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/env.dart';

/// Reports a captcha token through [onToken] (null = expired/failed/unavailable).
/// - TURNSTILE_TEST_TOKEN set (integration tests): reports it immediately, no webview.
/// - TURNSTILE_SITE_KEY empty (local stack, captcha disabled server-side): reports
///   null and renders nothing; the server decides whether a token is required.
class TurnstileCaptcha extends StatefulWidget {
  const TurnstileCaptcha({super.key, required this.onToken});

  final ValueChanged<String?> onToken;

  @override
  State<TurnstileCaptcha> createState() => _TurnstileCaptchaState();
}

class _TurnstileCaptchaState extends State<TurnstileCaptcha> {
  static final _siteKeyShape = RegExp(r'^[A-Za-z0-9_-]+$');
  WebViewController? _web;

  @override
  void initState() {
    super.initState();
    if (Env.turnstileTestToken.isNotEmpty || Env.turnstileSiteKey.isEmpty) {
      final token = Env.turnstileTestToken.isEmpty ? null : Env.turnstileTestToken;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onToken(token));
      return;
    }
    if (!_siteKeyShape.hasMatch(Env.turnstileSiteKey)) {
      throw StateError('TURNSTILE_SITE_KEY has an unexpected format');
    }
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel('Turnstile', onMessageReceived: (m) => widget.onToken(_tokenFrom(m.message)))
      ..loadHtmlString(_html(Env.turnstileSiteKey), baseUrl: Env.appBaseUrl);
  }

  /// Message `ok:TOKEN` -> TOKEN; `expired` / `error` -> null.
  static String? _tokenFrom(String message) =>
      message.startsWith('ok:') && message.length > 3 ? message.substring(3) : null;

  static String _html(String siteKey) => '''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=ready" async defer></script>
</head><body style="margin:0;background:transparent"><div id="c"></div><script>
function ready(){turnstile.render('#c',{sitekey:'$siteKey',
callback:function(t){Turnstile.postMessage('ok:'+t)},
'expired-callback':function(){Turnstile.postMessage('expired')},
'error-callback':function(){Turnstile.postMessage('error')}})}
</script></body></html>''';

  @override
  Widget build(BuildContext context) {
    if (Env.turnstileTestToken.isNotEmpty || Env.turnstileSiteKey.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xác minh bạn không phải robot', style: AppText.caption),
        const SizedBox(height: 8),
        SizedBox(height: 70, child: WebViewWidget(controller: _web!)),
      ],
    );
  }
}
