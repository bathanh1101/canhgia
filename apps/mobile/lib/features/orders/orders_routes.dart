import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/order_detail_screen.dart';

final List<RouteBase> ordersRoutes = [
  GoRoute(
    path: RoutePaths.orderDetail,
    builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id'] ?? ''),
  ),
];
