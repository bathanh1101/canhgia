import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../data/compare_repository.dart';

/// One shop: effective price ("đã trừ hoàn tiền"), list price, cashback, badges.
class CompareOfferRow extends StatelessWidget {
  const CompareOfferRow({super.key, required this.offer, required this.merchantName, required this.badgeLetter, required this.cheapest});

  final CompareOffer offer;
  final String merchantName;
  final String badgeLetter;
  final bool cheapest;

  Widget _pill(String t, Color fg, Color bg) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final o = offer;
    final list = o.listPriceVnd;
    return AppCard(
      color: cheapest ? AppColors.primaryTint : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MerchantBadge(badgeLetter, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.shopName ?? merchantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 14)),
            Text(merchantName, style: AppText.caption),
            const SizedBox(height: 4),
            Wrap(children: [
              if (cheapest) _pill('Rẻ nhất', Colors.white, AppColors.primary),
              if (o.isMall) _pill('Mall / Chính hãng', AppColors.info, AppColors.infoTint),
              if (!o.cashbackEligible) _pill('Không hoàn tiền', AppColors.error, AppColors.errorTint),
            ]),
            if (o.cashbackEligible && o.estCashbackVnd > 0)
              Text('Hoàn ${formatVnd(o.estCashbackVnd)} (ước tính)', style: AppText.caption.copyWith(color: AppColors.primary)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(formatVnd(o.effectivePriceVnd), style: AppText.title.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
          Text('đã trừ hoàn tiền', style: AppText.caption),
          Text('Giá bán ${formatVnd(o.priceVnd)}', style: AppText.caption),
          if (list != null && list > o.priceVnd)
            Text(formatVnd(list), style: AppText.caption.copyWith(decoration: TextDecoration.lineThrough)),
        ]),
      ]),
    );
  }
}
