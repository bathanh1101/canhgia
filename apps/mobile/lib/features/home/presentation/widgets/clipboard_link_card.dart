import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/home_providers.dart';

/// "Phát hiện link vừa sao chép": product, price, estimated cashback and the two actions.
class ClipboardLinkCard extends StatelessWidget {
  const ClipboardLinkCard({
    super.key,
    required this.card,
    required this.merchantName,
    required this.creating,
    required this.onDismiss,
    required this.onCreate,
    required this.onCompare,
  });

  final LinkCard card;
  final String merchantName;
  final bool creating;
  final VoidCallback onDismiss;
  final VoidCallback onCreate;
  final VoidCallback onCompare;

  @override
  Widget build(BuildContext context) {
    final r = card.resolved;
    final offer = r.offer;
    final est = r.estimate;
    final cashbackOk = offer?.cashbackEligible ?? true;
    return AppCard(
      color: AppColors.primaryTint,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Phát hiện link $merchantName vừa sao chép', style: AppText.label.copyWith(color: AppColors.primaryDark)),
        const SizedBox(height: 8),
        if (offer != null) ...[
          Text(offer.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
          Text(formatVnd(offer.priceVnd), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
        ] else
          Text('Bạn có muốn tạo link hoàn tiền cho sản phẩm này không?', style: AppText.body),
        if (!cashbackOk)
          Text('Không hoàn tiền', style: AppText.caption.copyWith(color: AppColors.error))
        else if (est != null)
          Text(
            'Hoàn ${est.label()}${est.cashbackVnd == null ? '' : ' · ${formatVnd(est.cashbackVnd!)}'} (ước tính)',
            style: AppText.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: 8),
        if (r.canCompare)
          GestureDetector(
            onTap: onCompare,
            child: Text('So sánh giá ›', style: AppText.label.copyWith(color: AppColors.primary)),
          )
        else
          Text('Chưa hỗ trợ so sánh', style: AppText.caption),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: AppButton(label: 'Bỏ qua', kind: AppButtonKind.outline, onPressed: onDismiss)),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: AppButton(label: 'Tạo link hoàn tiền', loading: creating, onPressed: onCreate)),
        ]),
      ]),
    );
  }
}
