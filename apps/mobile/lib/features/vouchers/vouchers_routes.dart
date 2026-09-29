import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/vouchers_screen.dart';

final List<RouteBase> vouchersRoutes = [
  GoRoute(path: RoutePaths.vouchers, builder: (context, state) => const VouchersScreen()),
];
