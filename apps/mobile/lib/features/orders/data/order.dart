import '../../../core/utils/format_date.dart';

/// Status tabs on the wallet order list (design 03).
enum OrderTab {
  all('Tất cả', null),
  pending('Chờ duyệt', ['none', 'pending']),
  approved('Đã duyệt', ['credited']),
  cancelled('Bị hủy', ['cancelled', 'reversed']);

  const OrderTab(this.label, this.creditStates);
  final String label;

  /// `orders.credit_state` values shown under this tab (null = no filter).
  final List<String>? creditStates;
}

/// Row of `orders` (explicit column list only: commission columns are not granted).
class Order {
  const Order({
    required this.id,
    required this.merchantId,
    required this.valueVnd,
    required this.cashbackVnd,
    required this.creditState,
    this.transactionId,
    this.productName,
    this.orderTime,
    this.clickTime,
    this.confirmedTime,
    this.withdrawableAt,
    this.source = 'accesstrade',
  });

  static const columns = 'id,merchant_id,transaction_id,product_name,value_vnd,user_cashback_vnd,credit_state,'
      'order_time,click_time,confirmed_time,withdrawable_at,source';

  final String id;
  final String merchantId;
  final String? transactionId;
  final String? productName;
  final int valueVnd;
  final int cashbackVnd;
  final String creditState;
  final DateTime? orderTime;
  final DateTime? clickTime;
  final DateTime? confirmedTime;
  final DateTime? withdrawableAt;
  final String source;

  factory Order.fromJson(Map<String, dynamic> j) {
    DateTime? ts(String k) => j[k] == null ? null : DateTime.parse(j[k] as String);
    return Order(
      id: j['id'] as String,
      merchantId: j['merchant_id'] as String,
      transactionId: j['transaction_id'] as String?,
      productName: j['product_name'] as String?,
      valueVnd: (j['value_vnd'] as num?)?.toInt() ?? 0,
      cashbackVnd: (j['user_cashback_vnd'] as num?)?.toInt() ?? 0,
      creditState: (j['credit_state'] as String?) ?? 'none',
      orderTime: ts('order_time'),
      clickTime: ts('click_time'),
      confirmedTime: ts('confirmed_time'),
      withdrawableAt: ts('withdrawable_at'),
      source: (j['source'] as String?) ?? 'accesstrade',
    );
  }

  bool get isCancelled => creditState == 'cancelled' || creditState == 'reversed';
  bool get isCredited => creditState == 'credited';

  /// Key understood by `StatusPill.forStatus`.
  String get statusKey => isCancelled ? 'cancelled' : (isCredited ? 'credited' : 'pending');

  String get title => (productName?.trim().isNotEmpty ?? false) ? productName!.trim() : 'Đơn hàng ${transactionId ?? ''}'.trim();

  DateTime? get placedAt => orderTime ?? clickTime;

  /// Credited but still inside the anti-reversal hold.
  bool holdActive(DateTime now) => isCredited && withdrawableAt != null && withdrawableAt!.isAfter(now);
}

enum TimelineState { done, current, upcoming, failed }

class TimelineStep {
  const TimelineStep(this.title, this.state, [this.subtitle]);
  final String title;
  final TimelineState state;
  final String? subtitle;
}

/// click -> order -> confirmed -> return window over -> available (or cancelled).
List<TimelineStep> orderTimeline(Order o, DateTime now) {
  final placed = o.placedAt;
  final first = TimelineStep('Đã ghi nhận đơn hàng', TimelineState.done, placed == null ? null : formatDateTime(placed));
  if (o.isCancelled) {
    return [first, const TimelineStep('Đơn bị hủy hoặc hoàn trả bởi sàn', TimelineState.failed)];
  }
  final confirmed = o.confirmedTime;
  final due = o.withdrawableAt;
  final windowOver = confirmed != null && due != null && !due.isAfter(now);
  return [
    first,
    TimelineStep(
      'Sàn xác nhận giao thành công',
      confirmed == null ? TimelineState.current : TimelineState.done,
      confirmed == null ? 'Đang chờ sàn đối soát' : formatDateTime(confirmed),
    ),
    TimelineStep(
      'Hết thời gian đổi trả',
      confirmed == null ? TimelineState.upcoming : (windowOver ? TimelineState.done : TimelineState.current),
      confirmed != null && !windowOver ? 'Đang trong thời gian đổi trả' : null,
    ),
    TimelineStep(
      'Tiền chuyển vào ví khả dụng',
      windowOver ? TimelineState.done : TimelineState.upcoming,
      due == null ? null : (windowOver ? formatDate(due) : 'Dự kiến ${formatDate(due)}'),
    ),
  ];
}

/// [first, nextFirst) bounds of the calendar month of [month] in local time, as UTC ISO strings.
({String from, String to}) monthBounds(DateTime month) {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  return (from: start.toUtc().toIso8601String(), to: end.toUtc().toIso8601String());
}
