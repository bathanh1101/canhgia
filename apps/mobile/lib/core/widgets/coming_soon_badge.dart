import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class ComingSoonBadge extends StatelessWidget {
  const ComingSoonBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(999)),
        child: const Text('Sắp có', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
