import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/auth/application/auth_controller.dart';
import 'package:canhgia_mobile/features/auth/data/auth_repository.dart';
import 'package:canhgia_mobile/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements AuthRepository {}

Widget _app(_MockRepo repo, {int bps = 2000}) => ProviderScope(
      key: UniqueKey(),
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        maxRateBpsProvider.overrideWith((ref) async => bps),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  testWidgets('Google tap with missing config shows the error toast', (t) async {
    final repo = _MockRepo();
    when(() => repo.signInWithGoogle()).thenThrow(const AppFailure('google_not_configured'));
    await t.pumpWidget(_app(repo));
    await t.pump();
    await t.tap(find.text('Tiếp tục với Google'));
    await t.pump();
    expect(find.text(errorMessagesVi['google_not_configured']!), findsOneWidget);
  });

  testWidgets('subtitle uses the live max rate; hidden when unknown', (t) async {
    await t.pumpWidget(_app(_MockRepo(), bps: 1250));
    await t.pump();
    expect(find.textContaining('tới 12,5% mỗi đơn'), findsOneWidget);
    await t.pumpWidget(_app(_MockRepo(), bps: 0));
    await t.pump();
    expect(find.textContaining('tới'), findsNothing);
  });

  testWidgets('phone, Facebook, Apple are disabled with a "Sắp có" badge', (t) async {
    await t.pumpWidget(_app(_MockRepo()));
    await t.pump();
    expect(find.text('Sắp có'), findsNWidgets(3));
  });
}
