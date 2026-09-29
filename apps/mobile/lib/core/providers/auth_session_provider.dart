import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';

/// Current session (null = signed out). Emits immediately, then on every auth event.
final authSessionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentSession;
  await for (final e in auth.onAuthStateChange) {
    yield e.session;
  }
});

/// Signed-in user id or null. Only rebuilds dependants when the id changes.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authSessionProvider.select((s) => s.value?.user.id)),
);

/// Synchronous signed-in flag for router redirects (falls back to the persisted
/// session while the stream has not emitted yet).
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authSessionProvider).when(
        data: (s) => s != null,
        loading: () => ref.read(supabaseProvider).auth.currentSession != null,
        error: (_, _) => false,
      );
});
