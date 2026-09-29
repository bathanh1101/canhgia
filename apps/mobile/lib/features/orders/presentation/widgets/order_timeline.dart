import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/order.dart';

/// Vertical stepper "Tiến trình hoàn tiền".
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < steps.length; i++) _row(steps[i], last: i == steps.length - 1),
      ]);

  Widget _row(TimelineStep s, {required bool last}) {
    final color = switch (s.state) {
      TimelineState.done => AppColors.primary,
      TimelineState.current => AppColors.warning,
      TimelineState.failed => AppColors.error,
      TimelineState.upcoming => AppColors.border,
    };
    final muted = s.state == TimelineState.upcoming;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 20,
          child: Column(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.state == TimelineState.done || s.state == TimelineState.failed ? color : AppColors.surface,
                border: Border.all(color: color, width: 3),
              ),
            ),
            if (!last) Expanded(child: Container(width: 2, color: s.state == TimelineState.done ? AppColors.primary : AppColors.border)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: AppText.title.copyWith(fontSize: 15, color: muted ? AppColors.textMuted : AppColors.text)),
              if (s.subtitle != null)
                Text(s.subtitle!, style: AppText.caption.copyWith(color: s.state == TimelineState.current ? AppColors.warning : null)),
            ]),
          ),
        ),
      ]),
    );
  }
}
