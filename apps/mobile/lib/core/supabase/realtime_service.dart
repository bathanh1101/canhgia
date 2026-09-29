import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_session_provider.dart';
import 'supabase_providers.dart';

/// A realtime signal. Deliberately has identity equality: Riverpod drops a new
/// `AsyncData` equal to the previous one, so value-equal events would be swallowed.
class RealtimeEvent {
  RealtimeEvent(this.kind); // not const: canonicalised instances would be `==` again
  final String kind;
}

/// One channel `user:<uid>` with postgres_changes on the user's own rows.
/// Emits the table name per change, and [resync] whenever local state may be
/// stale: re-SUBSCRIBED after an error, app resumed, access token refreshed.
class RealtimeService with WidgetsBindingObserver {
  RealtimeService(this._client, this._uid);

  static const resync = 'resync';
  static const tables = ['orders', 'notifications', 'withdrawals'];

  final SupabaseClient _client;
  final String _uid;
  final _events = StreamController<RealtimeEvent>.broadcast();
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _authSub;
  var _hadError = false;

  Stream<RealtimeEvent> get events => _events.stream;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    final ch = _client.channel('user:$_uid');
    for (final t in tables) {
      ch.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: t,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: _uid),
        callback: (_) => _emit(t),
      );
    }
    ch.subscribe((status, _) {
      if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
        _hadError = true;
      } else if (status == RealtimeSubscribeStatus.subscribed && _hadError) {
        _hadError = false;
        _emit(resync);
      }
    });
    _channel = ch;
    _authSub = _client.auth.onAuthStateChange.listen((e) {
      final token = e.session?.accessToken;
      if (e.event == AuthChangeEvent.tokenRefreshed && token != null) {
        _client.realtime.setAuth(token);
        _emit(resync);
      }
    });
  }

  void _emit(String v) {
    if (!_events.isClosed) _events.add(RealtimeEvent(v));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _emit(resync);
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _authSub?.cancel();
    final ch = _channel;
    if (ch != null) await _client.removeChannel(ch);
    await _events.close();
  }
}

/// Alive while signed in; recreated per user.
final realtimeServiceProvider = Provider<RealtimeService?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  final s = RealtimeService(ref.watch(supabaseProvider), uid)..start();
  ref.onDispose(s.dispose);
  return s;
});

/// `kind` is a table name ('orders' | 'notifications' | 'withdrawals') or [RealtimeService.resync].
/// List providers: `ref.listen(realtimeEventsProvider, (_, e) { if (e.value?.kind == ...) ref.invalidateSelf(); })`.
final realtimeEventsProvider = StreamProvider<RealtimeEvent>((ref) {
  final s = ref.watch(realtimeServiceProvider);
  return s?.events ?? const Stream.empty();
});
