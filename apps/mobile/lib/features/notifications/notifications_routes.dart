import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/notifications_screen.dart';

final List<RouteBase> notificationsRoutes = [
  GoRoute(path: RoutePaths.notifications, builder: (context, state) => const NotificationsScreen()),
];
