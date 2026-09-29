import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/order.dart';
import '../data/orders_repository.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) => OrdersRepository(ref.watch(supabaseProvider)));

typedef OrdersQuery = ({DateTime month, OrderTab tab, int limit});

/// Re-fetch on any `orders` change (realtime) or after a reconnect.
void _invalidateOnOrders(Ref ref) {
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value == 'orders' || e.value == RealtimeService.resync) ref.invalidateSelf();
  });
}

final ordersProvider = FutureProvider.autoDispose.family<List<Order>, OrdersQuery>((ref, q) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  _invalidateOnOrders(ref);
  return ref.watch(ordersRepositoryProvider).list(uid, month: q.month, tab: q.tab, limit: q.limit);
});

final orderDetailProvider = FutureProvider.autoDispose.family<Order?, String>((ref, id) {
  _invalidateOnOrders(ref);
  return ref.watch(ordersRepositoryProvider).get(id);
});

final creditedOrderCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return 0;
  _invalidateOnOrders(ref);
  return ref.watch(ordersRepositoryProvider).creditedCount(uid);
});
