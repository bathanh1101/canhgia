import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../supabase/realtime_service.dart';
import '../supabase/supabase_providers.dart';
import 'auth_session_provider.dart';

/// Live wallet row (Realtime stream); re-subscribes on `resync`.
final walletProvider = StreamProvider<Wallet?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value?.kind == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref
      .watch(supabaseProvider)
      .from('wallets')
      .stream(primaryKey: ['user_id'])
      .eq('user_id', uid)
      .map((rows) => rows.isEmpty ? null : Wallet.fromJson(rows.first));
});
