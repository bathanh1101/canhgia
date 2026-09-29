import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) => AccountRepository(ref.watch(supabaseProvider)));

final accountStatsProvider = FutureProvider<AccountStats>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const AccountStats();
  final tier = ref.watch(profileProvider.select((p) => p.value?.vipTierCode));
  return ref.watch(accountRepositoryProvider).stats(uid, tierCode: tier);
});

final userDevicesProvider = FutureProvider<List<UserDevice>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  return uid == null ? const [] : ref.watch(accountRepositoryProvider).devices(uid);
});
