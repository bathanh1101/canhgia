import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_vnd.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/withdraw_form.dart';
import '../../application/withdraw_validation.dart';

/// "Số tiền muốn rút": big input + quick amounts (100K / 200K / 500K / Tất cả).
class AmountCard extends ConsumerStatefulWidget {
  const AmountCard({super.key, required this.available, this.error});

  final int available;
  final String? error;

  @override
  ConsumerState<AmountCard> createState() => _AmountCardState();
}

class _AmountCardState extends ConsumerState<AmountCard> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(int v) {
    _ctrl.text = v == 0 ? '' : formatVnd(v).replaceAll('đ', '');
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    ref.read(withdrawFormProvider.notifier).setAmount(v);
  }

  @override
  Widget build(BuildContext context) {
    final amount = ref.watch(withdrawFormProvider.select((s) => s.amount));
    return AppCard(
      child: Column(children: [
        Text('Số tiền muốn rút', style: AppText.body.copyWith(color: AppColors.textMuted)),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
          style: AppText.h1.copyWith(fontSize: 36),
          decoration: const InputDecoration(border: InputBorder.none, hintText: '0', suffixText: 'đ'),
          onChanged: (t) => ref.read(withdrawFormProvider.notifier).setAmount(parseAmount(t)),
        ),
        Text(
          widget.error ?? 'Khả dụng: ${formatVnd(widget.available)}',
          style: AppText.label.copyWith(color: widget.error == null ? AppColors.primary : AppColors.error),
          textAlign: TextAlign.center,
        ),
        const Divider(height: 24),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in const [100000, 200000, 500000])
            ChoiceChip(
              label: Text(formatVndCompact(v)),
              selected: amount == v,
              onSelected: (_) => _set(v),
            ),
          ChoiceChip(
            label: const Text('Tất cả'),
            selected: amount != 0 && amount == widget.available,
            onSelected: (_) => _set(widget.available),
          ),
        ]),
      ]),
    );
  }
}
