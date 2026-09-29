import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';

/// Rounded white group of rows separated by dividers.
class AccountGroup extends StatelessWidget {
  const AccountGroup({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 16, 0, 8), child: Text(title, style: AppText.label)),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (final (i, c) in children.indexed) ...[if (i > 0) const Divider(height: 1, indent: 16), c],
            ]),
          ),
        ],
      );
}

class AccountTile extends StatelessWidget {
  const AccountTile({super.key, required this.icon, required this.title, this.value, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        title: Text(title, style: AppText.title.copyWith(fontSize: 15)),
        trailing: trailing ??
            Row(mainAxisSize: MainAxisSize.min, children: [
              if (value != null) Text(value!, style: AppText.caption),
              if (onTap != null) const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ]),
      );
}
