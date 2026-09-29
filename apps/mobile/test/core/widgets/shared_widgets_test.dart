import 'package:canhgia_mobile/app/theme/app_colors.dart';
import 'package:canhgia_mobile/core/models/wallet.dart';
import 'package:canhgia_mobile/core/widgets/async_value_view.dart';
import 'package:canhgia_mobile/core/widgets/balance_summary_card.dart';
import 'package:canhgia_mobile/core/widgets/money_text.dart';
import 'package:canhgia_mobile/core/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  testWidgets('MoneyText formats VND and optional plus sign', (t) async {
    await t.pumpWidget(_wrap(const Column(children: [MoneyText(1250000), MoneyText(454300, signed: true), MoneyText(-5, signed: true)])));
    expect(find.text('1.250.000đ'), findsOneWidget);
    expect(find.text('+454.300đ'), findsOneWidget);
    expect(find.text('-5đ'), findsOneWidget);
  });

  testWidgets('StatusPill maps order/withdrawal statuses', (t) async {
    const cases = {
      'pending': ('Chờ duyệt', AppColors.warning),
      'credited': ('Đã duyệt', AppColors.primary),
      'paid': ('Đã duyệt', AppColors.primary),
      'reversed': ('Bị hủy', AppColors.error),
      'cancelled': ('Bị hủy', AppColors.error),
      'checking': ('Đang kiểm tra', AppColors.info),
    };
    for (final e in cases.entries) {
      await t.pumpWidget(_wrap(StatusPill.forStatus(e.key)));
      expect(find.text(e.value.$1), findsOneWidget, reason: e.key);
      final text = t.widget<Text>(find.text(e.value.$1));
      expect(text.style!.color, e.value.$2, reason: e.key);
    }
  });

  testWidgets('BalanceSummaryCard shows available and awaiting (pending + held)', (t) async {
    const w = Wallet(availableVnd: 1000000, pendingVnd: 200000, heldVnd: 50000, totalEarnedVnd: 0);
    await t.pumpWidget(_wrap(const BalanceSummaryCard(wallet: w)));
    expect(find.text('1.000.000đ'), findsOneWidget);
    expect(find.text('Chờ duyệt 250.000đ'), findsOneWidget);
    await t.pumpWidget(_wrap(const BalanceSummaryCard(wallet: null)));
    expect(find.text('0đ'), findsOneWidget);
  });

  testWidgets('AsyncValueView shows retry with mapped error message', (t) async {
    var retried = false;
    await t.pumpWidget(_wrap(AsyncValueView<int>(
      value: AsyncError<int>(StateError('x'), StackTrace.empty),
      data: (_) => const Text('data'),
      onRetry: () => retried = true,
    )));
    expect(find.text('Đã có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
    await t.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });
}
