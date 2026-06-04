// lib/widgets/app_components.dart
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';

/// Fondo tinta + SafeArea estándar.
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child, this.backgroundColor});
  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.ink,
      body: SafeArea(child: child),
    );
  }
}

/// Chip pequeño (jugadores, etiquetas).
class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: AppType.titleM.copyWith(
        color: AppColors.textPrimary, fontSize: 14)),
    );
  }
}

/// Hoja inferior estándar (reemplaza los `AppTheme.isDark ? darkBg2 : lightBg2`).
class AppSheet extends StatelessWidget {
  const AppSheet({super.key, required this.child, this.maxHeight});
  final Widget child;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : const BoxConstraints(),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(child: child),
        ],
      ),
    );
  }
}
