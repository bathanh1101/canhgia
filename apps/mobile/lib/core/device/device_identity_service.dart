import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../supabase/supabase_providers.dart';

/// Stable per-install device id (random, persisted) + registration with the backend.
/// The Android/iOS hardware ids are deliberately not used (privacy, not stable).
class DeviceIdentityService {
  DeviceIdentityService(this._prefs);

  static const _key = 'device_id_v1';
  final SharedPreferences _prefs;

  String deviceId() {
    final existing = _prefs.getString(_key);
    if (existing != null && existing.length >= 8) return existing;
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    _prefs.setString(_key, id);
    return id;
  }

  String get platform => Platform.isIOS ? 'ios' : 'android';

  Future<String?> model() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (Platform.isIOS) return (await info.iosInfo).utsname.machine;
    } on Object {
      // Model is cosmetic (devices list); registration must not fail on it.
    }
    return null;
  }
}

/// Overridden in main() with the pre-loaded instance (and in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider'),
);

final deviceIdentityProvider =
    Provider<DeviceIdentityService>((ref) => DeviceIdentityService(ref.watch(sharedPreferencesProvider)));

/// Device id for `create-link` (`device_id`) and `register_device`.
final deviceIdProvider = Provider<String>((ref) => ref.watch(deviceIdentityProvider).deviceId());

Future<void> registerDevice(Ref ref) async {
  final svc = ref.read(deviceIdentityProvider);
  await ref.read(supabaseProvider).rpc('register_device', params: {
    'p_device_id': svc.deviceId(),
    'p_platform': svc.platform,
    'p_model': await svc.model(),
  });
}
