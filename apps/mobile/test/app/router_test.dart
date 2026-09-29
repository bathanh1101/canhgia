import 'package:canhgia_mobile/app/router.dart';
import 'package:canhgia_mobile/app/route_paths.dart';
import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/features/auth/presentation/login_screen.dart';
import 'package:canhgia_mobile/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SignedIn extends Notifier<bool> {
  @override
  bool build() => false;
  // ignore: use_setters_to_change_properties
  void set(bool v) => state = v;
}

final _signedInFlag = NotifierProvider<_SignedIn, bool>(_SignedIn.new);

Future<ProviderContainer> _pump(WidgetTester t, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(sp),
    isSignedInProvider.overrideWith((ref) => ref.watch(_signedInFlag)),
    isAccountLockedProvider.overrideWith((ref) => false),
    maxRateBpsProvider.overrideWith((ref) async => 2000),
  ]);
  addTearDown(c.dispose);
  await t.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: Consumer(builder: (context, ref, _) => MaterialApp.router(routerConfig: ref.watch(routerProvider))),
  ));
  await t.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('first launch shows onboarding, "Bắt đầu ngay" leads to login', (t) async {
    await _pump(t);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    await t.tap(find.text('Bắt đầu ngay'));
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.textContaining('tới 20%'), findsOneWidget);
  });

  testWidgets('onboarded + signed out lands on login', (t) async {
    await _pump(t, prefs: {'onboarding_seen_v1': true});
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(find.text('Sắp có'), findsNWidgets(3));
  });

  testWidgets('signing in moves to the shell (tabs), signing out returns to login', (t) async {
    final c = await _pump(t, prefs: {'onboarding_seen_v1': true});
    c.read(_signedInFlag.notifier).set(true);
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Tài khoản'), findsWidgets); // bottom nav
    expect(find.text('Trang chủ'), findsWidgets);
    c.read(_signedInFlag.notifier).set(false);
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('referral deep link stores the code and continues to login', (t) async {
    final c = await _pump(t, prefs: {'onboarding_seen_v1': true});
    c.read(routerProvider).go('${RoutePaths.referralPrefix}abc12345');
    await t.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('pending_referral_code'), 'ABC12345');
  });

  testWidgets('malformed referral code is not stored', (t) async {
    final c = await _pump(t, prefs: {'onboarding_seen_v1': true});
    c.read(routerProvider).go('/r/bad%20code!');
    await t.pumpAndSettle();
    expect((await SharedPreferences.getInstance()).getString('pending_referral_code'), isNull);
  });

  testWidgets('feature routes are registered (match, never the not-found page)', (t) async {
    final c = await _pump(t, prefs: {'onboarding_seen_v1': true});
    final config = c.read(routerProvider).configuration;
    for (final path in [RoutePaths.withdraw, RoutePaths.search, RoutePaths.searchResults, '/orders/1', RoutePaths.notifications, RoutePaths.pin]) {
      expect(config.findMatch(Uri.parse(path)).isError, isFalse, reason: path);
    }
  });
}
