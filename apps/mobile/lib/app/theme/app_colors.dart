import 'package:flutter/material.dart';

/// Tokens from docs/design-tokens.md. Do not add colors outside that file.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF059669);
  static const primaryDark = Color(0xFF047857);
  static const primaryTint = Color(0xFFECFDF5);
  static const primaryTintStrong = Color(0xFFD1FAE5);
  static const bg = Color(0xFFF4F6F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const text = Color(0xFF1E293B);
  static const text2 = Color(0xFF334155);
  static const textMuted = Color(0xFF64748B);
  static const warning = Color(0xFFF59E0B);
  static const warningTint = Color(0xFFFFFBEB);
  static const info = Color(0xFF2563EB);
  static const infoTint = Color(0xFFEFF6FF);
  static const error = Color(0xFFDC2626);
  static const errorTint = Color(0xFFFEF2F2);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );
}
