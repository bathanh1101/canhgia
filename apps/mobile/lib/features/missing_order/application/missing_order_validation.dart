import '../../../core/supabase/postgrest_error_mapper.dart';

const maxMissingOrderPhotos = 3;

/// Client mirror of `submit_missing_order` checks (server re-validates). Returns a message or null.
String? validateMissingOrder({
  required String? merchantId,
  required String orderCode,
  required DateTime? purchasedOn,
  required int valueVnd,
  required int photoCount,
  required DateTime today,
}) {
  if (merchantId == null) return 'Chọn sàn mua hàng.';
  final code = orderCode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (code.length < 4 || code.length > 40) return 'Mã đơn hàng chưa hợp lệ.';
  if (purchasedOn == null) return 'Chọn ngày mua.';
  final day = DateTime(today.year, today.month, today.day);
  final bought = DateTime(purchasedOn.year, purchasedOn.month, purchasedOn.day);
  final age = day.difference(bought).inDays;
  if (age < 1 || age > 60) return 'Ngày mua phải trong vòng 60 ngày gần đây và trước hôm nay.';
  if (valueVnd <= 0 || valueVnd > 1000000000) return 'Giá trị đơn chưa hợp lệ.';
  if (photoCount < 1) return 'Tải lên ít nhất 1 ảnh chụp chi tiết đơn hàng.';
  if (photoCount > maxMissingOrderPhotos) return 'Tối đa $maxMissingOrderPhotos ảnh.';
  return null;
}

String missingOrderErrorMessage(Object e) {
  final f = AppFailure.from(e);
  if (f.code == 'rate_limited') return 'Bạn đang có quá nhiều yêu cầu chờ xử lý (tối đa 5). Vui lòng đợi kết quả.';
  if (f.code == 'invalid_input' && f.detail['reason'] == 'duplicate_order_code') {
    return 'Mã đơn hàng này đã được báo trước đó.';
  }
  return f.message;
}
