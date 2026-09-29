import 'dart:async';
import 'dart:convert';
import 'dart:io';

// http is a transitive dependency (pubspec is frozen for this phase).
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vietnamese messages for the backend error vocabulary
/// (docs/backend-contracts.md). SQL `raise` message == code. Do not add codes
/// client-side that the backend does not raise.
const errorMessagesVi = <String, String>{
  // user
  'forbidden': 'Bạn không có quyền thực hiện thao tác này.',
  'rate_limited': 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.',
  'account_locked': 'Tài khoản đang bị khóa. Vui lòng liên hệ hỗ trợ.',
  'insufficient_balance': 'Số dư khả dụng không đủ.',
  'pin_invalid': 'Mã PIN không đúng.',
  'pin_locked': 'Mã PIN đã bị khóa tạm thời do nhập sai nhiều lần.',
  'kyc_required': 'Bạn cần xác thực định danh (KYC) trước.',
  'code_invalid': 'Mã không hợp lệ hoặc đã hết hạn.',
  'code_pending': 'Đang xử lý, vui lòng đợi giây lát.',
  'hold_active': 'Tài khoản đang trong thời gian giữ rút tiền. Vui lòng thử lại sau.',
  'daily_cap': 'Bạn đã đạt hạn mức rút tiền trong ngày.',
  'invalid_input': 'Thông tin nhập chưa hợp lệ. Vui lòng kiểm tra lại.',
  // admin per-row
  'invalid_state': 'Trạng thái hiện tại không cho phép thao tác này.',
  'not_claimer': 'Yêu cầu này đang do người khác xử lý.',
  'bank_unverified': 'Tài khoản ngân hàng chưa được xác minh.',
  // edge
  'unsupported_url': 'Link này chưa được hỗ trợ. Hãy dán link sản phẩm từ sàn đối tác.',
  'merchant_unavailable': 'Sàn này tạm thời chưa khả dụng. Vui lòng thử lại sau.',
  // client-side
  'google_not_configured': 'Đăng nhập Google chưa được cấu hình.',
  'network': 'Không có kết nối mạng. Vui lòng kiểm tra và thử lại.',
  'unknown': 'Đã có lỗi xảy ra. Vui lòng thử lại.',
};

/// Supabase Auth error codes worth a specific message.
const _authMessagesVi = <String, String>{
  'otp_expired': 'Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.',
  'otp_disabled': 'Đăng nhập bằng OTP đang tạm tắt.',
  'over_email_send_rate_limit': 'Bạn yêu cầu mã quá nhiều lần. Vui lòng thử lại sau.',
  'over_request_rate_limit': 'Bạn thao tác quá nhanh. Vui lòng thử lại sau.',
  'captcha_failed': 'Xác minh captcha thất bại. Vui lòng thử lại.',
  'validation_failed': 'Email hoặc mã OTP chưa hợp lệ.',
  'email_address_invalid': 'Địa chỉ email không hợp lệ.',
  'invalid_credentials': 'Mã OTP không đúng.',
};

/// Normalised failure carrying the vocabulary code, optional `detail` JSON and a
/// Vietnamese message. Build with [AppFailure.from]; UI shows [message].
class AppFailure implements Exception {
  const AppFailure(this.code, {this.detail = const {}, this.customMessage});

  final String code;
  final Map<String, dynamic> detail;
  final String? customMessage;

  String get message => customMessage ?? errorMessagesVi[code] ?? errorMessagesVi['unknown']!;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is PostgrestException) {
      final code = error.message.trim();
      return AppFailure(code, detail: _parseDetail(error.details));
    }
    if (error is FunctionException) {
      final d = error.details;
      final code = d is Map ? '${d['error'] ?? ''}' : '';
      return AppFailure(code, detail: d is Map ? _parseDetail(d['detail']) : const {});
    }
    if (error is AuthRetryableFetchException) return const AppFailure('network');
    if (error is AuthException) {
      final code = error.code ?? '';
      return AppFailure(code, customMessage: _authMessagesVi[code] ?? errorMessagesVi['unknown']);
    }
    if (error is SocketException || error is TimeoutException || error is HttpException ||
        error is http.ClientException) {
      return const AppFailure('network');
    }
    return const AppFailure('unknown');
  }

  @override
  String toString() => 'AppFailure($code)';
}

Map<String, dynamic> _parseDetail(Object? raw) {
  try {
    final v = raw is String ? jsonDecode(raw) : raw;
    return v is Map<String, dynamic> ? v : const {};
  } on FormatException {
    return const {};
  }
}

/// Convenience for snackbars: any thrown object -> Vietnamese message.
String mapErrorMessage(Object error) => AppFailure.from(error).message;

/// Vocabulary code of [error] ('' when not a backend error).
String errorCodeOf(Object error) => AppFailure.from(error).code;
