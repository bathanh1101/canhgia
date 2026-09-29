import 'route_paths.dart';

/// Pure auth/onboarding redirect rules (null = stay). Unit-tested.
/// - signed out: only login pages; first-time users go through onboarding.
/// - signed in: login/onboarding/root bounce to /home.
String? resolveRedirect({required String path, required bool signedIn, required bool onboarded}) {
  final isAuthPage = path == RoutePaths.login || path.startsWith('${RoutePaths.login}/');
  if (!signedIn) {
    if (isAuthPage) return null;
    if (path == RoutePaths.onboarding) return onboarded ? RoutePaths.login : null;
    return onboarded ? RoutePaths.login : RoutePaths.onboarding;
  }
  if (isAuthPage || path == RoutePaths.onboarding || path == '/') return RoutePaths.home;
  return null;
}

final _referralPath = RegExp(r'^/r/([^/]+)/?$');

/// Referral code when [path] is a `/r/<code>` deep link, else null.
String? referralCodeFromPath(String path) => _referralPath.firstMatch(path)?.group(1);

/// Auth-provider callback URIs (`io.canhgia.app://login-callback`) carry no page.
bool isAuthCallback(Uri uri) => uri.host == 'login-callback' || uri.path == '/login-callback';
