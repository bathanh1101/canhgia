import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/utils/format_vnd.dart';

/// Client-side hint only; the server re-checks everything in `request_withdrawal`.
String? validateWithdrawAmount({required int amount, required int available, required int min, int? dailyRemaining}) {
  if (amount < min) return 'Số tiền rút tối thiểu ${formatVnd(min)}.';
  if (amount > available) return 'Số dư khả dụng không đủ.';
  if (dailyRemaining != null && amount > dailyRemaining) {
    return 'Vượt hạn mức rút trong ngày (còn ${formatVnd(dailyRemaining)}).';
  }
  return null;
}

/// Digits only -> int (0 when empty or absurdly long).
int parseAmount(String text) {
  final d = text.replaceAll(RegExp(r'\D'), '');
  return d.isEmpty || d.length > 12 ? 0 : int.parse(d);
}

/// Vietnamese message for a failed `request_withdrawal` (exact vocabulary codes only).
String withdrawErrorMessage(Object e) {
  final f = AppFailure.from(e);
  switch (f.code) {
    case 'pin_invalid':
      return 'Phiên xác thực PIN đã hết hạn. Vui lòng xác nhận lại.';
    case 'hold_active':
      final until = DateTime.tryParse('${f.detail['until'] ?? ''}');
      return until == null ? f.message : 'Tài khoản đang trong thời gian giữ rút tiền đến ${formatDateTime(until)}.';
    default:
      return f.message;
  }
}
