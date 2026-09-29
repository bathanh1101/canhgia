import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onSeeAll, this.actionLabel = 'Xem tất cả'});

  final String title;
  final VoidCallback? onSeeAll;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: AppText.h2.copyWith(fontSize: 17))),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Text(actionLabel, style: AppText.label.copyWith(color: Theme.of(context).colorScheme.primary)),
            ),
        ],
      );
}
