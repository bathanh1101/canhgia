import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/product_tile.dart';
import '../../data/search_repository.dart';
import '../../../home/data/link_models.dart';

/// Search hit row: "giá thực trả" (price - est. cashback), "Hoàn X%", "N sàn". Tap -> compare, or history for single-offer groups.
class OfferHitTile extends StatelessWidget {
  const OfferHitTile({super.key, required this.hit});

  final OfferHit hit;

  void _open(BuildContext context) {
    final g = hit.groupId;
    if (g == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chưa hỗ trợ so sánh cho sản phẩm này')));
    } else if (hit.canCompare) {
      context.push(RoutePaths.compareFor('$g'));
    } else {
      context.push(RoutePaths.priceHistoryFor('$g'));
    }
  }

  @override
  Widget build(BuildContext context) => ProductTile(
        name: hit.name,
        priceVnd: hit.effectivePriceVnd,
        imageUrl: hit.imageUrl,
        cashbackPercentText: hit.rateBps > 0 ? formatBps(hit.rateBps) : null,
        cashbackVnd: hit.estCashbackVnd > 0 ? hit.estCashbackVnd : null,
        onTap: () => _open(context),
        trailing: hit.canCompare
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryTintStrong, borderRadius: BorderRadius.circular(8)),
                child: Text('${hit.offersInGroup} sàn', style: AppText.caption.copyWith(color: AppColors.primaryDark)),
              )
            : null,
      );
}
