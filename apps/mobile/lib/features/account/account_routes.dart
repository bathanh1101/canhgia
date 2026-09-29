import 'package:go_router/go_router.dart';

import '../../app/route_paths.dart';
import 'presentation/account_screen.dart';
import 'presentation/devices_screen.dart';
import 'presentation/extension_login_confirm_screen.dart';
import 'presentation/extension_login_scan_screen.dart';
import 'presentation/notification_settings_screen.dart';
import 'presentation/personal_info_screen.dart';

final List<RouteBase> accountRoutes = [
  GoRoute(
    path: RoutePaths.account,
    builder: (context, state) => const AccountScreen(),
    routes: [
      GoRoute(path: 'info', builder: (context, state) => const PersonalInfoScreen()),
      GoRoute(path: 'devices', builder: (context, state) => const DevicesScreen()),
      GoRoute(path: 'notification-settings', builder: (context, state) => const NotificationSettingsScreen()),
      GoRoute(
        path: 'extension-login',
        builder: (context, state) => const ExtensionLoginScanScreen(),
        routes: [
          GoRoute(
            path: 'confirm',
            builder: (context, state) => ExtensionLoginConfirmScreen(code: state.uri.queryParameters['code']),
          ),
        ],
      ),
    ],
  ),
];
