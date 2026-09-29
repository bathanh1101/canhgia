import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/format_date.dart';
import '../../data/price_history_repository.dart';

/// Line chart of daily min price; dashed horizontal line at the alert target when watching.
class PriceChart extends StatelessWidget {
  const PriceChart({super.key, required this.points, this.targetVnd});

  final List<PricePoint> points;
  final int? targetVnd;

  @override
  Widget build(BuildContext context) {
    final start = points.first.day;
    final spots = [for (final p in points) FlSpot(p.day.difference(start).inDays.toDouble(), p.minPriceVnd.toDouble())];
    final ys = [...spots.map((s) => s.y), ?(targetVnd?.toDouble())];
    final lo = ys.reduce((a, b) => a < b ? a : b), hi = ys.reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo) * 0.1 + 1;
    return Column(children: [
      SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          minY: lo - pad,
          maxY: hi + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          extraLinesData: ExtraLinesData(horizontalLines: [
            if (targetVnd != null)
              HorizontalLine(y: targetVnd!.toDouble(), color: AppColors.warning, strokeWidth: 1.5, dashArray: [6, 4]),
          ]),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(show: spots.length == 1),
              belowBarData: BarAreaData(show: true, color: AppColors.primaryTint),
            ),
          ],
        )),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(formatDayMonth(points.first.day), style: AppText.caption),
          Text(formatDayMonth(points.last.day), style: AppText.caption),
        ]),
      ),
    ]);
  }
}
