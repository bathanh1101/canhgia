import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/home_screen.dart';

final List<RouteBase> homeRoutes = [
  GoRoute(path: RoutePaths.home, builder: (context, state) => const HomeScreen()),
];
