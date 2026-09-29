import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/providers/merchants_provider.dart';
import '../../../../core/utils/format_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/status_pill.dart';
import '../../application/missing_order_providers.dart';

/// "Yêu cầu gần đây": status of earlier reports (hidden while loading / on error / empty).
class RecentReports extends ConsumerWidget {
  const RecentReports({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myReportsProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final merchants = ref.watch(merchantsProvider).value ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionHeader('Yêu cầu gần đây'),
      const SizedBox(height: 8),
      AppCard(
        child: Column(children: [
          for (final r in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                MerchantBadge(merchants.where((m) => m.id == r.merchantId).firstOrNull?.badgeLetter ?? r.merchantId.substring(0, 1).toUpperCase()),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.orderCode, style: AppText.title.copyWith(fontSize: 14)),
                    Text('#${r.publicCode} · Gửi ${formatDayMonth(r.createdAt)}', style: AppText.caption),
                  ]),
                ),
                StatusPill.forStatus(r.pillKey),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
