import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/voucher_repository.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) => VoucherRepository(ref.watch(supabaseProvider)));

/// Active vouchers, optionally for one merchant (null = all).
final vouchersProvider = FutureProvider.family<List<Voucher>, String?>((ref, merchantId) {
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value?.kind == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(voucherRepositoryProvider).active(merchantId: merchantId);
});

/// Home strip: the 5 vouchers expiring first.
final homeVouchersProvider = FutureProvider<List<Voucher>>((ref) async {
  final all = await ref.watch(vouchersProvider(null).future);
  return all.take(5).toList();
});

/// Ids the user saved; [toggle] is optimistic and rolls back (rethrowing) when the write fails.
class SavedVoucherIds extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() async {
    final uid = ref.watch(currentUserIdProvider);
    return uid == null ? <int>{} : ref.watch(voucherRepositoryProvider).savedIds(uid);
  }

  Future<void> toggle(int voucherId) async {
    final uid = ref.read(currentUserIdProvider);
    final before = state.value ?? <int>{};
    if (uid == null) return;
    final saving = !before.contains(voucherId);
    state = AsyncData(saving ? {...before, voucherId} : ({...before}..remove(voucherId)));
    try {
      final repo = ref.read(voucherRepositoryProvider);
      await (saving ? repo.save(uid, voucherId) : repo.unsave(uid, voucherId));
    } on Object {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final savedVoucherIdsProvider = AsyncNotifierProvider<SavedVoucherIds, Set<int>>(SavedVoucherIds.new);
