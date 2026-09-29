import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/realtime_service.dart';
import '../supabase/supabase_providers.dart';
import 'auth_session_provider.dart';

/// Unread count for the bell badge; refetched on any `notifications` change.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value == 'notifications' || e.value == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(supabaseProvider).from('notifications').count().eq('user_id', uid).isFilter('read_at', null);
});
