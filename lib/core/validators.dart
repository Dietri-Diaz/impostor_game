// lib/core/validators.dart

import 'constants.dart';

/// Validadores reutilizables. Centralizan reglas que antes se duplicaban en
/// `ConfigurarJugadoresScreen` y `CrearTematicaScreen`.
class Validators {
  Validators._();

  /// Devuelve `null` si el nombre es válido, o un mensaje de error.
  static String? playerName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'El nombre no puede estar vacío';
    if (value.length < GameConstants.minPlayerNameLength) {
      return 'Mínimo ${GameConstants.minPlayerNameLength} caracteres';
    }
    if (value.length > GameConstants.maxPlayerNameLength) {
      return 'Máximo ${GameConstants.maxPlayerNameLength} caracteres';
    }
    return null;
  }

  /// Verifica que la lista no contenga duplicados (case-insensitive,
  /// ignorando espacios). Devuelve el primer nombre repetido o `null`.
  static String? findDuplicate(List<String> names) {
    final seen = <String>{};
    for (final n in names) {
      final key = n.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (!seen.add(key)) return n.trim();
    }
    return null;
  }

  /// Valida la lista completa de jugadores. Devuelve `null` si todo está bien.
  static String? playerList(List<String> names) {
    if (names.length < GameConstants.minPlayers) {
      return 'Mínimo ${GameConstants.minPlayers} jugadores';
    }
    if (names.length > GameConstants.maxPlayers) {
      return 'Máximo ${GameConstants.maxPlayers} jugadores';
    }
    for (final n in names) {
      final err = playerName(n);
      if (err != null) return err;
    }
    final dup = findDuplicate(names);
    if (dup != null) return 'Nombre repetido: "$dup"';
    return null;
  }

  /// Valida el nombre de una temática personalizada.
  static String? topicName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'El nombre no puede estar vacío';
    if (value.length < GameConstants.minTopicNameLength) {
      return 'Mínimo ${GameConstants.minTopicNameLength} caracteres';
    }
    if (value.length > GameConstants.maxTopicNameLength) {
      return 'Máximo ${GameConstants.maxTopicNameLength} caracteres';
    }
    return null;
  }

  /// Valida el nombre de un personaje dentro de una temática.
  static String? characterName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return 'El nombre no puede estar vacío';
    if (value.length > GameConstants.maxPlayerNameLength) {
      return 'Máximo ${GameConstants.maxPlayerNameLength} caracteres';
    }
    return null;
  }

  /// Valida la lista de personajes de una temática personalizada.
  static String? characterList(List<String> chars) {
    if (chars.length < GameConstants.minCharacters) {
      return 'Mínimo ${GameConstants.minCharacters} personajes';
    }
    if (chars.length > GameConstants.maxCharacters) {
      return 'Máximo ${GameConstants.maxCharacters} personajes';
    }
    final dup = findDuplicate(chars);
    if (dup != null) return 'Personaje repetido: "$dup"';
    return null;
  }
}
