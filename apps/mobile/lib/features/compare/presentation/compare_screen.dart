import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../../link/application/link_providers.dart';
import '../../link/presentation/create_link_action.dart';
import '../application/compare_providers.dart';
import '../data/compare_repository.dart';
import 'widgets/compare_offer_row.dart';

/// Screen 15: offers of one product group by effective price, cheapest highlighted, buy via create-link.
class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  var _sort = 'effective';
  var _mallOnly = false;

  @override
  Widget build(BuildContext context) {
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    String nameOf(String id) => merchants.where((m) => m.id == id).firstOrNull?.name ?? id;
    String badgeOf(String id) => merchants.where((m) => m.id == id).firstOrNull?.badgeLetter ?? id.substring(0, 1);
    final value = ref.watch(compareProvider(widget.groupId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('So sánh giá'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Lịch sử giá & cảnh báo',
            icon: const Icon(Icons.notifications_none),
            onPressed: () => context.push(RoutePaths.priceHistoryFor(widget.groupId)),
          ),
        ],
      ),
      body: AsyncValueView(
        value: value,
        onRetry: () => ref.invalidate(compareProvider(widget.groupId)),
        data: (offers) {
          if (offers.length < 2) {
            return EmptyState(
              message: 'Chưa hỗ trợ so sánh',
              icon: Icons.compare_arrows,
              action: AppButton(
                label: 'Xem lịch sử giá',
                expand: false,
                kind: AppButtonKind.outline,
                onPressed: () => context.push(RoutePaths.priceHistoryFor(widget.groupId)),
              ),
            );
          }
          final shown = sortCompare(offers, _sort, mallOnly: _mallOnly);
          final best = cheapestOffer(shown);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(offers.first.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
                Text('Tìm thấy ${offers.length} shop', style: AppText.caption),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Chỉ hiện shop chính hãng / Mall'),
                  value: _mallOnly,
                  onChanged: (v) => setState(() => _mallOnly = v),
                ),
                FilterChipBar<String>(options: compareSorts, selected: _sort, onSelected: (s) => setState(() => _sort = s)),
              ]),
            ),
            Expanded(
              child: shown.isEmpty
                  ? const EmptyState(message: 'Không có shop chính hãng / Mall cho sản phẩm này.')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => CompareOfferRow(
                        offer: shown[i],
                        merchantName: nameOf(shown[i].merchantId),
                        badgeLetter: badgeOf(shown[i].merchantId),
                        cheapest: shown[i].offerId == best?.offerId,
                      ),
                    ),
            ),
            if (best != null) _buyBar(best, nameOf(best.merchantId)),
          ]);
        },
      ),
    );
  }

  Widget _buyBar(CompareOffer best, String merchantName) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            label: 'Mua ở $merchantName${best.estCashbackVnd > 0 ? ' · Hoàn ${formatVnd(best.estCashbackVnd)}' : ''}',
            loading: ref.watch(createLinkControllerProvider).isLoading,
            onPressed: () => runCreateLink(
              context,
              ref,
              merchantId: best.merchantId,
              url: best.url,
              name: best.name,
              priceVnd: best.priceVnd,
              image: best.imageUrl,
            ),
          ),
        ),
      );
}
