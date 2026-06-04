# Rediseño IMPOSTOR "Minimal Bold" — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar todas las pantallas del juego con la identidad "Minimal Bold" (solo oscuro, Anton+Inter, paleta disciplinada), corregir el bug de partida borrada al regresar y eliminar errores visuales/glitches.

**Architecture:** Sistema de diseño primero. Se reconstruye `lib/core/app_theme.dart` **preservando los nombres de los getters públicos** (`AppTheme.textPrimary`, `AppColors.primary`, etc.) pero cambiando sus valores a un único modo oscuro Minimal Bold; esto hace que toda la app adopte la nueva paleta sin tocar cada pantalla. Luego se añaden componentes reutilizables nuevos, se corrigen los bugs con TDD, y finalmente se re-skinea cada pantalla. La lógica del juego (managers, repos, modelos) no se toca.

**Tech Stack:** Flutter/Dart, Provider, SharedPreferences, sqflite, confetti, fuentes incrustadas (Anton + Inter), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-02-rediseno-impostor-minimal-bold-design.md`

---

## Mapa de archivos

**Crear:**
- `assets/fonts/Anton-Regular.ttf`, `assets/fonts/Inter-Variable.ttf` — fuentes incrustadas (offline).
- `lib/core/app_colors.dart` — tokens de color (extraído de app_theme).
- `lib/core/app_typography.dart` — escala tipográfica (Anton/Inter).
- `lib/widgets/auto_fit_title.dart` — título auto-escalado (anti-desborde).
- `lib/widgets/app_button.dart` — botón con variantes + háptica.
- `lib/widgets/app_components.dart` — `AppScaffold`, `AppCard`, `AppChip`, `RoleBadge`, `AppSheet`.
- `test/home_session_test.dart`, `test/popscope_test.dart` — tests de bugs de navegación.

**Modificar:**
- `pubspec.yaml` — assets de fuentes + bloque `fonts:`.
- `lib/core/app_theme.dart` — reconstruir a dark-only, re-exportar tokens, page transitions.
- `lib/main.dart` — quitar `ThemeNotifier`, un solo `darkTheme`.
- `lib/services/preferences_service.dart` — quitar clave de tema, añadir `colorful_reveal`.
- Las 11 pantallas en `lib/screens/`.

**Eliminar:**
- `lib/core/theme_notifier.dart`.

---

## FASE 0 — Fundaciones (fuentes + pubspec)

### Task 0.1: Incrustar fuentes Anton + Inter

**Files:**
- Create: `assets/fonts/Anton-Regular.ttf`
- Create: `assets/fonts/Inter-Variable.ttf`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Descargar las fuentes (OFL, open source)**

Run (desde la raíz del proyecto `impostor_game`):
```bash
mkdir -p assets/fonts
curl -gL "https://github.com/google/fonts/raw/main/ofl/anton/Anton-Regular.ttf" -o assets/fonts/Anton-Regular.ttf
curl -gL "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf" -o assets/fonts/Inter-Variable.ttf
```

- [ ] **Step 2: Verificar que se descargaron (tamaño > 0)**

Run:
```bash
ls -la assets/fonts/
```
Expected: `Anton-Regular.ttf` (~150 KB) e `Inter-Variable.ttf` (~800 KB+), ambos con tamaño distinto de 0.
Si algún archivo quedó vacío o falló la descarga: reintentar; como fallback temporal, la app usará la fuente sans por defecto (no rompe, solo no se ve Anton/Inter).

- [ ] **Step 3: Declarar las fuentes y assets en `pubspec.yaml`**

En la sección `flutter:`, debajo de `uses-material-design: true`, añadir el bloque `fonts:` y la carpeta de fuentes a `assets:`:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/fonts/
    - assets/images/dragon_ball/
    # ... (resto de assets existentes sin cambios) ...
    - assets/audio/
  fonts:
    - family: Anton
      fonts:
        - asset: assets/fonts/Anton-Regular.ttf
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Variable.ttf
```

- [ ] **Step 4: Resolver dependencias**

