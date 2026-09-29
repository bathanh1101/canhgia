import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'application/pin_state.dart';
import 'presentation/pin_screen.dart';

/// `/pin?mode=verify|create|change|reset[&return=pin]`; `extra` (String) = verify subtitle.
final List<RouteBase> pinRoutes = [
  GoRoute(
    path: RoutePaths.pin,
    builder: (context, state) {
      final q = state.uri.queryParameters;
      final extra = state.extra;
      return PinScreen(
        args: (mode: PinMode.parse(q['mode']), returnPin: q['return'] == 'pin'),
        hint: extra is String ? extra : null,
      );
    },
  ),
];
