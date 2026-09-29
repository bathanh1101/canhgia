import 'package:canhgia_mobile/app/route_paths.dart';
import 'package:canhgia_mobile/core/providers/unread_notifications_provider.dart';
import 'package:canhgia_mobile/features/notifications/application/notifications_providers.dart';
import 'package:canhgia_mobile/features/notifications/data/app_notification.dart';
import 'package:canhgia_mobile/features/notifications/data/notifications_repository.dart';
import 'package:canhgia_mobile/features/notifications/presentation/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

final _now = DateTime(2026, 10, 5, 12);

final _items = [
  AppNotification(id: 1, type: 'wallet', title: 'Tiền hoàn đã về ví', body: '+131.400đ', createdAt: DateTime(2026, 10, 5, 11, 55), data: const {'route': '/wallet'}),
  AppNotification(id: 2, type: 'order', title: 'Đơn hàng mới được ghi nhận', createdAt: DateTime(2026, 10, 5, 10), readAt: DateTime(2026, 10, 5, 11)),
  AppNotification(id: 3, type: 'promo', title: 'Mega Sale 10.10', createdAt: DateTime(2026, 10, 4, 8), data: const {'route': 'https://evil.example'}),
];

Widget _app(_MockRepo repo, {List<AppNotification>? items}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => NotificationsScreen(now: _now)),
    GoRoute(path: '/wallet', builder: (_, _) => const Text('WALLET-PAGE')),
    GoRoute(path: RoutePaths.accountNotificationSettings, builder: (_, _) => const Text('SETTINGS-PAGE')),
  ]);
  return ProviderScope(
    key: UniqueKey(),
    overrides: [
      notificationsRepositoryProvider.overrideWithValue(repo),
      notificationsProvider.overrideWith((ref, tab) async => (items ?? _items).where((n) => tab.type == null || n.type == tab.type).toList()),
      unreadNotificationsProvider.overrideWith((ref) async => 2),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(<int>[]));

  testWidgets('groups by day and marks unread rows', (t) async {
    await t.pumpWidget(_app(_MockRepo()));
    await t.pumpAndSettle();
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Hôm qua'), findsOneWidget);
    expect(find.text('Tiền hoàn đã về ví'), findsOneWidget);
    expect(find.text('11:55'), findsOneWidget);
    expect(find.text('04/10'), findsOneWidget);
  });

  testWidgets('type tabs filter the list', (t) async {
    await t.pumpWidget(_app(_MockRepo()));
    await t.pumpAndSettle();
    await t.tap(find.text('Ví tiền'));
    await t.pumpAndSettle();
    expect(find.text('Tiền hoàn đã về ví'), findsOneWidget);
    expect(find.text('Mega Sale 10.10'), findsNothing);
  });

  testWidgets('tapping an unread notification marks it read and opens its route', (t) async {
    final repo = _MockRepo();
    when(() => repo.markRead(any())).thenAnswer((_) async => 1);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Tiền hoàn đã về ví'));
    await t.pumpAndSettle();
    verify(() => repo.markRead([1])).called(1);
    expect(find.text('WALLET-PAGE'), findsOneWidget);
  });

  testWidgets('an already-read row is not re-marked; an unsafe route is ignored', (t) async {
    final repo = _MockRepo();
    when(() => repo.markRead(any())).thenAnswer((_) async => 1);
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Đơn hàng mới được ghi nhận')); // already read, no route
    await t.pump();
    verifyNever(() => repo.markRead(any()));
    await t.tap(find.text('Mega Sale 10.10')); // unread, external route dropped
    await t.pumpAndSettle();
    verify(() => repo.markRead([3])).called(1);
    expect(find.text('Mega Sale 10.10'), findsOneWidget); // still on the list
  });

  testWidgets('"Đọc tất cả" marks everything read; failure is shown', (t) async {
    final repo = _MockRepo();
    when(() => repo.markRead()).thenThrow(Exception('offline'));
    await t.pumpWidget(_app(repo));
    await t.pumpAndSettle();
    await t.tap(find.text('Đọc tất cả'));
    await t.pumpAndSettle();
    verify(() => repo.markRead()).called(1);
    expect(find.text('Đã có lỗi xảy ra. Vui lòng thử lại.'), findsOneWidget);
  });

  testWidgets('empty state and settings shortcut', (t) async {
    await t.pumpWidget(_app(_MockRepo(), items: const []));
    await t.pumpAndSettle();
    expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
    await t.tap(find.byIcon(Icons.settings_outlined));
    await t.pumpAndSettle();
    expect(find.text('SETTINGS-PAGE'), findsOneWidget);
  });
}
