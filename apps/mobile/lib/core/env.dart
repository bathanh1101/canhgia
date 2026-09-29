import 'package:flutter/foundation.dart';

/// Build-time config, supplied with `--dart-define-from-file=env/dev.json`.
/// Only public values belong here (anon key, client ids) - never a service key.
class Env {
  const Env._();

  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://10.0.2.2:55321');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appBaseUrl =
      String.fromEnvironment('APP_BASE_URL', defaultValue: 'https://canhgia.vn');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  static const turnstileSiteKey = String.fromEnvironment('TURNSTILE_SITE_KEY');
  static const _turnstileTestTokenDefine = String.fromEnvironment('TURNSTILE_TEST_TOKEN');
  /// Integration-test hook: ignored outside debug builds.
  static String get turnstileTestToken => kDebugMode ? _turnstileTestTokenDefine : '';
  static const fcmEnabled = bool.fromEnvironment('FCM_ENABLED');

  static bool get supabaseConfigured => supabaseAnonKey.isNotEmpty;
  static bool get googleConfigured => googleWebClientId.isNotEmpty;
  /// A real Turnstile challenge must be solved before sending an email OTP.
  static bool get captchaRequired => turnstileSiteKey.isNotEmpty && turnstileTestToken.isEmpty;
}
