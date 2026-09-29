import 'package:canhgia_mobile/app/app.dart';
import 'package:canhgia_mobile/core/device/device_identity_service.dart';
import 'package:canhgia_mobile/core/providers/auth_session_provider.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/features/notifications/application/push_registration.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app tree hosts ForegroundPushListener above the routed pages', (t) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await t.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        isSignedInProvider.overrideWith((ref) => false),
        isAccountLockedProvider.overrideWith((ref) => false),
        maxRateBpsProvider.overrideWith((ref) async => 2000),
      ],
      child: const CanhGiaApp(),
    ));
    await t.pumpAndSettle();
    expect(find.byType(ForegroundPushListener), findsOneWidget);
  });
}
