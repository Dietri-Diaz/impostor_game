// lib/core/constants.dart

/// Constantes globales de la app. Centralizar estos valores evita
/// inconsistencias entre pantallas que antes los duplicaban.
class GameConstants {
  GameConstants._();

  static const int minPlayers = 3;
  static const int maxPlayers = 12;

  static const int minCharacters = 3;
  static const int maxCharacters = 30;

  static const int minPlayerNameLength = 2;
  static const int maxPlayerNameLength = 20;

  static const int minTopicNameLength = 3;
  static const int maxTopicNameLength = 30;

  static const int defaultDiscussionSeconds = 120;
  static const int minImpostors = 1;

  /// Si quedan <= este número de jugadores vivos y el impostor sigue,
  /// gana el impostor.
  static const int impostorWinThreshold = 2;

  /// Límite de nombres recientes mostrados desde el historial.
  static const int recentNamesLimit = 50;

  /// Límite de sugerencias mientras el usuario escribe.
  static const int nameSuggestionsLimit = 10;
}
