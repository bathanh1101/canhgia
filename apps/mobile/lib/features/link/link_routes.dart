import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import '../home/data/link_models.dart';
import 'presentation/link_created_screen.dart';

final List<RouteBase> linkRoutes = [
  GoRoute(
    path: RoutePaths.link,
    builder: (context, state) {
      final extra = state.extra;
      return LinkCreatedScreen(link: extra is CreatedLink ? extra : null);
    },
  ),
];
