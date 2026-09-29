import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/merchant.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../../core/widgets/product_tile.dart';
import '../../price_history/presentation/widgets/target_price_sheet.dart';
import '../application/watchlist_providers.dart';

/// Screen 17: watched products with current vs target price; edit target, remove, tap -> price history.
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  var _reachedOnly = false;
  final _removing = <int>{}; // swiped rows: a dismissed Dismissible must leave the tree at once

  Future<bool> _run(Future<void> Function() op) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      return true;
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
      return false;
    }
  }

  Future<void> _edit(WatchEntry e) async {
    final t = await showTargetPriceSheet(context, initial: e.item.targetPriceVnd);
    if (t != null) await _run(() => ref.read(watchlistActionsProvider).setTarget(e.item.groupId, t));
  }

  @override
  Widget build(BuildContext context) {
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Theo dõi giá'), centerTitle: true),
      body: AsyncValueView(
        value: ref.watch(watchlistProvider),
        onRetry: () => ref.invalidate(watchlistProvider),
        data: (loaded) {
          final all = [for (final e in loaded) if (!_removing.contains(e.item.id)) e];
          if (all.isEmpty) {
            return EmptyState(
              message: 'Bạn chưa theo dõi sản phẩm nào. Tìm sản phẩm và đặt cảnh báo giá để mua đúng lúc.',
              icon: Icons.notifications_none,
              action: AppButton(label: 'Tìm sản phẩm', expand: false, onPressed: () => context.push(RoutePaths.search)),
            );
          }
          final reached = all.where((e) => e.reached).length;
          final shown = _reachedOnly ? all.where((e) => e.reached).toList() : all;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(watchlistProvider),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              if (reached > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('$reached sản phẩm đã chạm giá mục tiêu của bạn',
                      style: AppText.label.copyWith(color: AppColors.primary)),
                ),
              FilterChipBar<bool>(options: const {false: 'Tất cả', true: 'Đạt mục tiêu'}, selected: _reachedOnly, onSelected: (v) => setState(() => _reachedOnly = v)),
              const SizedBox(height: 12),
              if (shown.isEmpty) const SizedBox(height: 240, child: EmptyState(message: 'Chưa có sản phẩm nào đạt mục tiêu.')),
              for (final e in shown)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: _row(e, merchants)),
            ]),
          );
        },
      ),
    );
  }

  Widget _row(WatchEntry e, List<Merchant> merchants) {
    final info = e.info;
    final store = info == null ? null : merchants.where((m) => m.id == info.merchantId).firstOrNull?.name;
    final gap = e.gapPercent;
    return Dismissible(
      key: ValueKey(e.item.id),
      direction: DismissDirection.endToStart,
      background: Container(color: AppColors.errorTint, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete_outline, color: AppColors.error)),
      onDismissed: (_) async {
        setState(() => _removing.add(e.item.id));
        final ok = await _run(() => ref.read(watchlistActionsProvider).remove(e.item));
        if (!ok && mounted) setState(() => _removing.remove(e.item.id)); // on success the id stays hidden
      },
      child: ProductTile(
        name: info?.name ?? 'Sản phẩm #${e.item.groupId}',
        priceVnd: e.currentVnd ?? 0,
        imageUrl: info?.imageUrl,
        onTap: () => context.push(RoutePaths.priceHistoryFor('${e.item.groupId}')),
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (e.reached)
            Text('Đã đạt mục tiêu', style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700))
          else if (gap != null)
            Text('Cao hơn mục tiêu $gap%', style: AppText.caption),
          GestureDetector(
            onTap: () => _edit(e),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Mục tiêu ${formatVnd(e.item.targetPriceVnd)} ✎', style: AppText.caption.copyWith(color: AppColors.info)),
            ),
          ),
          if (store != null) Text('Rẻ nhất tại $store', style: AppText.caption),
        ]),
      ),
    );
  }
}
