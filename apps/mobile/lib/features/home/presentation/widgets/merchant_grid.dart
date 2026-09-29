import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/models/merchant.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../data/link_models.dart';

/// "Sàn & Thương hiệu": badge, name and "đến X%" (max rate; hidden when unknown).
class MerchantGrid extends StatelessWidget {
  const MerchantGrid({super.key, required this.merchants});

  final List<Merchant> merchants;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        children: [
          for (final m in merchants)
            Column(mainAxisSize: MainAxisSize.min, children: [
              MerchantBadge(m.badgeLetter, size: 48),
              const SizedBox(height: 6),
              Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label.copyWith(fontSize: 12)),
              if (m.maxUserRateBps > 0) Text('đến ${formatBps(m.maxUserRateBps)}', style: AppText.caption),
            ]),
        ],
      );
}
