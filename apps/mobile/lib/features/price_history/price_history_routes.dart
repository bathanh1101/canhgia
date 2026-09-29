import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/price_history_screen.dart';

final List<RouteBase> priceHistoryRoutes = [
  GoRoute(
    path: RoutePaths.priceHistory,
    builder: (context, state) => PriceHistoryScreen(groupId: state.pathParameters['groupId'] ?? ''),
  ),
];
