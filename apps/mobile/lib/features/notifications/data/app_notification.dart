import '../../../core/utils/format_date.dart';

/// Tabs on the notification list; `type` is the `notification_type` filter (null = all).
enum NotificationTab {
  all('Tất cả', null),
  order('Đơn hàng', 'order'),
  wallet('Ví tiền', 'wallet'),
  promo('Khuyến mãi', 'promo');

  const NotificationTab(this.label, this.type);
  final String label;
  final String? type;
}

/// Row of `notifications` (own).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.createdAt,
    this.body,
    this.data = const {},
    this.readAt,
  });

  static const columns = 'id,type,title,body,data,read_at,created_at';

  final int id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        data: j['data'] is Map<String, dynamic> ? j['data'] as Map<String, dynamic> : const {},
        readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Validated in-app route from `data.route`, or null.
  String? get route => safeRoute(data['route']);
}

const _allowedPrefixes = [
  '/orders/', '/wallet', '/rewards', '/withdraw', '/notifications', '/account', '/vouchers', '/home', '/missing-order', '/kyc',
];

/// `data.route` comes from the server / push payload: accept only known in-app paths.
String? safeRoute(Object? raw) {
  if (raw is! String || raw.length > 200) return null;
  if (!RegExp(r'^/[A-Za-z0-9/_\-.?=&%]*$').hasMatch(raw) || raw.startsWith('//') || raw.contains('..')) return null;
  final path = raw.split('?').first;
  return _allowedPrefixes.any((p) => path == p || path.startsWith(p.endsWith('/') ? p : '$p/')) ? raw : null;
}

typedef NotificationGroup = ({String label, List<AppNotification> items});

/// "Hôm nay" / "Hôm qua" / dd/mm/yyyy, keeping the incoming (newest first) order.
List<NotificationGroup> groupByDay(List<AppNotification> list, DateTime now) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = day(now);
  final groups = <NotificationGroup>[];
  for (final n in list) {
    final d = day(n.createdAt.toLocal());
    final diff = today.difference(d).inDays;
    final label = diff == 0 ? 'Hôm nay' : (diff == 1 ? 'Hôm qua' : formatDate(n.createdAt));
    if (groups.isEmpty || groups.last.label != label) {
      groups.add((label: label, items: [n]));
    } else {
      groups.last.items.add(n);
    }
  }
  return groups;
}
