import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import '../../core/widgets/placeholder_page.dart';

/// HANDOFF STUB from phase 04: replace the placeholder builders with the real screens.
/// Keep the exported list name; app/router.dart registers it.
final List<RouteBase> searchRoutes = [
  GoRoute(path: RoutePaths.search, builder: (context, state) => const PlaceholderPage('Tìm kiếm')),
  GoRoute(path: RoutePaths.searchResults, builder: (context, state) => const PlaceholderPage('Kết quả tìm kiếm')),
];
