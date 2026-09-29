import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_theme.dart';

enum AppButtonKind { primary, outline, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppButtonKind.primary,
    this.loading = false,
    this.leading,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonKind kind;
  final bool loading;
  final Widget? leading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg));
    const pad = EdgeInsets.symmetric(vertical: 16, horizontal: 20);
    final fg = kind == AppButtonKind.primary ? Colors.white : AppColors.primary;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              Flexible(child: Text(label, style: AppText.button, textAlign: TextAlign.center)),
            ],
          );
    final button = switch (kind) {
      AppButtonKind.primary => FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            padding: pad,
            shape: shape,
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
          ),
          child: child,
        ),
      AppButtonKind.outline => OutlinedButton(
          onPressed: enabled ? onPressed : null,
          style: OutlinedButton.styleFrom(
            padding: pad,
            shape: shape,
            foregroundColor: AppColors.text,
            side: const BorderSide(color: AppColors.border),
            backgroundColor: AppColors.surface,
          ),
          child: child,
        ),
      AppButtonKind.text => TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: child,
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
