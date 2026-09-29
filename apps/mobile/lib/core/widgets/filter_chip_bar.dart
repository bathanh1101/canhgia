import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Horizontal single-select chips (status tabs, sort, merchant filters).
class FilterChipBar<T> extends StatelessWidget {
  const FilterChipBar({super.key, required this.options, required this.selected, required this.onSelected});

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final e in options.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.value),
                  selected: e.key == selected,
                  onSelected: (_) => onSelected(e.key),
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  labelStyle: TextStyle(
                    color: e.key == selected ? Colors.white : AppColors.text2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );
}
