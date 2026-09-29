import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_date.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../../link/application/link_providers.dart';
import '../../../link/presentation/create_link_action.dart';
import '../../data/voucher_repository.dart';
import 'save_voucher_button.dart';

/// "HSD 30/09" / "Hết hạn hôm nay" / "Còn 2 ngày" (<= 3 days left).
String voucherExpiryText(DateTime? endsAt, DateTime now) {
  if (endsAt == null) return 'Không giới hạn';
  final end = endsAt.toLocal();
  if (end.year == now.year && end.month == now.month && end.day == now.day) return 'Hết hạn hôm nay';
  final days = DateTime(end.year, end.month, end.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  return days > 0 && days <= 3 ? 'Còn $days ngày' : 'HSD ${formatDayMonth(end)}';
}

class VoucherCard extends ConsumerWidget {
  const VoucherCard({super.key, required this.voucher, required this.merchantName, required this.badgeLetter, this.now});

  final Voucher voucher;
  final String merchantName;
  final String badgeLetter;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = voucher;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          MerchantBadge(badgeLetter, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
              Text(merchantName, style: AppText.caption),
            ]),
          ),
          Text(voucherExpiryText(v.endsAt, now ?? DateTime.now()), style: AppText.caption.copyWith(color: AppColors.warning)),
        ]),
        if (v.description != null && v.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(v.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body),
        ],
        if (v.hasCode) ...[
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
              child: Text(v.code!, style: AppText.label.copyWith(color: AppColors.primaryDark, letterSpacing: 1)),
            ),
            IconButton(
              tooltip: 'Sao chép mã',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(clipboardWriterProvider)(v.code!);
                messenger.showSnackBar(const SnackBar(content: Text('Đã sao chép mã')));
              },
            ),
          ]),
        ],
        const SizedBox(height: 8),
        Row(children: [
          SaveVoucherButton(voucherId: v.id, saveLabel: 'Lưu mã'),
          const Spacer(),
          AppButton(
            label: 'Dùng ngay',
            expand: false,
            loading: ref.watch(createLinkControllerProvider).isLoading,
            onPressed: () => runCreateLink(context, ref, merchantId: v.merchantId, url: v.url, name: v.headline),
          ),
        ]),
      ]),
    );
  }
}
