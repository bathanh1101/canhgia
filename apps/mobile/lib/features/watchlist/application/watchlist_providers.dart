import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_session_provider.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../compare/application/compare_providers.dart';
import '../../compare/data/compare_repository.dart';
import '../../price_history/application/price_history_providers.dart';
import '../../price_history/data/price_history_repository.dart';
import '../data/watchlist_repository.dart';

final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) => WatchlistRepository(ref.watch(supabaseProvider)));

/// Watch row + current price. [currentVnd] = cheapest effective price (after cashback) when the group is
/// comparable, else the cheapest listed price; null when the group has no priced offer.
class WatchEntry {
  const WatchEntry({required this.item, this.info, this.currentVnd});
  final WatchItem item;
  final GroupInfo? info;
  final int? currentVnd;

  bool get reached => currentVnd != null && currentVnd! <= item.targetPriceVnd;

  /// Percent above (+) or below (-) the target; null when unknown.
  int? get gapPercent => currentVnd == null ? null : ((currentVnd! - item.targetPriceVnd) * 100 / item.targetPriceVnd).round();
}

/// The user's watch row for one group (null = not watching).
final watchItemProvider = FutureProvider.family<WatchItem?, String>((ref, groupId) async {
  final uid = ref.watch(currentUserIdProvider);
  final id = int.tryParse(groupId);
  return uid == null || id == null ? null : ref.watch(watchlistRepositoryProvider).find(uid, id);
});

final watchlistProvider = FutureProvider<List<WatchEntry>>((ref) async {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const [];
  final items = await ref.watch(watchlistRepositoryProvider).list(uid);
  final infos = await ref.watch(priceHistoryRepositoryProvider).groupInfos([for (final i in items) i.groupId]);
  final compare = ref.watch(compareRepositoryProvider);
  return Future.wait([
    for (final i in items)
      () async {
        final info = infos[i.groupId];
        var offers = const <CompareOffer>[];
        try {
          offers = await compare.compare(i.groupId);
        } on Object {
          // Comparison is an enhancement: fall back to the cheapest listed price.
        }
        final best = cheapestOffer(offers);
        return WatchEntry(item: i, info: info, currentVnd: best?.effectivePriceVnd ?? info?.priceVnd);
      }(),
  ]);
});

/// Writes that keep list + per-group providers in sync.
class WatchlistActions {
  WatchlistActions(this._ref);
  final Ref _ref;

  void _refresh(int groupId) {
    _ref.invalidate(watchlistProvider);
    _ref.invalidate(watchItemProvider('$groupId'));
  }

  Future<void> setTarget(int groupId, int targetVnd) async {
    final uid = _ref.read(currentUserIdProvider);
    if (uid == null) return;
    await _ref.read(watchlistRepositoryProvider).setTarget(uid, groupId, targetVnd);
    _refresh(groupId);
  }

  Future<void> remove(WatchItem item) async {
    await _ref.read(watchlistRepositoryProvider).remove(item.id);
    _refresh(item.groupId);
  }
}

final watchlistActionsProvider = Provider<WatchlistActions>(WatchlistActions.new);
