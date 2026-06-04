// lib/widgets/app_button.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_typography.dart';

enum AppButtonVariant { primary, secondary, danger, safe }

/// Botón Minimal Bold con micro-escala al presionar y háptica ligera.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.height = 56,
  });

  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final double height;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this, lowerBound: 0.96, upperBound: 1.0, value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ({Color bg, Color fg, Border? border}) get _style {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return (bg: AppColors.white, fg: AppColors.ink, border: null);
      case AppButtonVariant.secondary:
        return (bg: Colors.transparent, fg: AppColors.textPrimary,
                border: Border.all(color: AppColors.border, width: 1.5));
      case AppButtonVariant.danger:
        return (bg: AppColors.danger, fg: AppColors.white, border: null);
      case AppButtonVariant.safe:
        return (bg: AppColors.safe, fg: AppColors.safeDark, border: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        if (widget.onPressed != null) {
          HapticFeedback.lightImpact();
          widget.onPressed!();
        }
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(
        scale: _c,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: s.bg,
            borderRadius: BorderRadius.circular(16),
            border: s.border,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: s.fg),
                const SizedBox(width: 10),
              ],
              Text(widget.text, style: AppType.button.copyWith(color: s.fg)),
            ],
          ),
        ),
      ),
    );
  }
}
