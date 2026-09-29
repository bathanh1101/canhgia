import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.total = 6});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < total; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? AppColors.primary : Colors.transparent,
              border: Border.all(color: i < filled ? AppColors.primary : AppColors.border, width: 2),
            ),
          ),
      ]);
}
