import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../utils/format_vnd.dart';
import 'app_card.dart';

/// Product row: image, name, price and "Hoàn X% · Yđ" (cashback shown only when known).
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.name,
    required this.priceVnd,
    this.imageUrl,
    this.cashbackPercentText,
    this.cashbackVnd,
    this.trailing,
    this.onTap,
  });

  final String name;
  final int priceVnd;
  final String? imageUrl;
  final String? cashbackPercentText;
  final int? cashbackVnd;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cashback = cashbackVnd == null
        ? null
        : 'Hoàn ${cashbackPercentText == null ? '' : '$cashbackPercentText · '}${formatVnd(cashbackVnd!)}';
    final cashbackText = cashback == null
        ? null
        : Text(cashback, style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700));
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 64,
              height: 64,
              child: imageUrl == null
                  ? const ColoredBox(color: AppColors.bg)
                  : CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const ColoredBox(color: AppColors.bg),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text(formatVnd(priceVnd), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ?cashbackText,
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
