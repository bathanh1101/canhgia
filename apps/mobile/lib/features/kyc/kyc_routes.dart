import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/kyc_screen.dart';

/// `/kyc[?step=1|2|3]`; without `step` it resumes at the first incomplete step.
final List<RouteBase> kycRoutes = [
  GoRoute(
    path: RoutePaths.kyc,
    builder: (context, state) => KycScreen(initialStep: int.tryParse(state.uri.queryParameters['step'] ?? '')),
  ),
];
