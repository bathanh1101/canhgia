import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/device/device_identity_service.dart';
import 'core/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Env.supabaseConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  if (Env.fcmEnabled) {
    try {
      await Firebase.initializeApp();
    } on Object catch (e) {
      // Push is optional: a missing/invalid Firebase setup must not stop the app.
      debugPrint('Firebase init skipped: $e');
    }
  }

  // anonKey (legacy JWT) is what the local stack issues; publishableKey is the same header.
  // ignore: deprecated_member_use
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const CanhGiaApp(),
  ));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Thiếu cấu hình SUPABASE_ANON_KEY.\nChạy với --dart-define-from-file=env/dev.json (xem env/example.json).',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
