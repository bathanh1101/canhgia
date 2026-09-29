import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/email_otp_screen.dart';
import 'presentation/login_screen.dart';

final List<RouteBase> authRoutes = [
  GoRoute(
    path: RoutePaths.login,
    builder: (context, state) => const LoginScreen(),
    routes: [GoRoute(path: 'email-otp', builder: (context, state) => const EmailOtpScreen())],
  ),
];
