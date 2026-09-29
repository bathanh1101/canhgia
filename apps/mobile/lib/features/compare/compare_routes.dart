import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/compare_screen.dart';

final List<RouteBase> compareRoutes = [
  GoRoute(
    path: RoutePaths.compare,
    builder: (context, state) => CompareScreen(groupId: state.pathParameters['groupId'] ?? ''),
  ),
];
