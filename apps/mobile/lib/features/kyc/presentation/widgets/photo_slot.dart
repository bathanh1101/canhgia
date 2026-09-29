import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../data/photo.dart';

/// Tap-to-pick photo tile with preview.
class PhotoSlot extends StatelessWidget {
  const PhotoSlot({super.key, required this.label, required this.photo, required this.onTap});

  final String label;
  final PickedPhoto? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 110,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: photo == null ? AppColors.border : AppColors.primary),
          ),
          child: photo == null
              ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                  const SizedBox(height: 4),
                  Text(label, style: AppText.caption),
                ])
              : Image.memory(
                  photo!.bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                ),
        ),
      );
}
