import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'data/search_repository.dart';
import 'presentation/search_results_screen.dart';
import 'presentation/search_screen.dart';

final List<RouteBase> searchRoutes = [
  GoRoute(path: RoutePaths.search, builder: (context, state) => const SearchScreen()),
  GoRoute(
    path: RoutePaths.searchResults,
    builder: (context, state) {
      final p = state.uri.queryParameters;
      return SearchResultsScreen(
        // Key on the query so replace() with new filters rebuilds the paging state.
        key: ValueKey(state.uri.toString()),
        args: (q: (p['q'] ?? '').trim(), merchant: p['m'] ?? '', sort: searchSorts.containsKey(p['sort']) ? p['sort']! : 'relevance'),
      );
    },
  ),
];
