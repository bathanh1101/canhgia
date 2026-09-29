import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// "1. Định danh / 2. Ngân hàng / 3. Mã PIN" progress bars; steps <= [current] are filled.
class KycStepper extends StatelessWidget {
  const KycStepper({super.key, required this.current});

  final int current;
  static const labels = ['1. Định danh', '2. Ngân hàng', '3. Mã PIN'];

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 4, decoration: BoxDecoration(color: i < current ? AppColors.primary : AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 4),
                Text(labels[i], style: AppText.caption.copyWith(color: i + 1 == current ? AppColors.text : AppColors.textMuted, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]);
}
