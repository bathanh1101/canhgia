import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'onboarding_screen.dart';

final List<RouteBase> onboardingRoutes = [
  GoRoute(path: RoutePaths.onboarding, builder: (context, state) => const OnboardingScreen()),
];