Run:
```bash
flutter pub get
```
Expected: `Got dependencies!` sin errores.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml assets/fonts/
git commit -m "feat(ui): incrustar fuentes Anton + Inter para Minimal Bold"
```

---

## FASE 1 — Sistema de diseño

### Task 1.1: Tokens de color (`app_colors.dart`)

**Files:**
- Create: `lib/core/app_colors.dart`

- [ ] **Step 1: Crear el archivo de colores Minimal Bold**

```dart
// lib/core/app_colors.dart
import 'package:flutter/material.dart';

/// Paleta Minimal Bold (solo modo oscuro). Disciplina: tinta + blanco +
/// rojo (peligro/impostor) + verde menta (seguro/civil/victoria) + oro
/// (solo líder del marcador).
class AppColors {
  // Fondo / superficies
  static const Color ink = Color(0xFF0B0B0D);
  static const Color surface = Color(0xFF16161A);
  static const Color surfaceHigh = Color(0xFF1F1F25);

  // Texto
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9AA2);
  static const Color textMuted = Color(0xFF6B6B73);

  // Acentos semánticos
  static const Color danger = Color(0xFFE0223E);   // impostor / derrota
  static const Color dangerDark = Color(0xFF8B0E22);
  static const Color safe = Color(0xFF22C55E);      // civil / victoria
  static const Color safeDark = Color(0xFF04210F);
  static const Color gold = Color(0xFFFFD700);      // solo #1 del ranking

  // Neutros
  static const Color white = Colors.white;
  static const Color black = Colors.black;

  // Bordes
  static const Color border = Color(0x14FFFFFF); // white @ ~8%

  // --- Alias de compatibilidad (mantienen compilando el código existente
  //     hasta que cada pantalla se re-skinee) ---
  static const Color primary = danger;
  static const Color primaryLight = Color(0xFFFF5C72);
  static const Color primaryDark = dangerDark;
  static const Color accent = safe;
  static const Color accentAlt = Color(0xFFF7971E);
  static const Color purple = Color(0xFF8B7CFF);
  static const Color impostor = danger;
  static const Color impostorDark = dangerDark;
  static const Color civil = safe;
  static const Color civilDark = safeDark;
  static const Color victory = safe;
  static const Color victoryLight = Color(0xFF4ADE80);
  static const Color defeat = danger;

  static const Color darkBg1 = ink;
  static const Color darkBg2 = surface;
  static const Color darkBg3 = surfaceHigh;
  static const Color darkSurface = surface;
  static const Color darkCard = surface;
  // light* eliminados conceptualmente; se mapean a oscuro por seguridad.
  static const Color lightBg1 = ink;
  static const Color lightBg2 = surface;
  static const Color lightCard = surface;
  static const Color lightSurface = surface;

  // Gradientes (se conservan los usados en momentos dramáticos)
  static const List<Color> primaryGradient = [danger, Color(0xFFFF5C72)];
  static const List<Color> darkBgGradient = [ink, Color(0xFF0E0E12), ink];
  static const List<Color> lightBgGradient = darkBgGradient;
  static const List<Color> victoryGradient = [safe, Color(0xFF16A34A)];
  static const List<Color> defeatGradient = [dangerDark, danger];
  static const List<Color> accentGradient = [safe, Color(0xFF16A34A)];
  static const List<Color> purpleGradient = [Color(0xFF8B7CFF), Color(0xFF6D5BD6)];
  static const List<Color> goldGradient = [Color(0xFFF7C948), gold];

  // Gradientes de tarjetas para temáticas (se mantienen para los logos)
  static const List<List<Color>> cardGradients = [
    [danger, Color(0xFFFF5C72)],
    [safe, Color(0xFF16A34A)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    [Color(0xFF8B7CFF), Color(0xFF6D5BD6)],
    [Color(0xFFf093fb), Color(0xFFf5576c)],
    [Color(0xFF4facfe), Color(0xFF00f2fe)],
    [safe, Color(0xFF38f9d7)],
    [Color(0xFFfa709a), Color(0xFFfee140)],
  ];
}
```

- [ ] **Step 2: Verificar compilación de tokens**

Run:
```bash
flutter analyze lib/core/app_colors.dart
```
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/core/app_colors.dart
git commit -m "feat(ui): tokens de color Minimal Bold (app_colors)"
```

