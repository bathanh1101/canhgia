import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/merchant_badge.dart';
import '../../data/bank_models.dart';

/// Selectable destination account row.
class BankAccountTile extends StatelessWidget {
  const BankAccountTile({super.key, required this.account, required this.bankName, required this.selected, required this.onTap});

  final BankAccount account;
  final String bankName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        color: selected ? AppColors.primaryTint : null,
        child: Row(children: [
          MerchantBadge(bankName.isEmpty ? '?' : bankName.substring(0, 1).toUpperCase()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bankName, style: AppText.title),
              Text('${account.accountName} · ${account.masked}', style: AppText.caption),
              if (account.isDefault) Text('✓ Chính chủ · Đã KYC', style: AppText.caption.copyWith(color: AppColors.primary)),
            ]),
          ),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.primary : AppColors.border),
        ]),
      );
}

/// bin -> bank name ('' when unknown).
String bankNameOf(List<Bank> banks, String bin) => banks.where((b) => b.bin == bin).firstOrNull?.name ?? '';
