import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_identity_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/search_repository.dart';

const searchPageSize = 20;

final searchRepositoryProvider = Provider<SearchRepository>((ref) => SearchRepository(ref.watch(supabaseProvider)));

final recentSearchStoreProvider =
    Provider<RecentSearchStore>((ref) => RecentSearchStore(ref.watch(sharedPreferencesProvider)));

class RecentSearches extends Notifier<List<String>> {
  @override
  List<String> build() => ref.watch(recentSearchStoreProvider).read();

  Future<void> add(String q) async => state = await ref.read(recentSearchStoreProvider).add(q);
  Future<void> remove(String q) async => state = await ref.read(recentSearchStoreProvider).remove(q);

  Future<void> clear() async {
    await ref.read(recentSearchStoreProvider).clear();
    state = const [];
  }
}

final recentSearchesProvider = NotifierProvider<RecentSearches, List<String>>(RecentSearches.new);

/// Top 5 hits for the typed text (callers debounce); < 2 chars -> nothing.
final searchSuggestionsProvider = FutureProvider.family<List<OfferHit>, String>((ref, q) async {
  if (q.trim().length < 2) return const [];
  return ref.watch(searchRepositoryProvider).search((q: q.trim(), merchant: '', sort: 'relevance'), limit: 5);
});

class PagedOffers {
  const PagedOffers({this.items = const [], this.hasMore = true, this.loadingMore = false, this.loadMoreFailed = false});

  final List<OfferHit> items;
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  PagedOffers copyWith({List<OfferHit>? items, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) => PagedOffers(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );

  /// Appends [page] (dropping offers already shown); a short page means the end.
  PagedOffers appended(List<OfferHit> page, {int pageSize = searchPageSize}) {
    final seen = {for (final o in items) o.offerId};
    return PagedOffers(items: [...items, for (final o in page) if (seen.add(o.offerId)) o], hasMore: page.length >= pageSize);
  }
}

class SearchResults extends AsyncNotifier<PagedOffers> {
  SearchResults(this.args);
  final SearchArgs args;

  @override
  Future<PagedOffers> build() async =>
      const PagedOffers().appended(await ref.watch(searchRepositoryProvider).search(args, limit: searchPageSize));

  Future<void> loadMore() async {
    final cur = state.value;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await ref
          .read(searchRepositoryProvider)
          .search(args, limit: searchPageSize, offset: cur.items.length);
      state = AsyncData(cur.appended(page));
    } on Object {
      state = AsyncData(cur.copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }
}

final searchResultsProvider = AsyncNotifierProvider.family<SearchResults, PagedOffers, SearchArgs>(SearchResults.new);
