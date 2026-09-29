import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/bank_models.dart';
import '../data/withdraw_repository.dart';
import '../data/withdrawal.dart';

final withdrawRepositoryProvider = Provider<WithdrawRepository>((ref) => WithdrawRepository(ref.watch(supabaseProvider)));

final bankAccountsProvider = FutureProvider.autoDispose<List<BankAccount>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? const [] : ref.watch(withdrawRepositoryProvider).bankAccounts(uid);
});

final defaultBankAccountProvider = FutureProvider.autoDispose<BankAccount?>(
  (ref) async => pickDefaultAccount(await ref.watch(bankAccountsProvider.future)),
);

final banksProvider = FutureProvider<List<Bank>>((ref) => ref.watch(withdrawRepositoryProvider).banks());

final publicSettingsProvider = FutureProvider<PublicSettings>((ref) => ref.watch(withdrawRepositoryProvider).publicSettings());

/// Own withdrawals, refetched on realtime `withdrawals` changes.
final withdrawalsProvider = FutureProvider.autoDispose<List<Withdrawal>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  ref.listen(realtimeEventsProvider, (_, e) {
    if (e.value?.kind == 'withdrawals' || e.value?.kind == RealtimeService.resync) ref.invalidateSelf();
  });
  return ref.watch(withdrawRepositoryProvider).withdrawals(uid);
});
