import 'dart:async';

import 'package:canhgia_mobile/features/notifications/application/push_registration.dart';
import 'package:canhgia_mobile/features/notifications/data/app_notification.dart';
import 'package:canhgia_mobile/features/notifications/data/notifications_repository.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wallet/fake_supabase.dart';

AppNotification _n(int id, DateTime at, {String type = 'order', Map<String, dynamic> data = const {}, DateTime? read}) =>
    AppNotification(id: id, type: type, title: 't$id', createdAt: at, data: data, readAt: read);

void main() {
  group('safeRoute only lets known in-app paths through', () {
    test('accepts', () {
      for (final ok in ['/orders/123e4567', '/wallet', '/rewards', '/withdraw/history', '/notifications', '/account/notification-settings', '/kyc?step=2', '/missing-order', '/home']) {
        expect(safeRoute(ok), ok, reason: ok);
      }
    });
    test('rejects external, protocol-relative, traversal, unknown, non-string and oversize', () {
      for (final bad in [
        'https://evil.example/wallet',
        '//evil.example',
        'wallet',
        '/orders/../admin',
        '/admin',
        '/walletx',
        '/wallet\n',
        '/wallet;rm',
        '/pin?mode=verify',
        '',
        '/orders/${'a' * 300}',
        42,
        null,
      ]) {
        expect(safeRoute(bad), isNull, reason: '$bad');
      }
    });
  });

  test('AppNotification.route uses data.route through safeRoute', () {
    final at = DateTime.utc(2026, 10, 1);
    expect(_n(1, at, data: {'route': '/orders/abc'}).route, '/orders/abc');
    expect(_n(2, at, data: {'route': 'https://x.y'}).route, isNull);
    expect(_n(3, at).route, isNull);
  });

  test('fromJson tolerates missing body / data / read_at', () {
    final n = AppNotification.fromJson({'id': 5, 'type': 'wallet', 'title': 'Rút tiền thành công', 'created_at': '2026-10-01T10:00:00Z', 'data': null});
    expect((n.id, n.body, n.data.isEmpty, n.isRead), (5, null, true, false));
  });

  test('groupByDay: Hôm nay / Hôm qua / date, order preserved', () {
    final now = DateTime(2026, 10, 5, 12);
    final g = groupByDay([
      _n(1, DateTime(2026, 10, 5, 11)),
      _n(2, DateTime(2026, 10, 5, 1)),
      _n(3, DateTime(2026, 10, 4, 20)),
      _n(4, DateTime(2026, 10, 1, 8)),
    ], now);
    expect(g.map((e) => e.label), ['Hôm nay', 'Hôm qua', '01/10/2026']);
    expect(g.map((e) => e.items.length), [2, 1, 1]);
    expect(groupByDay(const [], now), isEmpty);
  });

  test('tabs map to notification_type filters', () {
    expect(NotificationTab.all.type, isNull);
    expect([NotificationTab.order, NotificationTab.wallet, NotificationTab.promo].map((t) => t.type), ['order', 'wallet', 'promo']);
  });

  group('markRead', () {
    test('null ids marks everything (no params)', () async {
      final db = MockSupabase();
      stubRpc(db, 'mark_notifications_read', 4);
      expect(await NotificationsRepository(db).markRead(), 4);
      expect(lastRpcParams(db, 'mark_notifications_read'), isNull);
    });
    test('ids are sent as p_ids', () async {
      final db = MockSupabase();
      stubRpc(db, 'mark_notifications_read', 1);
      await NotificationsRepository(db).markRead([7]);
      expect(lastRpcParams(db, 'mark_notifications_read'), {'p_ids': [7]});
    });
  });

  group('foreground push', () {
    test('pushFromMessage validates the route and needs a title', () {
      final ok = pushFromMessage(const RemoteMessage(notification: RemoteNotification(title: 'Rút tiền thành công', body: '500.000đ'), data: {'route': '/wallet'}));
      expect((ok!.title, ok.body, ok.route), ('Rút tiền thành công', '500.000đ', '/wallet'));
      final bad = pushFromMessage(const RemoteMessage(notification: RemoteNotification(title: 'x'), data: {'route': 'https://evil.example'}));
      expect(bad!.route, isNull);
      expect(pushFromMessage(const RemoteMessage(data: {})), isNull);
      expect(pushFromMessage(const RemoteMessage(data: {'title': '  '})), isNull);
    });

    testWidgets('listener shows a snackbar with a "Xem" action that opens the route', (t) async {
      final ctrl = StreamController<ForegroundPush>();
      addTearDown(ctrl.close);
      String? opened;
      await t.pumpWidget(ProviderScope(
        overrides: [foregroundPushProvider.overrideWith((ref) => ctrl.stream)],
        child: MaterialApp(
          home: Scaffold(
            body: ForegroundPushListener(onOpenRoute: (r) => opened = r, child: const Text('home')),
          ),
        ),
      ));
      ctrl.add(const ForegroundPush(title: 'Tiền hoàn đã về ví', body: '+131.400đ', route: '/wallet'));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Tiền hoàn đã về ví'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.text('Xem'));
      expect(opened, '/wallet');
    });

    testWidgets('without a route or callback there is no action', (t) async {
      final ctrl = StreamController<ForegroundPush>();
      addTearDown(ctrl.close);
      await t.pumpWidget(ProviderScope(
        overrides: [foregroundPushProvider.overrideWith((ref) => ctrl.stream)],
        child: MaterialApp(home: Scaffold(body: ForegroundPushListener(child: const Text('home')))),
      ));
      ctrl.add(const ForegroundPush(title: 'Khuyến mãi'));
      await t.pump();
      await t.pump();
      expect(find.text('Khuyến mãi'), findsOneWidget);
      expect(find.text('Xem'), findsNothing);
    });
  });
}