### Task 1.2: Escala tipográfica (`app_typography.dart`)

**Files:**
- Create: `lib/core/app_typography.dart`

- [ ] **Step 1: Crear la escala tipográfica**

```dart
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
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/core/app_typography.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/core/app_typography.dart
git commit -m "feat(ui): escala tipográfica Anton+Inter (app_typography)"
```

### Task 1.3: `AutoFitTitle` (anti-desborde)

**Files:**
- Create: `lib/widgets/auto_fit_title.dart`
- Test: `test/auto_fit_title_test.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/auto_fit_title_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/widgets/auto_fit_title.dart';

void main() {
  testWidgets('AutoFitTitle no desborda en ancho muy estrecho', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 80, // muy angosto
          child: AutoFitTitle('IMPOSTOR', style: TextStyle(fontSize: 80)),
        ),
      ),
    ));
    // Si hubiera overflow, el framework habría lanzado una excepción.
    expect(tester.takeException(), isNull);
    expect(find.text('IMPOSTOR'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar el test para verificar que falla**

Run: `flutter test test/auto_fit_title_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:impostor_game/widgets/auto_fit_title.dart'`.

- [ ] **Step 3: Implementar `AutoFitTitle`**

```dart
// lib/widgets/auto_fit_title.dart
import 'package:flutter/material.dart';

/// Título que se reduce para caber en el ancho disponible — nunca desborda
/// ni se corta, sin importar el tamaño del celular. Usa FittedBox sobre una
/// sola línea (o varias si se pasan `maxLines`).
class AutoFitTitle extends StatelessWidget {
  const AutoFitTitle(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        softWrap: maxLines > 1,
        style: style,
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar el test para verificar que pasa**

Run: `flutter test test/auto_fit_title_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/auto_fit_title.dart test/auto_fit_title_test.dart
git commit -m "feat(ui): AutoFitTitle anti-desborde + test"
```

### Task 1.4: `AppButton` (variantes + háptica)

**Files:**
- Create: `lib/widgets/app_button.dart`

- [ ] **Step 1: Implementar el botón**

```dart
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
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/widgets/app_button.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/app_button.dart
git commit -m "feat(ui): AppButton con variantes y háptica"
```

### Task 1.5: Componentes base (`app_components.dart`)

**Files:**
- Create: `lib/widgets/app_components.dart`

- [ ] **Step 1: Implementar `AppScaffold`, `AppCard`, `AppChip`, `RoleBadge`, `AppSheet`**

```dart
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

/// Tarjeta sobria Minimal Bold (sin gradientes ruidosos).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.selected = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool selected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? (accent ?? AppColors.danger)
        : AppColors.border;
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
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
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/widgets/app_components.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/app_components.dart
git commit -m "feat(ui): componentes base (AppScaffold, AppCard, AppChip, AppSheet)"
```

### Task 1.6: Reconstruir `app_theme.dart` a dark-only (preservando API)

**Files:**
- Modify: `lib/core/app_theme.dart` (reemplazo completo)

> Mantiene los nombres de getters usados por las pantallas (`AppTheme.textPrimary`, `AppTheme.cardColor`, `AppTheme.backgroundGradient`, `AppTheme.isDark`, `GradientBackground`, `PrimaryButton`, `AppHeader`, `AppCard` legacy, `SlidePageRoute`, `FadeScalePageRoute`) para no romper compilación; `isDark` queda como shim `=> true`. Re-exporta `AppColors` desde `app_colors.dart`.

- [ ] **Step 1: Reemplazar el contenido de `app_theme.dart`**

```dart
// lib/core/app_theme.dart
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';

