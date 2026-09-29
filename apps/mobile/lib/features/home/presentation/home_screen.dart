import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../core/providers/merchants_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/unread_notifications_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/supabase/postgrest_error_mapper.dart';
import '../../../core/supabase/realtime_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/balance_summary_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../link/application/link_providers.dart';
import '../../link/presentation/create_link_action.dart';
import '../../vouchers/application/voucher_providers.dart';
import '../application/home_providers.dart';
import 'widgets/clipboard_link_card.dart';
import 'widgets/greeting_header.dart';
import 'widgets/merchant_grid.dart';
import 'widgets/paste_link_field.dart';
import 'widgets/voucher_strip.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  var _resolving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    if (!mounted) return;
    await ref.read(clipboardLinkProvider.notifier).checkClipboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state != AppLifecycleState.resumed) return;
    await WidgetsBinding.instance.endOfFrame; // Android 10+: clipboard readable only once focused
    await _checkClipboard();
  }

  Future<void> _submitPasted(String url) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _resolving = true);
    try {
      await ref.read(clipboardLinkProvider.notifier).submit(url);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _create(LinkCard card) async {
    final offer = card.resolved.offer;
    await runCreateLink(
      context,
      ref,
      merchantId: card.resolved.merchantId,
      url: card.resolved.resolvedUrl.isEmpty ? card.url : card.resolved.resolvedUrl,
      name: offer?.name,
      priceVnd: offer?.priceVnd,
      image: offer?.imageUrl,
    );
    if (mounted && !ref.read(createLinkControllerProvider).hasError) ref.read(clipboardLinkProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(realtimeEventsProvider, (_, e) {
      if (e.value?.kind == RealtimeService.resync) {
        ref.invalidate(merchantsProvider);
        ref.invalidate(homeVouchersProvider);
      }
    });
    final merchants = ref.watch(merchantsProvider);
    final card = ref.watch(clipboardLinkProvider).value;
    final creating = ref.watch(createLinkControllerProvider).isLoading;
    String nameOf(String id) => merchants.value?.where((m) => m.id == id).firstOrNull?.name ?? id;
    String badgeOf(String id) => merchants.value?.where((m) => m.id == id).firstOrNull?.badgeLetter ?? id.substring(0, 1);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(merchantsProvider);
            ref.invalidate(homeVouchersProvider);
            ref.invalidate(profileProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GreetingHeader(profile: ref.watch(profileProvider).value, unread: ref.watch(unreadNotificationsProvider).value ?? 0),
              const SizedBox(height: 16),
              BalanceSummaryCard(wallet: ref.watch(walletProvider).value, onTap: () => context.go(RoutePaths.wallet)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: AppButton(label: 'Rút tiền', kind: AppButtonKind.text, onPressed: () => context.push(RoutePaths.withdraw))),
                Expanded(child: AppButton(label: 'Lịch sử đơn', kind: AppButtonKind.text, onPressed: () => context.go(RoutePaths.wallet))),
                Expanded(child: AppButton(label: 'Theo dõi giá', kind: AppButtonKind.text, onPressed: () => context.push(RoutePaths.watchlist))),
              ]),
              if (card != null) ...[
                const SizedBox(height: 8),
                ClipboardLinkCard(
                  card: card,
                  merchantName: nameOf(card.resolved.merchantId),
                  creating: creating,
                  onDismiss: ref.read(clipboardLinkProvider.notifier).dismiss,
                  onCreate: () => _create(card),
                  onCompare: () => context.push(RoutePaths.compareFor('${card.resolved.offer!.productGroupId}')),
                ),
              ],
              const SizedBox(height: 16),
              PasteLinkField(onSubmit: _submitPasted, busy: _resolving),
              const SizedBox(height: 20),
              const SectionHeader('Sàn & Thương hiệu'),
              const SizedBox(height: 8),
              AsyncValueView(
                value: merchants,
                onRetry: () => ref.invalidate(merchantsProvider),
                data: (list) => MerchantGrid(merchants: list),
              ),
              ..._vouchers(badgeOf),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _vouchers(String Function(String) badgeOf) {
    final v = ref.watch(homeVouchersProvider).value;
    if (v == null || v.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      SectionHeader('Săn Voucher hôm nay', onSeeAll: () => context.go(RoutePaths.vouchers)),
      const SizedBox(height: 8),
      VoucherStrip(vouchers: v, badgeFor: badgeOf),
    ];
  }
}
