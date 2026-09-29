import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabase extends Mock implements SupabaseClient {}

/// Awaitable stand-in for the PostgREST builder returned by `rpc(...)`.
class FakeRpc extends Fake implements PostgrestFilterBuilder<dynamic> {
  FakeRpc.value(Object? value)
      : _value = value,
        _error = null;
  FakeRpc.error(Object error)
      : _value = null,
        _error = error;

  final Object? _value;
  final Object? _error;

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) =>
      (_error == null ? Future<dynamic>.value(_value) : Future<dynamic>.error(_error)).then(onValue, onError: onError);
}

/// `db.rpc(name, params: ...)` -> [result] (or throws when [result] is an error wrapper).
void stubRpc(MockSupabase db, String fn, Object? result, {Object? error}) {
  when(() => db.rpc<dynamic>(fn, params: any(named: 'params'), get: any(named: 'get')))
      .thenAnswer((_) => error != null ? FakeRpc.error(error) : FakeRpc.value(result));
  // Repositories returning Future<void> infer rpc<void>.
  when(() => db.rpc<void>(fn, params: any(named: 'params'), get: any(named: 'get')))
      .thenAnswer((_) => (error != null ? FakeRpc.error(error) : FakeRpc.value(result)) as PostgrestFilterBuilder<void>);
}

/// Params of the last `rpc(fn)` call (whichever generic variant the repository used).
Map<String, dynamic>? lastRpcParams(MockSupabase db, String fn) {
  List<dynamic> captured;
  try {
    captured = verify(() => db.rpc<dynamic>(fn, params: captureAny(named: 'params'), get: any(named: 'get'))).captured;
  } on Object {
    captured = verify(() => db.rpc<void>(fn, params: captureAny(named: 'params'), get: any(named: 'get'))).captured;
  }
  return captured.isEmpty ? null : captured.last as Map<String, dynamic>?;
}
