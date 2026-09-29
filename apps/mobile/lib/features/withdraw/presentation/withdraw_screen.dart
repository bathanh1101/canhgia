import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/route_paths.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/providers/wallet_provider.dart';
import '../../../core/utils/format_date.dart';
import '../../../core/utils/format_vnd.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../application/withdraw_form.dart';
import '../application/withdraw_providers.dart';
import '../application/withdraw_validation.dart';
import '../data/bank_models.dart';
import '../data/withdrawal.dart';
import 'widgets/amount_card.dart';
import 'widgets/bank_account_tile.dart';
import 'widgets/withdraw_result_view.dart';

/// Screen 04 - amount, destination, hold banner, PIN verification, request.
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key, this.now});
  final DateTime? now;

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  DateTime get _now => widget.now ?? DateTime.now();

  String? _amountError(int available, PublicSettings s) {
    final amount = ref.read(withdrawFormProvider).amount;
    // Watched in build(), so the value is loaded (and kept fresh) by the time this runs.
    final recent = ref.read(withdrawalsProvider).value;
    return validateWithdrawAmount(
      amount: amount,
      available: available,
      min: s.minWithdrawVnd,
      dailyRemaining: recent == null ? null : dailyCapRemaining(s.dailyCapVnd, recent, _now),
    );
  }

  Future<void> _confirm(int available, PublicSettings s, BankAccount bank, String bankName) async {
    final messenger = ScaffoldMessenger.of(context);
    final err = _amountError(available, s);
    if (err != null) {
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ref.read(withdrawFormProvider.notifier).selectBank(bank.id);
    final amount = ref.read(withdrawFormProvider).amount;
    final token = await context.push<String>(
      RoutePaths.pinFor('verify'),
      extra: 'Xác nhận rút ${formatVnd(amount)} về tài khoản $bankName ${bank.masked}',
    );
    if (token == null || !mounted) return;
    try {
      await ref.read(withdrawFormProvider.notifier).submit(token);
      ref.invalidate(withdrawalsProvider);
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(withdrawErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(withdrawFormProvider);
    ref.watch(withdrawalsProvider); // keep alive: `_amountError` needs the daily-cap history
    final settings = ref.watch(publicSettingsProvider).value ?? const PublicSettings();
    final accounts = ref.watch(bankAccountsProvider);
    if (form.result != null) {
      return Scaffold(
        appBar: const AppTopBar(title: 'Rút tiền'),
        body: WithdrawResultView(result: form.result!, amount: form.resultAmount ?? form.amount, eta: settings.etaText),
      );
    }
    final available = ref.watch(walletProvider).value?.availableVnd ?? 0;
    final profile = ref.watch(profileProvider).value;
    final holdUntil = profile?.withdrawalHoldUntil;
    final held = holdUntil != null && holdUntil.isAfter(_now);
    final banks = ref.watch(banksProvider).value ?? const [];
    return Scaffold(
      appBar: const AppTopBar(title: 'Rút tiền'),
      body: AsyncValueView(
        value: accounts,
        onRetry: () => ref.invalidate(bankAccountsProvider),
        data: (list) {
          final selected = list.where((a) => a.id == form.bankAccountId).firstOrNull ?? pickDefaultAccount(list);
          final touched = form.amount > 0;
          return Column(children: [
            Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
                if (held) _HoldBanner(until: holdUntil),
                AmountCard(available: available, error: touched ? _amountError(available, settings) : null),
                const SizedBox(height: 20),
                Text('Nhận tiền về', style: AppText.h2.copyWith(fontSize: 17)),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  AppCard(
                    child: Column(children: [
                      const Text('Bạn chưa có tài khoản nhận tiền. Hoàn tất xác thực để thêm tài khoản ngân hàng.'),
                      const SizedBox(height: 8),
                      AppButton(label: 'Xác thực & liên kết ngân hàng', onPressed: () => context.push(RoutePaths.kyc)),
                    ]),
                  ),
                for (final a in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: BankAccountTile(
                      account: a,
                      bankName: bankNameOf(banks, a.bankBin),
                      selected: a.id == selected?.id,
                      onTap: () => ref.read(withdrawFormProvider.notifier).selectBank(a.id),
                    ),
                  ),
                if (list.isNotEmpty)
                  TextButton(onPressed: () => context.push(RoutePaths.kycStep(2)), child: const Text('+ Thêm tài khoản ngân hàng')),
                const SizedBox(height: 8),
                _Summary(amount: form.amount, eta: settings.etaText, min: settings.minWithdrawVnd),
              ]),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  AppButton(
                    label: 'Xác nhận rút tiền',
                    loading: form.submitting,
                    onPressed: selected == null || held
                        ? null
                        : () => _confirm(available, settings, selected, bankNameOf(banks, selected.bankBin)),
                  ),
                  const SizedBox(height: 4),
                  Text('Xác thực bằng mã PIN', style: AppText.caption),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _HoldBanner extends StatelessWidget {
  const _HoldBanner({required this.until});
  final DateTime until;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(12)),
        child: Text(
          'Vì lý do an toàn, tài khoản tạm giữ rút tiền đến ${formatDateTime(until)} '
          '(sau khi đổi PIN, thêm ngân hàng, thiết bị mới).',
          style: AppText.body.copyWith(color: AppColors.text),
        ),
      );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.amount, required this.eta, required this.min});
  final int amount;
  final String eta;
  final int min;

  @override
  Widget build(BuildContext context) {
    Widget row(String k, String v, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Text(k, style: AppText.body.copyWith(color: AppColors.textMuted)),
            const Spacer(),
            Text(v, style: AppText.title.copyWith(fontSize: 14, color: strong ? AppColors.primary : null)),
          ]),
        );
    return AppCard(
      child: Column(children: [
        row('Phí rút tiền', 'Miễn phí'),
        row('Thời gian nhận', eta),
        row('Rút tối thiểu', formatVnd(min)),
        const Divider(),
        row('Thực nhận', formatVnd(amount), strong: true),
      ]),
    );
  }
}
