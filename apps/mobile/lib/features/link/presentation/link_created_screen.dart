import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/merchant_badge.dart';
import '../../home/data/link_models.dart';
import '../application/link_providers.dart';
import 'widgets/activation_countdown.dart';

/// Screen 08: link created. `link == null` when the route is restored without its `extra`.
class LinkCreatedScreen extends ConsumerWidget {
  const LinkCreatedScreen({super.key, required this.link});

  final CreatedLink? link;

  void _toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _buy(BuildContext context, WidgetRef ref, CreatedLink l) async {
    final uri = safeExternalUri(l.affLink);
    if (uri == null) return _toast(context, errorMessagesVi['unknown']!);
    final launch = ref.read(externalLauncherProvider);
    try {
      if (!await launch(uri)) throw const AppFailure('unknown');
    } on Object catch (e) {
      // Universal link may fail to open the app: fall back to the short link.
      final fallback = l.shortLink == null ? null : safeExternalUri(l.shortLink!);
      if (fallback != null && await launch(fallback)) return;
      if (context.mounted) _toast(context, mapErrorMessage(e));
    }
  }

  Future<void> _copy(BuildContext context, WidgetRef ref, CreatedLink l) async {
    await ref.read(clipboardWriterProvider)(l.shareUrl);
    if (context.mounted) _toast(context, 'Đã sao chép link');
  }

  Future<void> _share(BuildContext context, WidgetRef ref, CreatedLink l) async {
    final share = ref.read(shareTextProvider);
    final repo = ref.read(linkRepositoryProvider);
    try {
      await share(l.shareUrl);
    } on Object catch (e) {
      if (context.mounted) _toast(context, mapErrorMessage(e));
      return;
    }
    try {
      await repo.recordShare(l.clickId); // analytics only: a failure must not look like a failed share
    } on Object {
      // ignored on purpose
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = link;
    if (l == null) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Link hoàn tiền'),
        body: EmptyState(
          message: 'Phiên tạo link đã hết. Hãy dán lại link sản phẩm để tạo mới.',
          icon: Icons.link_off,
          action: AppButton(label: 'Về trang chủ', expand: false, onPressed: () => context.go(RoutePaths.home)),
        ),
      );
    }
    final merchant = ref.watch(merchantsProvider).value?.where((m) => m.id == l.merchantId).firstOrNull;
    final merchantName = merchant?.name ?? l.merchantId;
    final tier = ref.watch(profileProvider).value?.vipTierCode;
    final holdDays = ref.watch(merchantHoldDaysProvider).value?[l.merchantId];
    final est = l.estimate;
    final tierLabel = tier == null || tier.isEmpty ? null : tier[0].toUpperCase() + tier.substring(1);
    return Scaffold(
      appBar: const AppTopBar(title: 'Link hoàn tiền'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(children: [
              MerchantBadge(merchant?.badgeLetter ?? merchantName.substring(0, merchantName.isEmpty ? 0 : 1)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.productName ?? 'Sản phẩm tại $merchantName',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title),
                  Text(merchantName, style: AppText.caption),
                  if (l.productPriceVnd != null)
                    Text(formatVnd(l.productPriceVnd!), style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.primaryTint,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hoàn tiền dự kiến (ước tính)', style: AppText.label),
              const SizedBox(height: 4),
              if (est?.cashbackVnd != null)
                Text(formatVnd(est!.cashbackVnd!), style: AppText.h1.copyWith(color: AppColors.primary)),
              if (est != null)
                Text(est.label(tierLabel), style: AppText.title.copyWith(color: AppColors.primary))
              else
                Text('Chưa có mức hoàn tiền cụ thể cho sản phẩm này', style: AppText.body),
              const SizedBox(height: 4),
              Text(
                holdDays == null
                    ? 'Về ví sau khi sàn đối soát'
                    : 'Về ví sau khi sàn đối soát + $holdDays ngày chờ',
                style: AppText.caption,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Link hoàn tiền', style: AppText.label),
              const SizedBox(height: 6),
              Text(l.shareUrl, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: AppButton(label: 'Sao chép', kind: AppButtonKind.outline, onPressed: () => _copy(context, ref, l)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(label: 'Chia sẻ', kind: AppButtonKind.outline, onPressed: () => _share(context, ref, l)),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.warningTint,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                l.activationHours > 0
                    ? 'Mua trong ${l.activationHours} giờ và không mở link của ứng dụng khác để đơn được ghi nhận hoàn tiền.'
                    : 'Không mở link của ứng dụng khác trước khi mua để đơn được ghi nhận hoàn tiền.',
                style: AppText.body,
              ),
              if (l.activationHours > 0) ActivationCountdown(link: l),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(label: 'Mở $merchantName & mua ngay', onPressed: () => _buy(context, ref, l)),
        ),
      ),
    );
  }
}
