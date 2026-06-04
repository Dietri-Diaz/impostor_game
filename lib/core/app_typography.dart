// lib/core/app_typography.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Tipografía Minimal Bold: Anton para display/títulos, Inter para cuerpo.
class AppType {
  static const String display = 'Anton';
  static const String body = 'Inter';

  // Display (Anton) — para titulares grandes. Úsese SIEMPRE dentro de
  // AutoFitTitle para evitar desbordes.
  static const TextStyle displayXL = TextStyle(
    fontFamily: display, fontSize: 56, height: 0.95,
    letterSpacing: 1, color: AppColors.textPrimary,
  );
  static const TextStyle displayL = TextStyle(
    fontFamily: display, fontSize: 40, height: 0.98,
    letterSpacing: 1, color: AppColors.textPrimary,
  );
  static const TextStyle displayM = TextStyle(
    fontFamily: display, fontSize: 28, height: 1.0,
    letterSpacing: 0.5, color: AppColors.textPrimary,
  );

  // Títulos / cuerpo (Inter)
  static const TextStyle titleL = TextStyle(
    fontFamily: body, fontSize: 20, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const TextStyle titleM = TextStyle(
    fontFamily: body, fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle body_ = TextStyle(
    fontFamily: body, fontSize: 15, height: 1.5,
    color: AppColors.textSecondary,
  );
  static const TextStyle bodyS = TextStyle(
    fontFamily: body, fontSize: 13, color: AppColors.textMuted,
  );
  static const TextStyle label = TextStyle(
    fontFamily: body, fontSize: 11, fontWeight: FontWeight.w600,
    letterSpacing: 2, color: AppColors.textMuted,
  );
  static const TextStyle button = TextStyle(
    fontFamily: body, fontSize: 16, fontWeight: FontWeight.w700,
    letterSpacing: 0.5, color: AppColors.ink,
  );
}
