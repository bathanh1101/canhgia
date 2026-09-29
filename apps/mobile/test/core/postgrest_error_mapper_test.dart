import 'dart:async';
import 'dart:io';

import 'package:canhgia_mobile/core/supabase/postgrest_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // docs/backend-contracts.md vocabulary: keep in sync when the backend adds codes.
  const userCodes = [
    'forbidden', 'rate_limited', 'account_locked', 'insufficient_balance', 'pin_invalid', 'pin_locked',
    'kyc_required', 'code_invalid', 'code_pending', 'hold_active', 'daily_cap', 'invalid_input',
  ];
  const adminCodes = ['invalid_state', 'not_claimer', 'bank_unverified'];
  const edgeCodes = ['unsupported_url', 'merchant_unavailable'];

  group('vocabulary coverage', () {
    for (final code in [...userCodes, ...adminCodes, ...edgeCodes]) {
      test('$code has a specific Vietnamese message', () {
        final m = mapErrorMessage(PostgrestException(message: code));
        expect(m, isNot(errorMessagesVi['unknown']));
        expect(m, equals(errorMessagesVi[code]));
      });
    }
  });

  test('PostgREST message with padding and JSON detail keeps code and detail', () {
    final f = AppFailure.from(PostgrestException(message: ' pin_locked ', details: '{"locked_until":"2026-10-01T00:00:00Z"}'));
    expect(f.code, 'pin_locked');
    expect(f.detail['locked_until'], '2026-10-01T00:00:00Z');
  });

  test('malformed detail does not throw', () {
    final f = AppFailure.from(PostgrestException(message: 'daily_cap', details: '{not json'));
    expect(f.code, 'daily_cap');
    expect(f.detail, isEmpty);
  });

  test('unknown backend message -> generic message', () {
    expect(mapErrorMessage(PostgrestException(message: 'duplicate key value violates ...')), errorMessagesVi['unknown']);
  });

  test('Edge function error body {error} maps to vocabulary', () {
    final e = FunctionException(status: 422, details: {'error': 'unsupported_url'});
    expect(errorCodeOf(e), 'unsupported_url');
    expect(mapErrorMessage(e), errorMessagesVi['unsupported_url']);
  });

  test('Edge function with detail JSON', () {
    final e = FunctionException(status: 429, details: {'error': 'rate_limited', 'detail': {'retry_after': 30}});
    expect(AppFailure.from(e).detail['retry_after'], 30);
  });

  test('auth error codes get their own text', () {
    expect(mapErrorMessage(const AuthException('x', code: 'otp_expired')), contains('hết hạn'));
    expect(mapErrorMessage(const AuthException('x', code: 'captcha_failed')), contains('captcha'));
    expect(mapErrorMessage(const AuthException('x', code: 'something_new')), errorMessagesVi['unknown']);
  });

  test('network-ish exceptions -> network message', () {
    expect(errorCodeOf(const SocketException('down')), 'network');
    expect(errorCodeOf(TimeoutException('slow')), 'network');
  });

  test('AppFailure passes through untouched', () {
    const f = AppFailure('google_not_configured');
    expect(identical(AppFailure.from(f), f), isTrue);
  });

  test('arbitrary object -> generic', () {
    expect(mapErrorMessage(StateError('boom')), errorMessagesVi['unknown']);
  });
}
