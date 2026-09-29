import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined, this.action});

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(message, style: AppText.body, textAlign: TextAlign.center),
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
