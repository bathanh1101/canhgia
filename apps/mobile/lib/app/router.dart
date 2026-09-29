import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_session_provider.dart';
import '../core/providers/referral_store.dart';
import '../core/widgets/placeholder_page.dart';
import '../features/account/account_routes.dart';
import '../features/auth/auth_routes.dart';
import '../features/compare/compare_routes.dart';
import '../features/home/home_routes.dart';
import '../features/kyc/kyc_routes.dart';
import '../features/link/link_routes.dart';
import '../features/missing_order/missing_order_routes.dart';
import '../features/notifications/notifications_routes.dart';
import '../features/onboarding/onboarding_routes.dart';
import '../features/onboarding/onboarding_seen_provider.dart';
import '../features/orders/orders_routes.dart';
import '../features/pin/pin_routes.dart';
import '../features/price_history/price_history_routes.dart';
import '../features/rewards/rewards_routes.dart';
import '../features/search/search_routes.dart';
import '../features/vouchers/vouchers_routes.dart';
import '../features/wallet/wallet_routes.dart';
import '../features/watchlist/watchlist_routes.dart';
import '../features/withdraw/withdraw_routes.dart';
import 'route_paths.dart';
import 'router_redirect.dart';
import 'shell/main_shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the session or onboarding flag changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(isSignedInProvider, (_, _) => refresh.value++);
  ref.listen(onboardingSeenProvider, (_, _) => refresh.value++);

  final router = GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: refresh,
    errorBuilder: (context, state) => const PlaceholderPage('Không tìm thấy trang'),
    redirect: (context, state) {
      final uri = state.uri;
      final code = referralCodeFromPath(uri.path);
      if (code != null) {
        ref.read(referralStoreProvider).save(code);
        return RoutePaths.home;
      }
      if (isAuthCallback(uri)) return RoutePaths.home;
      return resolveRedirect(
        path: uri.path,
        signedIn: ref.read(isSignedInProvider),
        onboarded: ref.read(onboardingSeenProvider),
      );
    },
    routes: [
      ...onboardingRoutes,
      ...authRoutes,
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShellScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: homeRoutes),
          StatefulShellBranch(routes: vouchersRoutes),
          StatefulShellBranch(routes: walletRoutes),
          StatefulShellBranch(routes: rewardsRoutes),
          StatefulShellBranch(routes: accountRoutes),
        ],
      ),
      // Full-screen routes above the tab bar.
      ...linkRoutes,
      ...searchRoutes,
      ...compareRoutes,
      ...priceHistoryRoutes,
      ...watchlistRoutes,
      ...ordersRoutes,
      ...withdrawRoutes,
      ...pinRoutes,
      ...missingOrderRoutes,
      ...kycRoutes,
      ...notificationsRoutes,
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
