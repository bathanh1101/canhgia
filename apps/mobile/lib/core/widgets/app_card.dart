import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: color ?? AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: radius, side: const BorderSide(color: AppColors.border)),
      child: InkWell(borderRadius: radius, onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}
