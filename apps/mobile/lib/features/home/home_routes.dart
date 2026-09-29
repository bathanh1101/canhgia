import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import '../../core/widgets/placeholder_page.dart';

/// HANDOFF STUB from phase 04: replace the placeholder builders with the real screens.
/// Keep the exported list name; app/router.dart registers it.
final List<RouteBase> homeRoutes = [
  GoRoute(path: RoutePaths.home, builder: (context, state) => const PlaceholderPage('Trang chủ')),
];
