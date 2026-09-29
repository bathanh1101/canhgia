import 'package:canhgia_mobile/features/orders/data/order.dart';
import 'package:flutter_test/flutter_test.dart';

Order _o({String state = 'pending', DateTime? confirmed, DateTime? due}) => Order(
      id: 'o1',
      merchantId: 'shopee',
      valueVnd: 6490000,
      cashbackVnd: 454300,
      creditState: state,
      orderTime: DateTime.utc(2026, 9, 28, 7, 32),
      confirmedTime: confirmed,
      withdrawableAt: due,
    );

void main() {
  final now = DateTime.utc(2026, 10, 10);

  test('fromJson maps columns and defaults', () {
    final o = Order.fromJson({
      'id': 'x',
      'merchant_id': 'lazada',
      'value_vnd': 2190000,
      'user_cashback_vnd': 131400,
      'credit_state': 'credited',
      'order_time': '2026-09-21T03:00:00Z',
      'withdrawable_at': '2026-10-21T03:00:00Z',
      'product_name': 'Nồi chiên',
    });
    expect(o.cashbackVnd, 131400);
    expect(o.title, 'Nồi chiên');
    expect(o.withdrawableAt, DateTime.utc(2026, 10, 21, 3));
    expect(o.source, 'accesstrade');
    expect(Order.fromJson({'id': 'y', 'merchant_id': 'a', 'credit_state': null}).creditState, 'none');
  });

  test('status tabs map credit_state (none counts as pending)', () {
    expect(OrderTab.pending.creditStates, ['none', 'pending']);
    expect(OrderTab.approved.creditStates, ['credited']);
    expect(OrderTab.cancelled.creditStates, ['cancelled', 'reversed']);
    expect(OrderTab.all.creditStates, isNull);
    expect(_o(state: 'none').statusKey, 'pending');
    expect(_o(state: 'reversed').statusKey, 'cancelled');
    expect(_o(state: 'credited').statusKey, 'credited');
  });

  test('holdActive only for credited rows before withdrawable_at', () {
    expect(_o(state: 'credited', due: DateTime.utc(2026, 11, 1)).holdActive(now), isTrue);
    expect(_o(state: 'credited', due: DateTime.utc(2026, 10, 1)).holdActive(now), isFalse);
    expect(_o(state: 'pending', due: DateTime.utc(2026, 11, 1)).holdActive(now), isFalse);
    expect(_o(state: 'credited').holdActive(now), isFalse);
  });

  test('title falls back to the transaction id', () {
    expect(const Order(id: 'a', merchantId: 'm', valueVnd: 1, cashbackVnd: 0, creditState: 'none', transactionId: 'T1').title, 'Đơn hàng T1');
  });

  group('orderTimeline', () {
    test('pending: waiting for the merchant', () {
      final s = orderTimeline(_o(), now);
      expect(s.map((e) => e.state), [TimelineState.done, TimelineState.current, TimelineState.upcoming, TimelineState.upcoming]);
    });

    test('confirmed but inside the hold window', () {
      final s = orderTimeline(_o(state: 'credited', confirmed: DateTime.utc(2026, 10, 2), due: DateTime.utc(2026, 11, 12)), now);
      expect(s.map((e) => e.state), [TimelineState.done, TimelineState.done, TimelineState.current, TimelineState.upcoming]);
      expect(s.last.subtitle, startsWith('Dự kiến'));
    });

    test('hold elapsed: everything done', () {
      final s = orderTimeline(_o(state: 'credited', confirmed: DateTime.utc(2026, 9, 1), due: DateTime.utc(2026, 10, 1)), now);
      expect(s.every((e) => e.state == TimelineState.done), isTrue);
    });

    test('cancelled ends in a failed step', () {
      final s = orderTimeline(_o(state: 'cancelled'), now);
      expect(s.length, 2);
      expect(s.last.state, TimelineState.failed);
    });
  });

  test('monthBounds is [first of month, first of next month) incl. December rollover', () {
    final b = monthBounds(DateTime(2026, 12, 15));
    expect(DateTime.parse(b.from).toLocal(), DateTime(2026, 12));
    expect(DateTime.parse(b.to).toLocal(), DateTime(2027, 1));
  });
}
