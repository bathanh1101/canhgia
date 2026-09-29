import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Letter avatar (S, L, T, Ti, A) from `merchants.badge_letter`.
class MerchantBadge extends StatelessWidget {
  const MerchantBadge(this.letter, {super.key, this.size = 40});

  final String letter;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.primaryTintStrong, borderRadius: BorderRadius.circular(size / 3)),
        child: Text(
          letter,
          style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: size * 0.4),
        ),
      );
}
