import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../env.dart';

/// Upserts the FCM token into `push_tokens`. No-op unless FCM_ENABLED (Firebase
/// initialised in main.dart); failures are logged, never fatal to login.
class PushTokenService {
  PushTokenService(this._client);
  final SupabaseClient _client;

  Future<void> register(String uid) async {
    if (!Env.fcmEnabled) return;
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      final token = await fm.getToken();
      if (token != null) await _upsert(uid, token);
      fm.onTokenRefresh.listen(
        (t) => _upsert(uid, t).catchError((Object e) => debugPrint('push token refresh failed: $e')),
      );
    } on Object catch (e) {
      debugPrint('push token registration skipped: $e');
    }
  }

  Future<void> _upsert(String uid, String token) => _client.from('push_tokens').upsert({
        'token': token,
        'user_id': uid,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
}
