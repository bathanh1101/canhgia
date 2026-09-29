import 'package:canhgia_mobile/core/models/merchant.dart';
import 'package:canhgia_mobile/core/models/wallet.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/core/providers/profile_provider.dart';
import 'package:canhgia_mobile/core/providers/wallet_provider.dart';
import 'package:canhgia_mobile/features/orders/application/orders_providers.dart';
import 'package:canhgia_mobile/features/orders/data/order.dart';
import 'package:canhgia_mobile/features/wallet/application/wallet_providers.dart';
import 'package:canhgia_mobile/features/wallet/data/ledger_entry.dart';
import 'package:canhgia_mobile/features/wallet/presentation/wallet_screen.dart';
import 'package:canhgia_mobile/features/withdraw/application/withdraw_providers.dart';
import 'package:canhgia_mobile/features/withdraw/data/bank_models.dart';
import 'package:canhgia_mobile/features/withdraw/data/withdrawal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final _now = DateTime(2026, 10, 5, 12);

const _wallet = Wallet(availableVnd: 1250000, pendingVnd: 120000, heldVnd: 200000, totalEarnedVnd: 4860000);

Merchant _m(String id, String name, String letter) =>
    Merchant(id: id, name: name, badgeLetter: letter, domains: const [], maxUserRateBps: 0, datafeedEnabled: false, extensionEnabled: false);

Order _order(String id, String name, String state, {DateTime? due, int cashback = 100000}) => Order(
      id: id,
      merchantId: 'shopee',
      productName: name,
      valueVnd: 2000000,
      cashbackVnd: cashback,
      creditState: state,
      orderTime: DateTime(2026, 9, 28, 10),
      withdrawableAt: due,
    );

Widget _app({Wallet? wallet = _wallet, List<Order>? orders, List<OrdersQuery>? queries, List<LedgerEntry> ledger = const []}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => WalletScreen(now: _now)),
    GoRoute(path: '/withdraw', builder: (_, _) => const Text('WITHDRAW-PAGE')),
    GoRoute(path: '/orders/:id', builder: (_, s) => Text('ORDER-${s.pathParameters['id']}')),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      walletProvider.overrideWith((ref) => Stream.value(wallet)),
      profileProvider.overrideWith((ref) async => null),
      defaultBankAccountProvider.overrideWith((ref) async => const BankAccount(id: 'b', bankBin: '970436', accountNumber: '0071006789', accountName: 'A', isDefault: true)),
      banksProvider.overrideWith((ref) async => const [Bank(bin: '970436', code: 'VCB', name: 'Vietcombank', isEnabled: true)]),
      publicSettingsProvider.overrideWith((ref) async => const PublicSettings()),
      merchantsProvider.overrideWith((ref) async => [_m('shopee', 'Shopee', 'S')]),
      creditedOrderCountProvider.overrideWith((ref) async => 58),
      ordersProvider.overrideWith((ref, q) async {
        queries?.add(q);
        final all = orders ?? const [];
        final states = q.tab.creditStates;
        return states == null ? all : all.where((o) => states.contains(o.creditState)).toList();
      }),
      ledgerProvider.overrideWith((ref, limit) async => ledger),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void _tall(WidgetTester t) {
  t.view.physicalSize = const Size(800, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('three numbers: available, awaiting (pending + held) and total refunded with order count', (t) async {
    _tall(t);
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.text('1.250.000đ'), findsOneWidget);
    expect(find.text('320.000đ'), findsOneWidget); // 120.000 + 200.000
    expect(find.text('Chờ sàn 120.000đ · Đang giữ 200.000đ'), findsOneWidget);
    expect(find.text('4.860.000đ'), findsOneWidget);
    expect(find.text('Từ 58 đơn hàng'), findsOneWidget);
    expect(find.text('Vietcombank •••• 6789'), findsOneWidget);
  });

  testWidgets('footnote explains the hold and the min withdraw amount', (t) async {
    _tall(t);
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    expect(find.textContaining('Rút tối thiểu 50.000đ'), findsOneWidget);
    expect(find.textContaining('chuyển sang khả dụng khi hết hạn đổi trả'), findsOneWidget);
    expect(find.textContaining('thường 30 ngày'), findsOneWidget);
  });

  testWidgets('no wallet row yet renders zeros', (t) async {
    _tall(t);
    await t.pumpWidget(_app(wallet: null));
    await t.pumpAndSettle();
    expect(find.text('0đ'), findsWidgets);
  });

  testWidgets('Rút tiền opens /withdraw', (t) async {
    _tall(t);
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    await t.tap(find.text('Rút tiền'));
    await t.pumpAndSettle();
    expect(find.text('WITHDRAW-PAGE'), findsOneWidget);
  });

  testWidgets('orders: status pills, hold chip for credited-but-held, tabs filter, tap opens detail', (t) async {
    _tall(t);
    final orders = [
      _order('a', 'Tai nghe Sony', 'pending', cashback: 454300),
      _order('b', 'Nồi chiên Philips', 'credited', due: DateTime(2026, 10, 21)),
      _order('c', 'Khách sạn Đà Nẵng', 'reversed'),
    ];
    await t.pumpWidget(_app(orders: orders));
    await t.pumpAndSettle();
    expect(find.text('Tai nghe Sony'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsWidgets); // pill + tab + card title
    expect(find.text('Đã duyệt'), findsWidgets);
    expect(find.text('khả dụng từ 21/10'), findsOneWidget);
    expect(find.text('+454.300đ'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Bị hủy'));
    await t.pumpAndSettle();
    expect(find.text('Khách sạn Đà Nẵng'), findsOneWidget);
    expect(find.text('Tai nghe Sony'), findsNothing);

    await t.tap(find.text('Khách sạn Đà Nẵng'));
    await t.pumpAndSettle();
    expect(find.text('ORDER-c'), findsOneWidget);
  });

  testWidgets('month picker and tabs drive the provider query', (t) async {
    _tall(t);
    final queries = <OrdersQuery>[];
    await t.pumpWidget(_app(queries: queries));
    await t.pumpAndSettle();
    expect(queries.last.month, DateTime(2026, 10));
    expect(queries.last.tab, OrderTab.all);
    await t.tap(find.text('Tháng 10 ▾'));
    await t.pumpAndSettle();
    await t.tap(find.text('Tháng 9/2026'));
    await t.pumpAndSettle();
    expect(queries.last.month, DateTime(2026, 9));
    await t.tap(find.widgetWithText(ChoiceChip, 'Đã duyệt'));
    await t.pumpAndSettle();
    expect(queries.last.tab, OrderTab.approved);
    expect(find.text('Chưa có đơn hàng trong tháng này.'), findsOneWidget);
  });

  testWidgets('ledger view lists movements with the hold note', (t) async {
    _tall(t);
    final ledger = [
      LedgerEntry(id: 2, entryType: 'withdrawal_debit', amountVnd: -500000, createdAt: DateTime(2026, 10, 4, 16, 2)),
      LedgerEntry(id: 1, entryType: 'cashback_credit', amountVnd: 131400, createdAt: DateTime(2026, 10, 1), availableAt: DateTime(2026, 10, 31)),
    ];
    await t.pumpWidget(_app(ledger: ledger));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Đổi chế độ xem'));
    await t.pumpAndSettle();
    expect(find.text('Biến động số dư'), findsOneWidget);
    expect(find.text('Rút tiền'), findsWidgets);
    expect(find.text('-500.000đ'), findsOneWidget);
    expect(find.text('+131.400đ'), findsOneWidget);
    expect(find.text('khả dụng từ 31/10'), findsOneWidget);
  });
}
