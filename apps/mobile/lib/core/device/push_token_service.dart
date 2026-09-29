import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';
import '../supabase/supabase_providers.dart';

/// Keeps the FCM token in `push_tokens` for the signed-in user. No-op unless
/// FCM_ENABLED (Firebase initialised in main.dart); failures are logged, never
/// fatal to login or sign-out.
class PushTokenService {
  PushTokenService(this._client);
  final SupabaseClient _client;

  StreamSubscription<String>? _refreshSub;
  String? _token;

  Future<void> register(String uid) async {
    if (!Env.fcmEnabled) return;
    try {
      await _refreshSub?.cancel();
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      if (token != null) {
        _token = token;
        await upsertToken(uid, token);
      }
      _refreshSub = fm.onTokenRefresh.listen((t) {
        _token = t;
        upsertToken(uid, t).catchError((Object e) => debugPrint('push token refresh failed: $e'));
      });
    } on Object catch (e) {
      debugPrint('push token registration skipped: $e');
    }
  }

  /// Sign-out: stop listening, drop this device's row (session must still be valid)
  /// and revoke the FCM token so the previous user's pushes stop reaching this phone.
  Future<void> unregister() async {
    await cancel();
    if (!Env.fcmEnabled) return;
    try {
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token != null) await deleteRow(token);
    } on Object catch (e) {
      debugPrint('push token row delete failed: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } on Object catch (e) {
      debugPrint('fcm deleteToken failed: $e');
    }
    _token = null;
  }

  Future<void> cancel() async {
    final sub = _refreshSub;
    _refreshSub = null;
    await sub?.cancel();
  }

  Future<void> deleteRow(String token) => _client.from('push_tokens').delete().eq('token', token);

  /// Delete-then-insert: a stale row owned by another user (RLS-invisible, so the
  /// delete is a no-op) can no longer make the upsert fail silently as an UPDATE
  /// on a row we do not own. A row we own is simply replaced.
  @visibleForTesting
  Future<void> upsertToken(String uid, String token) async {
    await deleteRow(token);
    await _client.from('push_tokens').insert({
      'token': token,
      'user_id': uid,
      'platform': Platform.isIOS ? 'ios' : 'android',
    });
  }
}

final pushTokenServiceProvider = Provider<PushTokenService>((ref) {
  final s = PushTokenService(ref.watch(supabaseProvider));
  ref.onDispose(s.cancel);
  return s;
});
