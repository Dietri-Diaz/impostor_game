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

  // Gradientes (se conservan los usados en momentos dramáticos)
  static const List<Color> primaryGradient = [danger, Color(0xFFFF5C72)];
  static const List<Color> darkBgGradient = [ink, Color(0xFF0E0E12), ink];
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
