import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_identity_service.dart';
import '../device/push_token_service.dart';
import '../security/biometric_pin_vault.dart';
import '../supabase/supabase_providers.dart';
import 'auth_session_provider.dart';
import 'referral_store.dart';

String _lastTouchKey(String uid) => 'last_touch_activity_day:$uid';

/// Runs whenever the session ends by any route (user sign-out, server-side
/// revocation/expiry): wipes that user's biometric PIN and any pending referral.
final sessionCleanupProvider = Provider<void>((ref) {
  ref.listen<String?>(currentUserIdProvider, (prev, next) {
    if (prev == null || next != null) return;
    _guard('vault_wipe', () => BiometricPinVault(prev).disable());
    _guard('referral_clear', () => ref.read(referralStoreProvider).clear());
    _guard('push_cancel', () => ref.read(pushTokenServiceProvider).cancel());
  });
});

/// Post-login chores, each isolated so one failure never blocks the others:
/// register_device, complete_onboarding, bind_referral, FCM token, and
/// touch_activity (at login and on resume, at most once per day).
/// Watched by the app root; re-runs when the signed-in user changes.
final sessionBootstrapProvider = Provider<void>((ref) {
  ref.watch(sessionCleanupProvider);
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return;
  final observer = _ResumeObserver(() => _touchActivity(ref, uid));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  _guard('register_device', () => registerDevice(ref));
  _guard('complete_onboarding', () => ref.read(supabaseProvider).rpc('complete_onboarding'));
  _guard('bind_referral', () => bindPendingReferral(ref.read(supabaseProvider), ref.read(referralStoreProvider)));
  _guard('touch_activity', () => _touchActivity(ref, uid));
  _guard('push_token', () => ref.read(pushTokenServiceProvider).register(uid));
});

class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this.onResume);
  final VoidCallback onResume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

Future<void> _guard(String name, Future<void> Function() task) async {
  try {
    await task();
  } on Object catch (e) {
    debugPrint('bootstrap $name failed: $e');
  }
}

Future<void> _touchActivity(Ref ref, String uid) => _guard('touch_activity', () async {
      final prefs = ref.read(sharedPreferencesProvider);
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      if (prefs.getString(_lastTouchKey(uid)) == today) return;
      await ref.read(supabaseProvider).rpc('touch_activity');
      await prefs.setString(_lastTouchKey(uid), today);
    });
