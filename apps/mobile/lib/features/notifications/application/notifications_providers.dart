import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(supabaseProvider)));

/// Live: refetched on realtime `notifications` events (e.g. admin marks a withdrawal paid).
final notificationsProvider = FutureProvider.autoDispose.family<List<AppNotification>, NotificationTab>((ref, tab) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value == 'notifications' || e.value == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(notificationsRepositoryProvider).list(uid, type: tab.type);
});
