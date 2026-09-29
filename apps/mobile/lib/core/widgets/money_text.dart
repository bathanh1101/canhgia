import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../utils/format_vnd.dart';

/// Integer VND rendered as "1.250.000đ". Use for every money value.
class MoneyText extends StatelessWidget {
  const MoneyText(this.amountVnd, {super.key, this.style, this.signed = false});

  final int amountVnd;
  final TextStyle? style;

  /// Prefix "+" for positive values (cashback credit lines).
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final text = (signed && amountVnd > 0 ? '+' : '') + formatVnd(amountVnd);
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary).merge(style),
    );
  }
}
