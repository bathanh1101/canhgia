import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/filter_chip_bar.dart';
import '../../../orders/application/orders_providers.dart';
import '../../../orders/data/order.dart';
import '../../../orders/presentation/widgets/order_tile.dart';
import 'ledger_list.dart';

/// Month picker, status tabs and the live order list (or the ledger view).
class OrderHistory extends ConsumerStatefulWidget {
  const OrderHistory({super.key, this.now});

  final DateTime? now;

  @override
  ConsumerState<OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends ConsumerState<OrderHistory> {
  static const _page = 50;
  late DateTime _month = DateTime((widget.now ?? DateTime.now()).year, (widget.now ?? DateTime.now()).month);
  var _tab = OrderTab.all;
  var _limit = _page;
  var _ledger = false;

  List<DateTime> get _months {
    final n = widget.now ?? DateTime.now();
    return [for (var i = 0; i < 12; i++) DateTime(n.year, n.month - i)];
  }

  @override
  Widget build(BuildContext context) {
    final query = (month: _month, tab: _tab, limit: _limit);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(_ledger ? 'Biến động số dư' : 'Lịch sử đơn hàng', style: AppText.h2.copyWith(fontSize: 18))),
        IconButton(
          tooltip: 'Đổi chế độ xem',
          icon: Icon(_ledger ? Icons.shopping_bag_outlined : Icons.swap_vert, color: AppColors.primary),
          onPressed: () => setState(() => _ledger = !_ledger),
        ),
        if (!_ledger)
          PopupMenuButton<DateTime>(
            initialValue: _month,
            onSelected: (m) => setState(() {
              _month = m;
              _limit = _page;
            }),
            itemBuilder: (_) => [for (final m in _months) PopupMenuItem(value: m, child: Text('Tháng ${m.month}/${m.year}'))],
            child: Text('Tháng ${_month.month} ▾', style: AppText.label.copyWith(color: AppColors.primary)),
          ),
      ]),
      const SizedBox(height: 8),
      if (_ledger)
        const LedgerList()
      else ...[
        FilterChipBar<OrderTab>(
          options: {for (final t in OrderTab.values) t: t.label},
          selected: _tab,
          onSelected: (t) => setState(() {
            _tab = t;
            _limit = _page;
          }),
        ),
        ref.watch(ordersProvider(query)).when(
              skipLoadingOnRefresh: true,
              loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              error: (_, _) => Center(
                child: TextButton(onPressed: () => ref.invalidate(ordersProvider), child: const Text('Không tải được. Thử lại')),
              ),
              data: (list) => list.isEmpty
                  ? const EmptyState(message: 'Chưa có đơn hàng trong tháng này.', icon: Icons.shopping_bag_outlined)
                  : Column(children: [
                      for (final o in list) OrderTile(order: o, now: widget.now),
                      if (list.length >= _limit)
                        TextButton(onPressed: () => setState(() => _limit += _page), child: const Text('Xem thêm')),
                    ]),
            ),
      ],
    ]);
  }
}
