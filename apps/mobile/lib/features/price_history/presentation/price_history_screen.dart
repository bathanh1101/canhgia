import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../watchlist/application/watchlist_providers.dart';
import '../application/price_history_providers.dart';
import '../data/price_history_repository.dart';
import '../../watchlist/data/watchlist_repository.dart';
import 'widgets/price_chart.dart';
import 'widgets/target_price_sheet.dart';

/// Screen 16: price chart + stats for a product group and the target-price alert (watchlist_items).
class PriceHistoryScreen extends ConsumerStatefulWidget {
  const PriceHistoryScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  var _days = 90;

  Future<void> _saveTarget(int current) async {
    final watch = ref.read(watchItemProvider(widget.groupId)).value;
    final target = await showTargetPriceSheet(context, initial: watch?.targetPriceVnd ?? suggestedTarget(current));
    final gid = int.tryParse(widget.groupId);
    if (target == null || gid == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(watchlistActionsProvider).setTarget(gid, target);
      messenger.showSnackBar(SnackBar(
        content: Text('Đã đặt cảnh báo khi giá dưới ${formatVnd(target)}'),
        action: SnackBarAction(label: 'Xem danh sách', onPressed: () => context.push(RoutePaths.watchlist)),
      ));
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  Future<void> _unwatch() async {
    final item = ref.read(watchItemProvider(widget.groupId)).value;
    if (item == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(watchlistActionsProvider).remove(item);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(priceHistoryProvider((widget.groupId, _days)));
    final info = ref.watch(groupInfoProvider(widget.groupId)).value;
    final watch = ref.watch(watchItemProvider(widget.groupId)).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giá'), centerTitle: true),
      body: AsyncValueView(
        value: history,
        onRetry: () => ref.invalidate(priceHistoryProvider((widget.groupId, _days))),
        data: (points) => ListView(padding: const EdgeInsets.all(16), children: [
          if (info != null) Text(info.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
          const SizedBox(height: 12),
          FilterChipBar<int>(options: priceRanges, selected: _days, onSelected: (d) => setState(() => _days = d)),
          const SizedBox(height: 12),
          if (points.isEmpty)
            const SizedBox(height: 200, child: EmptyState(message: 'Chưa có dữ liệu giá cho khoảng thời gian này.', icon: Icons.show_chart))
          else
            ..._data(points, info, watch),
        ]),
      ),
    );
  }

  List<Widget> _data(List<PricePoint> points, GroupInfo? info, WatchItem? watch) {
    final stats = PriceStats.of(points)!;
    final current = info?.priceVnd ?? points.last.minPriceVnd;
    final insight = priceInsight(current, stats, _days);
    Widget stat(String label, int v) => Expanded(
          child: Column(children: [
            Text(label, style: AppText.caption),
            Text(formatVnd(v), style: AppText.title.copyWith(fontSize: 14)),
          ]),
        );
    return [
      AppCard(child: Row(children: [stat('Thấp nhất', stats.min), stat('Hiện tại', current), stat('Cao nhất', stats.max)])),
      const SizedBox(height: 12),
      AppCard(child: PriceChart(points: chartPoints(points, _days), targetVnd: watch?.targetPriceVnd)),
      if (insight != null) ...[
        const SizedBox(height: 12),
        AppCard(color: AppColors.infoTint, child: Text(insight, style: AppText.body)),
      ],
      const SizedBox(height: 12),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cảnh báo giá', style: AppText.title),
          const SizedBox(height: 4),
          Text(
            watch == null
                ? 'Báo khi giá thực trả dưới mức bạn chọn (đã tính hoàn tiền).'
                : 'Đang báo khi giá thực trả dưới ${formatVnd(watch.targetPriceVnd)}.',
            style: AppText.body,
          ),
          const SizedBox(height: 12),
          AppButton(label: watch == null ? 'Lưu theo dõi giá' : 'Đổi mức giá mục tiêu', onPressed: () => _saveTarget(current)),
          if (watch != null) AppButton(label: 'Bỏ theo dõi', kind: AppButtonKind.text, onPressed: _unwatch),
        ]),
      ),
    ];
  }
}
