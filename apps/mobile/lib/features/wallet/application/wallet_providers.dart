import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/ledger_entry.dart';
import '../data/ledger_repository.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) => LedgerRepository(ref.watch(supabaseProvider)));

/// Balance movements, newest first; refetched when orders / withdrawals change.
final ledgerProvider = FutureProvider.autoDispose.family<List<LedgerEntry>, int>((ref, limit) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value?.kind == 'orders' || e.value?.kind == 'withdrawals' || e.value?.kind == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(ledgerRepositoryProvider).list(uid, limit: limit);
});
