import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../application/rewards_logic.dart';

/// Weekly check-in strip T2..CN with the streak and the check-in button.
class CheckinStrip extends StatelessWidget {
  const CheckinStrip({super.key, required this.cells, required this.streak, required this.checkedToday, required this.todayCoins, required this.busy, required this.onCheckin});

  final List<CheckinCell> cells;
  final int streak;
  final bool checkedToday;
  final int todayCoins;
  final bool busy;
  final VoidCallback onCheckin;

  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Điểm danh hằng ngày', style: AppText.h2.copyWith(fontSize: 17))),
            Text('Chuỗi $streak ngày', style: AppText.label.copyWith(color: AppColors.warning)),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final c in cells) _Cell(c)]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: checkedToday || busy ? null : onCheckin,
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(checkedToday ? 'Hôm nay bạn đã điểm danh' : 'Điểm danh nhận $todayCoins xu', style: AppText.button),
            ),
          ),
        ]),
      );
}

class _Cell extends StatelessWidget {
  const _Cell(this.cell);
  final CheckinCell cell;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, child) = switch (cell.state) {
      CheckinCellState.done => (AppColors.primary, Colors.white, const Icon(Icons.check, size: 18, color: Colors.white)),
      CheckinCellState.today => (AppColors.warning, Colors.white, Text('+${cell.coins}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white))),
      CheckinCellState.upcoming => (AppColors.bg, AppColors.textMuted, Text('+${cell.coins}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted))),
      CheckinCellState.missed => (AppColors.bg, AppColors.textMuted, const Icon(Icons.remove, size: 16, color: AppColors.textMuted)),
    };
    return Column(children: [
      CircleAvatar(radius: 19, backgroundColor: bg, foregroundColor: fg, child: child),
      const SizedBox(height: 4),
      Text(cell.label, style: AppText.caption),
    ]);
  }
}
