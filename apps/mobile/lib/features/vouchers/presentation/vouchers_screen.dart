import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/filter_chip_bar.dart';
import '../application/voucher_providers.dart';
import '../data/voucher_repository.dart';
import 'widgets/voucher_card.dart';

/// Screen 13 (tab): active vouchers, filter by merchant or saved, save / copy / use.
class VouchersScreen extends ConsumerStatefulWidget {
  const VouchersScreen({super.key});

  @override
  ConsumerState<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends ConsumerState<VouchersScreen> {
  var _filter = voucherFilterAll;

  @override
  Widget build(BuildContext context) {
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    final saved = ref.watch(savedVoucherIdsProvider).value ?? const <int>{};
    final merchantId = _filter == voucherFilterAll || _filter == voucherFilterSaved ? null : _filter;
    final list = ref.watch(vouchersProvider(merchantId));
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ưu đãi', style: AppText.h2),
            Text('${saved.length} mã đã lưu', style: AppText.caption),
            const SizedBox(height: 12),
            FilterChipBar<String>(
              options: {
                voucherFilterAll: 'Tất cả',
                voucherFilterSaved: 'Đã lưu',
                for (final m in merchants) m.id: m.name,
              },
              selected: _filter,
              onSelected: (f) => setState(() => _filter = f),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AsyncValueView(
                value: list,
                onRetry: () => ref.invalidate(vouchersProvider(merchantId)),
                data: (all) {
                  final shown = filterVouchers(all, _filter, saved);
                  if (shown.isEmpty) {
                    return EmptyState(
                      message: _filter == voucherFilterSaved ? 'Bạn chưa lưu mã nào.' : 'Chưa có voucher phù hợp.',
                      icon: Icons.local_offer_outlined,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(vouchersProvider(merchantId)),
                    child: ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final v = shown[i];
                        final m = merchants.where((x) => x.id == v.merchantId).firstOrNull;
                        return VoucherCard(
                          voucher: v,
                          merchantName: m?.name ?? v.merchantId,
                          badgeLetter: m?.badgeLetter ?? v.merchantId.substring(0, 1),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
