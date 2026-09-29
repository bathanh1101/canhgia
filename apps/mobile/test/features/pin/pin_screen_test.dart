import 'package:canhgia_mobile/core/security/biometric_pin_vault.dart';
import 'package:canhgia_mobile/features/pin/application/pin_controller.dart';
import 'package:canhgia_mobile/features/pin/application/pin_state.dart';
import 'package:canhgia_mobile/features/pin/data/pin_repository.dart';
import 'package:canhgia_mobile/features/pin/presentation/pin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements PinRepository {}

class _MockVault extends Mock implements BiometricPinVault {}

Widget _app(_MockRepo repo, _MockVault vault, PinArgs args, {String? hint, void Function(String?)? onResult}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (ctx, _) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final r = await ctx.push<String>('/pin');
            onResult?.call(r);
          },
          child: const Text('open'),
        ),
      ),
    ),
    GoRoute(path: '/pin', builder: (_, _) => PinScreen(args: args, hint: hint)),
  ]);
  return ProviderScope(
    overrides: [
      pinRepositoryProvider.overrideWithValue(repo),
      biometricPinVaultProvider.overrideWithValue(vault),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _open(WidgetTester t) async {
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> _digits(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.text(d));
    await t.pump();
  }
  await t.pumpAndSettle();
}

void main() {
  late _MockRepo repo;
  late _MockVault vault;
  setUp(() {
    repo = _MockRepo();
    vault = _MockVault();
    when(() => vault.isEnabled()).thenAnswer((_) async => false);
    when(() => vault.disable()).thenAnswer((_) async {});
  });

  testWidgets('verify: shows the hint, correct PIN pops the pin_token to the caller', (t) async {
    when(() => repo.verify('123456')).thenAnswer((_) async => const PinVerifyResult(ok: true, attemptsLeft: 5, pinToken: 'tok'));
    String? got;
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.verify, returnPin: false), hint: 'Xác nhận rút 500.000đ', onResult: (r) => got = r));
    await _open(t);
    expect(find.text('Nhập mã PIN'), findsOneWidget);
    expect(find.text('Xác nhận rút 500.000đ'), findsOneWidget);
    await _digits(t, '123456');
    expect(got, 'tok');
  });

  testWidgets('wrong PIN shows the attempts left message', (t) async {
    when(() => repo.verify(any())).thenAnswer((_) async => const PinVerifyResult(ok: false, attemptsLeft: 4));
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.verify, returnPin: false)));
    await _open(t);
    await _digits(t, '111111');
    expect(find.text('Sai PIN, còn 4 lần thử.'), findsOneWidget);
  });

  testWidgets('locked: countdown is shown and the keypad is disabled', (t) async {
    final until = DateTime.now().add(const Duration(minutes: 14, seconds: 30));
    when(() => repo.verify(any())).thenAnswer((_) async => PinVerifyResult(ok: false, attemptsLeft: 0, lockedUntil: until));
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.verify, returnPin: false)));
    await _open(t);
    await _digits(t, '111111');
    expect(find.textContaining('Tạm khóa đến'), findsOneWidget);
    expect(find.textContaining('thử lại sau 14:'), findsOneWidget);
    await t.tap(find.text('5'));
    await t.pump();
    verify(() => repo.verify(any())).called(1);
    // let the periodic countdown timer die with the widget tree
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('biometric button only when the vault is enabled, and it is not shown for return=pin', (t) async {
    when(() => vault.isEnabled()).thenAnswer((_) async => true);
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.verify, returnPin: false)));
    await _open(t);
    expect(find.text('Sinh trắc học'), findsOneWidget);
    expect(find.text('Quên mã PIN?'), findsOneWidget);

    await t.pumpWidget(_app(repo, vault, (mode: PinMode.verify, returnPin: true)));
    await _open(t);
    expect(find.text('Sinh trắc học'), findsNothing);
  });

  testWidgets('create asks for the PIN twice', (t) async {
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.create, returnPin: false)));
    await _open(t);
    expect(find.text('Tạo mã PIN'), findsOneWidget);
    await _digits(t, '135790');
    expect(find.text('Nhập lại mã PIN'), findsOneWidget);
  });

  testWidgets('reset explains the support path (no server reset exists)', (t) async {
    await t.pumpWidget(_app(repo, vault, (mode: PinMode.reset, returnPin: false)));
    await _open(t);
    expect(find.text('Quên mã PIN?'), findsOneWidget);
    expect(find.textContaining('liên hệ hỗ trợ'), findsOneWidget);
  });
}
