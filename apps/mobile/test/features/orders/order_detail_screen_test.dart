import 'package:canhgia_mobile/core/models/merchant.dart';
import 'package:canhgia_mobile/core/providers/merchants_provider.dart';
import 'package:canhgia_mobile/features/orders/application/orders_providers.dart';
import 'package:canhgia_mobile/features/orders/data/order.dart';
import 'package:canhgia_mobile/features/orders/presentation/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _shopee = Merchant(
  id: 'shopee',
  name: 'Shopee',
  badgeLetter: 'S',
  domains: ['shopee.vn'],
  maxUserRateBps: 100,
  datafeedEnabled: true,
  extensionEnabled: true,
);

Widget _app(Order? order) => ProviderScope(
      overrides: [
        orderDetailProvider('o1').overrideWith((ref) async => order),
        merchantsProvider.overrideWith((ref) async => [_shopee]),
      ],
      child: MaterialApp(home: OrderDetailScreen(orderId: 'o1', now: DateTime.utc(2026, 10, 10))),
    );

void main() {
  testWidgets('pending order: header, timeline and facts', (t) async {
    await t.pumpWidget(_app(Order(
      id: 'o1',
      merchantId: 'shopee',
      transactionId: '240928SNYXM5KQ',
      productName: 'Tai nghe Sony',
      valueVnd: 6490000,
      cashbackVnd: 454300,
      creditState: 'pending',
      orderTime: DateTime.utc(2026, 9, 28, 7, 32),
    )));
    await t.pumpAndSettle();
    expect(find.text('Đang chờ đối soát'), findsOneWidget);
    expect(find.text('+454.300đ'), findsOneWidget);
    expect(find.text('Tiến trình hoàn tiền'), findsOneWidget);
    expect(find.text('Sàn xác nhận giao thành công'), findsOneWidget);
    expect(find.text('240928SNYXM5KQ'), findsOneWidget);
    expect(find.text('Shopee'), findsOneWidget);
    expect(find.text('6.490.000đ'), findsOneWidget);
    expect(find.text('Báo lỗi / khiếu nại đơn hàng', skipOffstage: false), findsOneWidget);
  });

  testWidgets('cancelled order shows the cancelled state', (t) async {
    await t.pumpWidget(_app(const Order(id: 'o1', merchantId: 'shopee', valueVnd: 1000, cashbackVnd: 0, creditState: 'reversed')));
    await t.pumpAndSettle();
    expect(find.text('Đơn đã bị hủy'), findsOneWidget);
    expect(find.text('Đơn bị hủy hoặc hoàn trả bởi sàn'), findsOneWidget);
  });

  testWidgets('unknown order id shows an empty state', (t) async {
    await t.pumpWidget(_app(null));
    await t.pumpAndSettle();
    expect(find.text('Không tìm thấy đơn hàng.'), findsOneWidget);
  });
}
