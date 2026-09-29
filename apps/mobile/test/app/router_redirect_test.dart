import 'package:canhgia_mobile/app/route_paths.dart';
import 'package:canhgia_mobile/app/router_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? r(String path, {required bool signedIn, required bool onboarded}) =>
      resolveRedirect(path: path, signedIn: signedIn, onboarded: onboarded);

  group('signed out', () {
    test('first launch -> onboarding from anywhere', () {
      expect(r('/home', signedIn: false, onboarded: false), RoutePaths.onboarding);
      expect(r('/wallet', signedIn: false, onboarded: false), RoutePaths.onboarding);
    });
    test('onboarding page itself is allowed before onboarding', () {
      expect(r(RoutePaths.onboarding, signedIn: false, onboarded: false), isNull);
    });
    test('after onboarding -> login', () {
      expect(r('/home', signedIn: false, onboarded: true), RoutePaths.login);
      expect(r('/account/devices', signedIn: false, onboarded: true), RoutePaths.login);
      expect(r(RoutePaths.onboarding, signedIn: false, onboarded: true), RoutePaths.login);
    });
    test('login pages are reachable, with or without onboarding', () {
      for (final onboarded in [true, false]) {
        expect(r(RoutePaths.login, signedIn: false, onboarded: onboarded), isNull);
        expect(r(RoutePaths.loginEmailOtp, signedIn: false, onboarded: onboarded), isNull);
      }
    });
  });

  group('signed in', () {
    test('auth pages, onboarding and root bounce to home', () {
      for (final p in [RoutePaths.login, RoutePaths.loginEmailOtp, RoutePaths.onboarding, '/']) {
        expect(r(p, signedIn: true, onboarded: true), RoutePaths.home, reason: p);
        expect(r(p, signedIn: true, onboarded: false), RoutePaths.home, reason: p);
      }
    });
    test('app pages stay put', () {
      for (final p in [RoutePaths.home, RoutePaths.wallet, '/orders/123', RoutePaths.pin, RoutePaths.accountExtensionConfirm]) {
        expect(r(p, signedIn: true, onboarded: true), isNull, reason: p);
      }
    });
  });

  test('referralCodeFromPath', () {
    expect(referralCodeFromPath('/r/ABC12345'), 'ABC12345');
    expect(referralCodeFromPath('/r/ABC12345/'), 'ABC12345');
    expect(referralCodeFromPath('/r/'), isNull);
    expect(referralCodeFromPath('/r/a/b'), isNull);
    expect(referralCodeFromPath('/home'), isNull);
  });

  test('isAuthCallback', () {
    expect(isAuthCallback(Uri.parse('io.canhgia.app://login-callback')), isTrue);
    expect(isAuthCallback(Uri.parse('io.canhgia.app://login-callback?code=x')), isTrue);
    expect(isAuthCallback(Uri.parse('https://canhgia.vn/login-callback')), isTrue);
    expect(isAuthCallback(Uri.parse('/wallet')), isFalse);
  });
}
