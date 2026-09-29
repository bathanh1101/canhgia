import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/price_history_repository.dart';

final priceHistoryRepositoryProvider =
    Provider<PriceHistoryRepository>((ref) => PriceHistoryRepository(ref.watch(supabaseProvider)));

/// (groupId, days) -> daily min price across shops.
final priceHistoryProvider = FutureProvider.family<List<PricePoint>, (String, int)>((ref, key) async {
  final id = int.tryParse(key.$1);
  return id == null ? const [] : ref.watch(priceHistoryRepositoryProvider).history(id, key.$2);
});

final groupInfoProvider = FutureProvider.family<GroupInfo?, String>((ref, groupId) async {
  final id = int.tryParse(groupId);
  if (id == null) return null;
  return (await ref.watch(priceHistoryRepositoryProvider).groupInfos([id]))[id];
});
