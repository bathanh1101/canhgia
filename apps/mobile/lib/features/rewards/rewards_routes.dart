import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/rewards_screen.dart';

final List<RouteBase> rewardsRoutes = [
  GoRoute(path: RoutePaths.rewards, builder: (context, state) => const RewardsScreen()),
];
