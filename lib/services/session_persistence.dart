// lib/services/session_persistence.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/sesion_juego.dart';
import 'preferences_service.dart';

/// Conecta una [SesionJuego] con [PreferencesService] para auto-guardar
/// el estado cuando la sesión notifique cambios. Sin esto, si el usuario
/// minimiza la app o suena el teléfono, la partida activa se perdía.
class SessionPersistence {
  SessionPersistence({required this.prefs, required this.sesion}) {
    sesion.addListener(_onChange);
  }

  final PreferencesService prefs;
  final SesionJuego sesion;

  Timer? _debounce;

  /// Guarda con debounce: si la sesión notifica varias veces seguidas
  /// (ej: cambiar tema + jugadores en sucesión), solo escribimos a disco
  /// una vez.
  void _onChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _save);
  }

  Future<void> _save() async {
    try {
      final json = jsonEncode(sesion.toJson());
      await prefs.saveActiveSession(json);
    } catch (e) {
      if (kDebugMode) debugPrint('Error guardando sesión: $e');
    }
  }

  /// Guarda inmediatamente sin esperar al debounce. Útil al iniciar
  /// el lobby para asegurar que existe un snapshot inicial.
  Future<void> saveNow() async {
    _debounce?.cancel();
    await _save();
  }

  void dispose() {
    _debounce?.cancel();
    sesion.removeListener(_onChange);
  }

  /// Restaura una sesión guardada previamente. Devuelve `null` si no hay
  /// sesión persistida o si la deserialización falla.
  static SesionJuego? tryRestore(PreferencesService prefs) {
    final raw = prefs.activeSessionJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return SesionJuego.fromJson(json);
    } catch (e) {
      if (kDebugMode) debugPrint('Error restaurando sesión: $e');
      return null;
    }
  }
}
