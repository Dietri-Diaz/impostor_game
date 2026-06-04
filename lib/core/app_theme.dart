// lib/core/app_theme.dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';

/// Tema Minimal Bold — SOLO modo oscuro. Los getters conservan sus nombres
/// históricos para no romper las pantallas existentes; `isDark` es un shim
/// que siempre devuelve true.
class AppTheme {
  static List<Color> get backgroundGradient => AppColors.darkBgGradient;
  static Color get backgroundColor => AppColors.ink;
  static Color get surfaceColor => AppColors.surface;
  static Color get cardColor => AppColors.surface;
  static Color get sheetColor => AppColors.surface;
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textMuted => AppColors.textMuted;
  static Color get dividerColor => AppColors.border;
  static Color get cardBorder => AppColors.border;
  static Color get iconColor => AppColors.textPrimary;

  // Estilos de texto legacy → mapeados a la nueva escala
  static TextStyle get headingLarge => AppType.displayL;
  static TextStyle get headingMedium => AppType.displayM;
  static TextStyle get headingSmall => AppType.titleL;
  static TextStyle get titleLarge => AppType.titleL;
  static TextStyle get titleMedium => AppType.titleM;
  static TextStyle get bodyLarge => AppType.body_;
  static TextStyle get bodyMedium => AppType.body_.copyWith(fontSize: 14);
  static TextStyle get bodySmall => AppType.bodyS;
  static TextStyle get buttonText =>
      AppType.button.copyWith(color: AppColors.white);

  static BoxDecoration get backgroundDecoration => const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: AppColors.darkBgGradient,
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: AppType.body,
        scaffoldBackgroundColor: AppColors.ink,
        primaryColor: AppColors.danger,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.danger,
          secondary: AppColors.safe,
          surface: AppColors.surface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: AppColors.textMuted),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
        ),
      );
}

/// Fondo con gradiente tinta (compat con pantallas existentes).
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child, this.colors});
  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: colors ?? AppColors.darkBgGradient,
        ),
      ),
      child: child,
    );
  }
}

/// Botón legacy (mantiene la firma usada por pantallas aún no re-skineadas).
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.height = 56,
    this.gradient,
  });
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final List<Color>? gradient;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this, lowerBound: 0.96, upperBound: 1.0, value: 1.0,
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasGradient = widget.gradient != null;
    final fg = hasGradient ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTapDown: (_) => _c.reverse(),
      onTapUp: (_) {
        _c.forward();
        widget.onPressed?.call();
      },
      onTapCancel: () => _c.forward(),
      child: ScaleTransition(
        scale: _c,
        child: Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: hasGradient ? null : AppColors.white,
            gradient: hasGradient ? LinearGradient(colors: widget.gradient!) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 22, color: fg),
                const SizedBox(width: 10),
              ],
              Text(widget.text,
                  style: AppType.button.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta legacy (compat). Reusa superficie sobria; respeta gradientes solo
/// si se pasan explícitamente para momentos dramáticos.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.borderColor,
    this.borderRadius = 18,
    this.onTap,
    this.selected = false,
  });
  final Widget child;
  final EdgeInsets? padding;
  final List<Color>? gradient;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final w = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient != null ? LinearGradient(colors: gradient!) : null,
        color: gradient == null ? AppColors.surface : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: selected
              ? AppColors.white.withValues(alpha: 0.4)
              : (borderColor ?? AppColors.border),
          width: selected ? 2 : 1,
        ),
      ),
      child: child,
    );
    if (onTap == null) return w;
    return GestureDetector(onTap: onTap, child: w);
  }
}

/// Header con botón atrás opcional.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.onBack, this.actions});
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary),
              onPressed: onBack,
            ),
          Expanded(child: Text(title, style: AppType.titleL)),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Transición estándar: deslizar + fundido.
class SlidePageRoute<T> extends PageRouteBuilder<T> {
  SlidePageRoute({required this.page})
      : super(
          pageBuilder: (c, a, s) => page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          transitionsBuilder: (c, a, s, child) {
            final curved = CurvedAnimation(
                parent: a, curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic);
            return SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(1, 0), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
  final Widget page;
}

/// Transición para momentos especiales: fundido + escala.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  FadeScalePageRoute({required this.page})
      : super(
          pageBuilder: (c, a, s) => page,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (c, a, s, child) {
            final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        );
  final Widget page;
}
