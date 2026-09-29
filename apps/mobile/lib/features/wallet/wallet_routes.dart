import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/wallet_screen.dart';

final List<RouteBase> walletRoutes = [
  GoRoute(path: RoutePaths.wallet, builder: (context, state) => const WalletScreen()),
];
