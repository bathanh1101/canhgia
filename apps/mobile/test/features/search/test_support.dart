import 'dart:async';

import 'package:canhgia_mobile/core/models/merchant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

/// Awaitable stand-in for the builder returned by `rpc()` / `from().select()`.
class FakeBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  FakeBuilder(this.value);
  final T value;

  @override
  Future<R> then<R>(FutureOr<R> Function(T value) onValue, {Function? onError}) =>
      Future<T>.value(value).then(onValue, onError: onError);
}

const shopee = Merchant(
  id: 'shopee',
  name: 'Shopee',
  badgeLetter: 'S',
  domains: ['shopee.vn'],
  maxUserRateBps: 1000,
  datafeedEnabled: true,
  extensionEnabled: true,
);
const traveloka = Merchant(
  id: 'traveloka',
  name: 'Traveloka',
  badgeLetter: 'T',
  domains: ['traveloka.com'],
  maxUserRateBps: 0,
  datafeedEnabled: false,
  extensionEnabled: false,
);

/// MaterialApp.router hosting [home] at `/` with stub targets for every route the features push.
Widget routerApp(Widget home, {List<Override> overrides = const []}) {
  Widget stub(String t) => Scaffold(body: Text(t));
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => home),
    GoRoute(path: '/link/:clickId', builder: (_, s) => stub('LINK ${s.pathParameters['clickId']}')),
    GoRoute(path: '/compare/:groupId', builder: (_, s) => stub('COMPARE ${s.pathParameters['groupId']}')),
    GoRoute(path: '/price-history/:groupId', builder: (_, s) => stub('HISTORY ${s.pathParameters['groupId']}')),
    GoRoute(path: '/search/results', builder: (_, s) => stub('RESULTS ${s.uri.query}')),
    GoRoute(path: '/watchlist', builder: (_, _) => stub('WATCHLIST')),
  ]);
  return ProviderScope(retry: (_, _) => null, overrides: overrides, child: MaterialApp.router(routerConfig: router));
}

/// Plain MaterialApp (no navigation).
Widget plainApp(Widget home, {List<Override> overrides = const []}) =>
    ProviderScope(retry: (_, _) => null, overrides: overrides, child: MaterialApp(home: home));
