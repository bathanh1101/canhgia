import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/withdraw_screen.dart';
import 'presentation/withdrawal_history_screen.dart';

final List<RouteBase> withdrawRoutes = [
  GoRoute(
    path: RoutePaths.withdraw,
    builder: (context, state) => const WithdrawScreen(),
    routes: [GoRoute(path: 'history', builder: (context, state) => const WithdrawalHistoryScreen())],
  ),
];
