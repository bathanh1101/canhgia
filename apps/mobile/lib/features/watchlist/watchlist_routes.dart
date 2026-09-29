import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/watchlist_screen.dart';

final List<RouteBase> watchlistRoutes = [
  GoRoute(path: RoutePaths.watchlist, builder: (context, state) => const WatchlistScreen()),
];
