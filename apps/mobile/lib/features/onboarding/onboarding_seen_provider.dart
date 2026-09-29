import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/device/device_identity_service.dart';

const _key = 'onboarding_seen_v1';

/// Whether the intro was shown once on this install (local flag).
class OnboardingSeen extends Notifier<bool> {
  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? false;

  Future<void> markSeen() async {
    await ref.read(sharedPreferencesProvider).setBool(_key, true);
    state = true;
  }
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeen, bool>(OnboardingSeen.new);
