import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile.dart';
import '../supabase/realtime_service.dart';
import '../supabase/supabase_providers.dart';
import 'auth_session_provider.dart';

final profileProvider = FutureProvider<Profile?>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value == RealtimeService.resync) ref.invalidateSelf();
  });
  final row = await ref.watch(supabaseProvider).from('profiles').select().eq('id', uid).maybeSingle();
  return row == null ? null : Profile.fromJson(row);
});

/// True while `profiles.locked_at` is set: money actions must be disabled.
final isAccountLockedProvider =
    Provider<bool>((ref) => ref.watch(profileProvider).value?.isLocked ?? false);
