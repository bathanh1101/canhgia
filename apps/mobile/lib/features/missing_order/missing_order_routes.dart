import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/missing_order_screen.dart';

final List<RouteBase> missingOrderRoutes = [
  GoRoute(path: RoutePaths.missingOrder, builder: (context, state) => const MissingOrderScreen()),
];