/// Tema Minimal Bold — SOLO modo oscuro. Los getters conservan sus nombres
/// históricos para no romper las pantallas existentes; `isDark` es un shim
/// que siempre devuelve true.
class AppTheme {
  static bool get isDark => true; // compat shim (la app es solo-oscuro)

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
/// Internamente reusa el estilo Minimal Bold.
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
    // Si recibe gradient (momentos especiales), lo respeta; si no, botón blanco.
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

/// Tarjeta legacy (compat). Reusa superficie sobria; ignora gradientes salvo
/// que se pasen explícitamente para momentos dramáticos.
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
```

- [ ] **Step 2: Verificar que toda la app sigue compilando**

Run: `flutter analyze`
Expected: Sin errores nuevos. (Puede haber warnings preexistentes; no introducir nuevos errores.)

- [ ] **Step 3: Commit**

```bash
git add lib/core/app_theme.dart
git commit -m "refactor(ui): app_theme dark-only Minimal Bold (API preservada)"
```

---

## FASE 2 — Solo oscuro (quitar ThemeNotifier)

### Task 2.1: Simplificar `main.dart` y eliminar `theme_notifier.dart`

**Files:**
- Modify: `lib/main.dart`
- Delete: `lib/core/theme_notifier.dart`

- [ ] **Step 1: Reemplazar `main.dart`**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final sharedPrefs = await SharedPreferences.getInstance();
  final prefs = PreferencesService(sharedPrefs);

  runApp(
    Provider<PreferencesService>.value(
      value: prefs,
      child: const ImpostorGame(),
    ),
  );
}

class ImpostorGame extends StatelessWidget {
  const ImpostorGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impostor Game',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: Eliminar el notifier de tema**

Run:
```bash
git rm lib/core/theme_notifier.dart
```

- [ ] **Step 3: Quitar el botón de toggle de tema en `home_screen.dart`**

En `lib/screens/home_screen.dart`, eliminar el import `import '../core/theme_notifier.dart';` y borrar el `IconButton` del toggle de tema (el primero dentro del `Row` en `Positioned(top:10,right:10,...)`, líneas ~512-523, el que usa `context.read<ThemeNotifier>().toggle()`). Dejar los botones de sonido y ajustes.

- [ ] **Step 4: Verificar compilación**

Run: `flutter analyze`
Expected: Sin errores. Si aparece "Undefined name 'ThemeNotifier'", quedó una referencia — eliminarla.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor(ui): solo modo oscuro — eliminar ThemeNotifier y toggle de tema"
```

### Task 2.2: Limpiar `PreferencesService` (quitar tema, añadir colorful_reveal)

**Files:**
- Modify: `lib/services/preferences_service.dart`

- [ ] **Step 1: Editar las claves**

Quitar el bloque `// ---------- Tema ----------` (clave `_kIsDark`, getter `isDark`, `setIsDark`). Añadir el ajuste de revelación a todo color:
```dart
  // ---------- Gameplay ----------
  static const String _kSkipPasaTelefono = 'gameplay.skip_pasa_telefono';
  bool get skipPasaTelefono => _prefs.getBool(_kSkipPasaTelefono) ?? false;
  Future<void> setSkipPasaTelefono(bool value) =>
      _prefs.setBool(_kSkipPasaTelefono, value);

  static const String _kColorfulReveal = 'gameplay.colorful_reveal';
  bool get colorfulReveal => _prefs.getBool(_kColorfulReveal) ?? false;
  Future<void> setColorfulReveal(bool value) =>
      _prefs.setBool(_kColorfulReveal, value);
```

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/services/preferences_service.dart`
Expected: "No issues found!" (`ThemeNotifier` ya no usa `isDark`, eliminado en 2.1).

- [ ] **Step 3: Commit**

```bash
git add lib/services/preferences_service.dart
git commit -m "feat(settings): quitar pref de tema, añadir colorful_reveal"
```

---

## FASE 3 — Corrección de bugs (TDD)

### Task 3.1: Bug principal — "JUGAR AHORA" no debe borrar la sesión guardada

**Files:**
- Test: `test/home_session_test.dart`
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Escribir el test que falla**

```dart
// test/home_session_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:impostor_game/services/preferences_service.dart';
import 'package:impostor_game/screens/home_screen.dart';

void main() {
  testWidgets(
      'Tocar "JUGAR AHORA" y regresar NO borra la sesión guardada',
      (tester) async {
    // Sesión previa válida persistida.
    const sessionJson =
        '{"tematica":"Marvel","nombresJugadores":["A","B","C"],'
        '"configuracion":{"tiempoDiscusion":120,"eliminarEnEmpate":false,'
        '"numeroImpostores":1},"historialRondas":[],"puntuacion":{}}';
    SharedPreferences.setMockInitialValues({'session.active': sessionJson});
    final prefs = PreferencesService(await SharedPreferences.getInstance());

    await tester.pumpWidget(MaterialApp(
      home: Provider<PreferencesService>.value(
        value: prefs,
        child: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // Tocar JUGAR AHORA.
    await tester.tap(find.text('JUGAR AHORA'));
    await tester.pumpAndSettle();

    // Regresar inmediatamente a Home.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();

    // La sesión guardada debe seguir intacta.
    expect(prefs.activeSessionJson, isNotNull);
    expect(prefs.activeSessionJson, contains('Marvel'));
  });
}
```

- [ ] **Step 2: Ejecutar para verificar que falla**

Run: `flutter test test/home_session_test.dart`
Expected: FAIL — `activeSessionJson` es `null` porque "JUGAR AHORA" llama `clearActiveSession()`.

- [ ] **Step 3: Quitar el borrado prematuro en `home_screen.dart`**

En el `onPressed` del botón "JUGAR AHORA" (~líneas 412-427), eliminar las dos líneas que borran la sesión:
```dart
// ELIMINAR estas líneas:
await context.read<PreferencesService>().clearActiveSession();
if (!context.mounted) return;
```
El handler queda:
```dart
onPressed: () async {
  AudioService.playClick();
  await Navigator.push<void>(
    context,
    FadeScalePageRoute<void>(page: const ConfigurarPartidaScreen()),
  );
  if (mounted) setState(() {});
},
```
> La sesión nueva solo sobrescribe la guardada cuando llega al Lobby (`LobbyScreen.initState` → `saveNow()`), no antes. Así, regresar a media configuración conserva la partida anterior.

- [ ] **Step 4: Ejecutar para verificar que pasa**

Run: `flutter test test/home_session_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test/home_session_test.dart lib/screens/home_screen.dart
git commit -m "fix(nav): no borrar sesión guardada al iniciar configuración (+test)"
```

### Task 3.2: `PopScope` de confirmación en el Lobby

**Files:**
- Modify: `lib/screens/lobby_screen.dart`

- [ ] **Step 1: Envolver `_LobbyView` con `PopScope`**

En `_LobbyViewState.build`, envolver el `Scaffold` raíz con `PopScope(canPop: false, onPopInvokedWithResult: ...)` que dispare el mismo diálogo `_salirAlInicio`. Reemplazar el `return Scaffold(...)` por:
```dart
return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _salirAlInicio();
  },
  child: Scaffold(
    // ... contenido existente sin cambios ...
  ),
);
```
> El botón atrás físico ahora pasa por la misma confirmación que la flecha del header. Salir NO borra la sesión (solo el botón "Salir" del diálogo lo hace), así que "Continuar" permanece disponible.

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/screens/lobby_screen.dart`
Expected: Sin errores nuevos.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/lobby_screen.dart
git commit -m "fix(nav): PopScope con confirmación en el Lobby"
```

### Task 3.3: `PopScope` de confirmación en Votación

**Files:**
- Modify: `lib/screens/votacion_screen.dart`

- [ ] **Step 1: Añadir el diálogo de confirmación y `PopScope`**

En `_VotacionScreenState`, añadir un método:
```dart
Future<void> _confirmarSalir() async {
  final salir = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('¿Salir de la ronda?', style: AppType.titleL),
      content: const Text(
        'Volverás al lobby y se perderá la discusión y los votos de esta ronda.',
        style: AppType.body_,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Salir',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (salir == true && mounted) Navigator.of(context).pop();
}
```
Añadir el import `import '../core/app_colors.dart';` y `import '../core/app_typography.dart';` si no están. Envolver el `Scaffold` raíz del `build` con:
```dart
return PopScope(
  canPop: false,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    _confirmarSalir();
  },
  child: Scaffold( /* ... */ ),
);
```
También cambiar el `onBack` del `AppHeader` para que use `_confirmarSalir` en vez de `Navigator.pop` directo.

- [ ] **Step 2: Verificar**

Run: `flutter analyze lib/screens/votacion_screen.dart`
Expected: Sin errores nuevos.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/votacion_screen.dart
git commit -m "fix(nav): confirmar antes de salir de la votación (PopScope)"
```

---

## FASE 4 — Re-skin de pantallas

> Patrón general para cada pantalla: usar `AppColors`/`AppType` nuevos, `AutoFitTitle` para titulares grandes, `AppButton` (o `PrimaryButton` legacy ya estilizado), `AppCard`/`AppSheet`/`AppChip`. Reemplazar cualquier `AppTheme.isDark ? AppColors.darkBg2 : AppColors.lightBg2` por `AppColors.surface` (o `AppSheet`). Cada tarea termina con `flutter analyze` (sin errores nuevos) y commit. Donde haya titulares grandes, añadir/usar `AutoFitTitle`.

### Task 4.1: HomeScreen

**Files:** Modify `lib/screens/home_screen.dart`

- [ ] **Step 1:** Reemplazar el título "IMPOSTOR" (Text con fontSize calculado) por `AutoFitTitle('IMPOSTOR', style: AppType.displayXL)`. Quitar la capa `_ParticlesLayer` (o reducirla a un degradado sutil) para el look limpio. Convertir el botón "JUGAR AHORA" a `AppButton(text: 'Jugar ahora', icon: Icons.play_arrow_rounded, variant: AppButtonVariant.primary)`. "Continuar" como `AppButton(variant: safe)`. Las filas de features con `AppCard` sobrio. Reemplazar la hoja de Ajustes (`showModalBottomSheet`) para usar `AppSheet` y añadir el toggle **"Pantalla a todo color"** (lee/escribe `prefs.colorfulReveal`).
- [ ] **Step 2:** `flutter analyze lib/screens/home_screen.dart` → sin errores.
- [ ] **Step 3:** Commit: `style(home): rediseño Minimal Bold + toggle pantalla a todo color`.

### Task 4.2: ConfigurarPartidaScreen (temáticas)

**Files:** Modify `lib/screens/configurar_partida_screen.dart`

- [ ] **Step 1:** Grid de temáticas con `AppCard` (selección por borde/realce, sin gradiente saturado salvo el realce de seleccionado). Título de logo con `AppType.titleM`. Botón "CONTINUAR" → `AppButton`.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(temáticas): rediseño Minimal Bold`.

### Task 4.3: ConfigurarJugadoresScreen

**Files:** Modify `lib/screens/configurar_jugadores_screen.dart`

- [ ] **Step 1:** Reemplazar los `AppTheme.isDark ? darkBg2 : lightBg2` (2 ocurrencias) por `AppColors.surface` / `AppSheet`. Filas de jugador con `AppCard`. Botón "INICIAR PARTIDA" → `AppButton`. Hoja de configuración con `AppSheet`. Conservar autocompletado/historial.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(jugadores): rediseño Minimal Bold`.

### Task 4.4: LobbyScreen

**Files:** Modify `lib/screens/lobby_screen.dart`

- [ ] **Step 1:** Reemplazar `darkBg2/lightBg2` (2) por `AppColors.surface`/`AppSheet`. Jugadores como `AppChip(color: AppColors.safe)`. Marcador con #1 en `AppColors.gold`. Botones a `AppButton`. Título "Sala de Juego" con `AppType.titleL`. Mantener selector de impostores e historial (re-estilizados con `AppCard`).
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(lobby): rediseño Minimal Bold`.

### Task 4.5: PasarTelefonoScreen

**Files:** Modify `lib/screens/pasar_telefono_screen.dart`

- [ ] **Step 1:** Fondo tinta. Nombre del jugador con `AutoFitTitle(..., style: AppType.displayM)` (anti-desborde para nombres largos). Botón "ESTOY LISTO" → `AppButton`. Ícono y aviso re-estilizados sobrios.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(pasar-teléfono): rediseño Minimal Bold`.

### Task 4.6: RevelarRolesScreen (revelación discreta + modo color opcional)

**Files:** Modify `lib/screens/revelar_roles_screen.dart`

- [ ] **Step 1: Leer el ajuste de color al construir la revelación.** En `_buildRolReveal`, leer `final colorful = context.read<PreferencesService>().colorfulReveal;`.
- [ ] **Step 2: Layout "ícono protagonista" + fondo discreto por defecto.** Reescribir `_buildRolReveal` con estructura limpia (corrige la indentación irregular actual):
  - **Fondo:** si `colorful` → impostor `[AppColors.dangerDark, AppColors.danger]`, civil `[AppColors.safeDark, AppColors.safe]`. Si **no** `colorful` (default) → **mismo** `AppColors.darkBgGradient` para ambos (anti-spoiler).
  - **Contenido (ícono protagonista):** nombre arriba (pequeño), centro = anillo circular (borde rojo + ☠️ para impostor / borde menta + avatar del personaje para civil), etiqueta (`AppType.label`: "TU ROL" / "EL PERSONAJE ES"), chip (`AppChip` rojo "IMPOSTOR" / menta con el nombre del personaje), texto de ayuda (`AppType.bodyS`), botón "Ocultar" → `AppButton` (blanco si fondo oscuro; tinta si fondo color).
  - Usar `AutoFitTitle` para el nombre del personaje en el chip si puede ser largo.
  - Conservar el `_CharacterAvatar` existente para la imagen del personaje.
  - Confetti: en modo discreto, usar colores neutros/suaves; en modo color, los actuales por rol.
- [ ] **Step 3:** `flutter analyze lib/screens/revelar_roles_screen.dart` → sin errores.
- [ ] **Step 4:** Commit: `feat(revelar): revelación discreta anti-spoiler + modo color opcional`.

### Task 4.7: VotacionScreen

**Files:** Modify `lib/screens/votacion_screen.dart`

- [ ] **Step 1:** Temporizador grande con `AutoFitTitle` (mm:ss) en `AppCard`. Reemplazar el `ExpansionTile` clunky de `_VoteSelector` por una hoja `AppSheet` (al tocar "Votar", abrir hoja con la lista de jugadores) o por tarjetas seleccionables claras. Botones a `AppButton`. Voto unánime con `AppCard` seleccionable. Mantener la lógica de votos intacta.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(votación): rediseño Minimal Bold + selector de voto claro`.

### Task 4.8: ResultadoRondaScreen

**Files:** Modify `lib/screens/resultado_ronda_screen.dart`

- [ ] **Step 1:** Título principal con `AutoFitTitle` (`displayL`). Bloques de color audaces: victoria `AppColors.victoryGradient`, derrota `AppColors.defeatGradient`, empate naranja. Tarjeta de info y conteo de votos con superficie sobria (sobre el fondo de color, usar tarjetas blancas/translúcidas legibles). Botones a `AppButton`. Mantener auto-retorno al lobby.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(resultado-ronda): rediseño Minimal Bold`.

### Task 4.9: ResultadoFinalScreen

**Files:** Modify `lib/screens/resultado_final_screen.dart`

- [ ] **Step 1:** Título "¡VICTORIA!" / "¡EL IMPOSTOR GANA!" con `AutoFitTitle` (`displayL`). Revelación de personaje e impostores con tarjetas sobrias. Marcador con #1 en oro. Confetti **discreto** (reducir `numberOfParticles` y usar paleta acorde: verdes/blancos) solo en victoria. Botones a `AppButton`.
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(resultado-final): rediseño Minimal Bold`.

### Task 4.10: ReglasScreen

**Files:** Modify `lib/screens/reglas_screen.dart`

- [ ] **Step 1:** Aplicar paleta/tipografía nuevas; títulos de página con `AutoFitTitle` donde sean grandes; botones a `AppButton`; PageView conservado. (Leer el archivo primero para mapear su estructura.)
- [ ] **Step 2:** `flutter analyze` del archivo → sin errores.
- [ ] **Step 3:** Commit: `style(reglas): rediseño Minimal Bold`.

### Task 4.11: ListaTematicasScreen + CrearTematicaScreen

**Files:** Modify `lib/screens/lista_tematicas_screen.dart`, `lib/screens/crear_tematica_screen.dart`

- [ ] **Step 1:** Reemplazar `darkBg2/lightBg2` por `AppColors.surface`/`AppSheet`. Tarjetas y formularios con `AppCard`/inputs del tema. Botones a `AppButton`. Barra de progreso de personajes con `AppColors.safe`/`danger`. (Leer ambos archivos primero.)
- [ ] **Step 2:** `flutter analyze` de ambos archivos → sin errores.
- [ ] **Step 3:** Commit: `style(temáticas-custom): rediseño Minimal Bold`.

---

## FASE 5 — Verificación final

### Task 5.1: Análisis estático y tests completos

- [ ] **Step 1:** Run `flutter analyze`. Expected: sin errores (warnings preexistentes tolerados, no nuevos).
- [ ] **Step 2:** Run `flutter test`. Expected: todos los tests pasan (incluye los nuevos `home_session_test`, `auto_fit_title_test` y los existentes).
- [ ] **Step 3:** Run la app y verificar manualmente el flujo crítico:
  - Iniciar partida con sesión guardada → tocar "Jugar ahora" → regresar → "Continuar" sigue ahí. ✅
  - Atrás físico en Lobby/Votación → confirma. ✅
  - Revelación discreta por defecto; activar "Pantalla a todo color" en Ajustes → revelación a color. ✅
  - Revisar que ningún título se desborde (probar en un emulador chico, p. ej. pixel 4a o iPhone SE).
- [ ] **Step 4: Commit final si hubo ajustes**

```bash
git add -A
git commit -m "chore: verificación final del rediseño Minimal Bold"
```

### Task 5.2: Actualizar CLAUDE.md

**Files:** Modify `CLAUDE.md`

- [ ] **Step 1:** En la sección de tareas completadas, anotar el rediseño Minimal Bold (solo oscuro, Anton/Inter), la revelación discreta anti-spoiler con modo color opcional, y los fixes (sesión no se borra al regresar, PopScope en Lobby/Votación, tema unificado).
- [ ] **Step 2:** Commit: `docs: actualizar CLAUDE.md con el rediseño Minimal Bold`.

---

## Self-Review (cobertura del spec)

- **Dirección Minimal Bold** → Fases 1 y 4. ✅
- **Anton/Inter incrustadas (offline)** → Task 0.1. ✅
- **Solo oscuro / quitar ThemeNotifier / fix tema roto** → Fase 2 + Task 1.6. ✅
- **Bug partida borrada al regresar** → Task 3.1 (con test). ✅
- **PopScope Lobby/Votación** → Tasks 3.2, 3.3. ✅
- **Anti-desborde de texto** → Task 1.3 (`AutoFitTitle` + test) y uso en Fase 4. ✅
- **Revelación discreta + modo color opcional** → Tasks 1.x (tokens), 2.2 (pref), 4.1 (toggle en Ajustes), 4.6 (pantalla). ✅
- **Paleta disciplinada** → Task 1.1. ✅
- **Todas las pantallas re-skineadas** → Tasks 4.1–4.11 (11 pantallas). ✅
- **Háptica/pulido** → Tasks 1.4 (AppButton), 4.6. ✅
- **Sin cambios a lógica/DB** → respetado en todo el plan. ✅
- **Criterios de éxito (analyze/test)** → Fase 5. ✅

Notas de consistencia: el ajuste se llama `colorfulReveal` en `PreferencesService` (Task 2.2) y se lee igual en Home (4.1) y Revelar (4.6). `AutoFitTitle` se define en Task 1.3 y se usa en 4.1/4.5/4.6/4.7/4.8/4.9/4.10. `AppButton`/variantes definidas en 1.4 y usadas en toda la Fase 4.
