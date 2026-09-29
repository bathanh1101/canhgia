import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_date.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../../vouchers/data/voucher_repository.dart';
import '../../../vouchers/presentation/widgets/save_voucher_button.dart';

/// Horizontal "Săn Voucher hôm nay" cards with a Lưu toggle.
class VoucherStrip extends StatelessWidget {
  const VoucherStrip({super.key, required this.vouchers, required this.badgeFor});

  final List<Voucher> vouchers;
  final String Function(String merchantId) badgeFor;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 156,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: vouchers.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final v = vouchers[i];
            return SizedBox(
              width: 190,
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    MerchantBadge(badgeFor(v.merchantId), size: 28),
                    const Spacer(),
                    if (v.endsAt != null) Text('HSD ${formatDayMonth(v.endsAt!)}', style: AppText.caption),
                  ]),
                  const SizedBox(height: 6),
                  Text(v.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 14)),
                  const Spacer(),
                  Align(alignment: Alignment.centerRight, child: SaveVoucherButton(voucherId: v.id)),
                ]),
              ),
            );
          },
        ),
      );
}
