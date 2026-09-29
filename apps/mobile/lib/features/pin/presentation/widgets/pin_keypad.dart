import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// 3x4 numeric pad; [leading] fills the bottom-left slot (biometric button).
class PinKeypad extends StatelessWidget {
  const PinKeypad({super.key, required this.onDigit, required this.onBackspace, this.leading, this.enabled = true});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final Widget? leading;
  final bool enabled;

  Widget _key(Widget child, VoidCallback? onTap) => Padding(
        padding: const EdgeInsets.all(5),
        child: Material(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(borderRadius: BorderRadius.circular(14), onTap: enabled ? onTap : null, child: Center(child: child)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _key(
          Text(d, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.text)),
          () => onDigit(d),
        );
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisExtent: 56),
      children: [
        for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9']) digit(d),
        leading ?? const SizedBox.shrink(),
        digit('0'),
        _key(const Icon(Icons.backspace_outlined, key: Key('pin-backspace'), color: AppColors.text), onBackspace),
      ],
    );
  }
}
