import 'package:canhgia_mobile/app/route_paths.dart';
import 'package:canhgia_mobile/core/models/profile.dart';
import 'package:canhgia_mobile/core/models/wallet.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/core/providers/wallet_provider.dart';
import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_providers.dart';
import 'package:canhgia_mobile/features/withdraw/data/bank_models.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdraw_repository.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdrawal.dart';
import 'package:canhgia_mobile/features/withdraw/presentation/withdraw_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements WithdrawRepository {}

final _now = DateTime.utc(2026, 10, 5, 12);
const _bank = BankAccount(id: 'b1', bankBin: '970436', accountNumber: '0071001236789', accountName: 'NGUYEN VAN MINH', isDefault: true);
const _vcb = Bank(bin: '970436', code: 'VCB', name: 'Vietcombank', isEnabled: true);

Widget _app(
  _MockRepo repo, {
  List<BankAccount> accounts = const [_bank],
  DateTime? holdUntil,
  int available = 1250000,
  String pinResult = 'tok-1',
  List<Withdrawal> recent = const [],
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => WithdrawScreen(now: _now)),
    GoRoute(
      path: RoutePaths.pin,
      builder: (_, s) => Scaffold(
        body: Column(children: [
          Text('PIN:${s.extra}'),
          Builder(builder: (ctx) => TextButton(onPressed: () => ctx.pop(pinResult), child: const Text('ok-pin'))),
        ]),
      ),
    ),
    GoRoute(path: RoutePaths.kyc, builder: (_, _) => const Text('KYC-PAGE')),
  ]);
  return ProviderScope(
    overrides: [
      withdrawRepositoryProvider.overrideWithValue(repo),
      walletProvider.overrideWith((ref) => Stream.value(Wallet(availableVnd: available, pendingVnd: 0, heldVnd: 0, totalEarnedVnd: 0))),
      profileProvider.overrideWith((ref) async => Profile(id: 'u', referralCode: 'X', withdrawalHoldUntil: holdUntil)),
      bankAccountsProvider.overrideWith((ref) async => accounts),
      banksProvider.overrideWith((ref) async => [_vcb]),
      publicSettingsProvider.overrideWith((ref) async => const PublicSettings()),
      withdrawalsProvider.overrideWith((ref) async => recent),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _type(WidgetTester t, String amount) async {
  await t.enterText(find.byType(TextField), amount);
  await t.pump();
}

void main() {
  testWidgets('shows balance, bank and quick chips; net equals the typed amount', (t) async {
    await t.pumpWidget(_app(_MockRepo()));
    await t.pumpAndSettle();
    expect(find.text('Khả dụng: 1.250.000đ'), findsOneWidget);
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('500K'), findsOneWidget);
    expect(find.text('Tất cả'), findsOneWidget);
    await t.tap(find.text('500K'));
    await t.pump();
    expect(find.text('500.000đ'), findsOneWidget); // Thực nhận
  });

  testWidgets('amount validation hints: below minimum and above balance', (t) async {
    await t.pumpWidget(_app(_MockRepo(), available: 200000));
    await t.pumpAndSettle();
    await _type(t, '10000');
    expect(find.textContaining('tối thiểu 50.000đ'), findsWidgets);
    await _type(t, '300000');
    expect(find.text('Số dư khả dụng không đủ.'), findsOneWidget);
  });

  testWidgets('daily cap: history is watched so the remaining cap is enforced client-side', (t) async {
    final used = Withdrawal(
        id: 'w0', amount: 4900000, status: 'pending', bankBin: '970436', accountNumber: '1', createdAt: _now.subtract(const Duration(hours: 1)));
    await t.pumpWidget(_app(_MockRepo(), available: 3000000, recent: [used]));
    await t.pumpAndSettle();
    await _type(t, '200000');
    expect(find.textContaining('100.000đ'), findsWidgets); // remaining 5.000.000 - 4.900.000
  });

  testWidgets('hold banner disables the confirm button', (t) async {
    await t.pumpWidget(_app(_MockRepo(), holdUntil: _now.add(const Duration(hours: 5))));
    await t.pumpAndSettle();
    expect(find.textContaining('tạm giữ rút tiền đến'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.ancestor(of: find.text('Xác nhận rút tiền'), matching: find.byType(FilledButton)));
    expect(btn.onPressed, isNull);
  });

  testWidgets('no bank account: CTA goes to KYC', (t) async {
    await t.pumpWidget(_app(_MockRepo(), accounts: const []));
    await t.pumpAndSettle();
    await t.tap(find.text('Xác thực & liên kết ngân hàng'));
    await t.pumpAndSettle();
    expect(find.text('KYC-PAGE'), findsOneWidget);
  });

  testWidgets('confirm -> PIN token -> request_withdrawal (same key on retry) -> result view', (t) async {
    final repo = _MockRepo();
    final keys = <String>[];
    var calls = 0;
    when(() => repo.withdrawalByKey(any())).thenAnswer((_) async => null);
    when(() => repo.request(
          requestKey: any(named: 'requestKey'),
          amount: any(named: 'amount'),
          bankAccountId: any(named: 'bankAccountId'),
          pinToken: any(named: 'pinToken'),
        )).thenAnswer((inv) async {
      keys.add(inv.namedArguments[#requestKey] as String);
      if (++calls == 1) throw const AppFailure('network');
      return (id: 'w-9', status: 'pending');
    });
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await _type(t, '100000');

    await t.tap(find.text('Xác nhận rút tiền'));
    await t.pumpAndSettle();
    expect(find.textContaining('Xác nhận rút 100.000đ về tài khoản Vietcombank'), findsOneWidget);
    await t.tap(find.text('ok-pin'));
    await t.pumpAndSettle();
    expect(find.text(errorMessagesVi['network']!), findsOneWidget); // first attempt failed, form still shown

    await t.tap(find.text('Xác nhận rút tiền'));
    await t.pumpAndSettle();
    await t.tap(find.text('ok-pin'));
    await t.pumpAndSettle();
    expect(keys.length, 2);
    expect(keys.first, keys.last);
    expect(find.text('Đã gửi yêu cầu rút tiền'), findsOneWidget);
    verify(() => repo.request(requestKey: keys.first, amount: 100000, bankAccountId: 'b1', pinToken: 'tok-1')).called(2);
  });

  testWidgets('server error (daily_cap) shows the mapped message', (t) async {
    final repo = _MockRepo();
    when(() => repo.request(
          requestKey: any(named: 'requestKey'),
          amount: any(named: 'amount'),
          bankAccountId: any(named: 'bankAccountId'),
          pinToken: any(named: 'pinToken'),
        )).thenThrow(const AppFailure('daily_cap'));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await _type(t, '100000');
    await t.tap(find.text('Xác nhận rút tiền'));
    await t.pumpAndSettle();
    await t.tap(find.text('ok-pin'));
    await t.pumpAndSettle();
    expect(find.text(errorMessagesVi['daily_cap']!), findsOneWidget);
  });

  testWidgets('cancelling the PIN sheet sends nothing', (t) async {
    final repo = _MockRepo();
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await _type(t, '100000');
    await t.tap(find.text('Xác nhận rút tiền'));
    await t.pumpAndSettle();
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    await t.pumpAndSettle();
    verifyNever(() => repo.request(
          requestKey: any(named: 'requestKey'),
          amount: any(named: 'amount'),
          bankAccountId: any(named: 'bankAccountId'),
          pinToken: any(named: 'pinToken'),
        ));
  });
}
