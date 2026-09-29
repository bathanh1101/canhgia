import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../device/device_identity_service.dart';
import '../device/push_token_service.dart';
import '../supabase/postgrest_error_mapper.dart';
import '../supabase/supabase_providers.dart';
import 'auth_session_provider.dart';
import 'referral_store.dart';

const _lastTouchKey = 'last_touch_activity_day';

/// Post-login chores, each isolated so one failure never blocks the others:
/// register_device, complete_onboarding, bind_referral, FCM token, and
/// touch_activity (at login and on resume, at most once per day).
/// Watched by the app root; re-runs when the signed-in user changes.
final sessionBootstrapProvider = Provider<void>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return;
  final observer = _ResumeObserver(() => _touchActivity(ref));
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  _guard('register_device', () => registerDevice(ref));
  _guard('complete_onboarding', () => ref.read(supabaseProvider).rpc('complete_onboarding'));
  _guard('bind_referral', () => _bindReferral(ref));
  _guard('touch_activity', () => _touchActivity(ref));
  _guard('push_token', () => PushTokenService(ref.read(supabaseProvider)).register(uid));
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

Future<void> _touchActivity(Ref ref) => _guard('touch_activity', () async {
      final prefs = ref.read(sharedPreferencesProvider);
      final now = DateTime.now();
      final today = '${now.year}-${now.month}-${now.day}';
      if (prefs.getString(_lastTouchKey) == today) return;
      await ref.read(supabaseProvider).rpc('touch_activity');
      await prefs.setString(_lastTouchKey, today);
    });

Future<void> _bindReferral(Ref ref) async {
  final store = ref.read(referralStoreProvider);
  final code = store.pending;
  if (code == null) return;
  try {
    await ref.read(supabaseProvider).rpc('bind_referral', params: {'p_code': code});
    await store.clear();
  } on Object catch (e) {
    // Server rejected the code (self/duplicate/unknown): drop it. Transient failure: retry next login.
    final c = errorCodeOf(e);
    if (c != 'network' && c != 'unknown') await store.clear();
    rethrow;
  }
}
