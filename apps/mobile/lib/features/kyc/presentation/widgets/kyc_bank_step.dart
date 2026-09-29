import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/supabase/postgrest_error_mapper.dart';
import '../../../../core/utils/vn_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/coming_soon_badge.dart';
import '../../../withdraw/application/withdraw_providers.dart';
import '../../application/kyc_logic.dart';
import '../../application/kyc_providers.dart';
import '../../data/kyc_repository.dart';

/// Step 2 (KYC verified): pick bank, account number, holder name that matches the CCCD.
class KycBankStep extends ConsumerStatefulWidget {
  const KycBankStep({super.key, required this.profile, required this.onDone});

  final KycProfile profile;
  final VoidCallback onDone;

  @override
  ConsumerState<KycBankStep> createState() => _KycBankStepState();
}

class _KycBankStepState extends ConsumerState<KycBankStep> {
  late final _name = TextEditingController(text: normalizeName(widget.profile.fullName));
  final _number = TextEditingController();
  String? _bin;
  var _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  bool get _match => nameMatchesCccd(_name.text, widget.profile.fullName);
  bool get _valid => _bin != null && isValidAccountNumber(_number.text) && _match;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    try {
      await ref.read(kycRepositoryProvider).addBank(
            bankBin: _bin!,
            accountNumber: _number.text.replaceAll(RegExp(r'\s'), ''),
            accountName: _name.text.trim(),
          );
      ref.invalidate(bankAccountsProvider);
      widget.onDone();
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(mapErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.primaryTintStrong, borderRadius: BorderRadius.circular(14)),
          child: Text('✓ CCCD đã xác thực · ${widget.profile.fullName} · ••••${widget.profile.last4}', style: AppText.title.copyWith(fontSize: 14)),
        ),
        const SizedBox(height: 16),
        Text('Chọn ngân hàng', style: AppText.h2.copyWith(fontSize: 17)),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: AsyncValueView(
            value: ref.watch(banksProvider),
            onRetry: () => ref.invalidate(banksProvider),
            data: (banks) => GridView.count(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final b in banks)
                  InkWell(
                    onTap: b.isEnabled ? () => setState(() => _bin = b.bin) : null,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: b.isEnabled ? (_bin == b.bin ? AppColors.primaryTint : AppColors.surface) : AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _bin == b.bin ? AppColors.primary : AppColors.border),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(b.code, style: AppText.title.copyWith(fontSize: 13, color: b.isEnabled ? null : AppColors.textMuted)),
                        Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(fontSize: 10)),
                        if (!b.isEnabled) const ComingSoonBadge(),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Số tài khoản', style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: _number,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(24)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('Tên chủ tài khoản', style: AppText.label),
        const SizedBox(height: 6),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            suffixText: _name.text.trim().isEmpty ? null : (_match ? '✓ Khớp CCCD' : 'Chưa khớp CCCD'),
            suffixStyle: TextStyle(color: _match ? AppColors.primary : AppColors.error, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        Text('Chỉ chấp nhận tài khoản chính chủ trùng tên với CCCD đã xác thực để đảm bảo an toàn khi rút tiền.', style: AppText.caption),
        const SizedBox(height: 16),
        AppButton(label: 'Tiếp tục · Tạo mã PIN', loading: _busy, onPressed: _valid ? _submit : null),
      ]);
}
