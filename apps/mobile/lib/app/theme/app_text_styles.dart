import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppText {
  const AppText._();

  static const h1 = TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.2, color: AppColors.text);
  static const h2 = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text);
  static const title = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, color: AppColors.text2);
  static const caption = TextStyle(fontSize: 12, color: AppColors.textMuted);
  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
}
