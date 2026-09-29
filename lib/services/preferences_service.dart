// lib/services/preferences_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper sobre [SharedPreferences] que centraliza las claves usadas en
/// la app. Inyectable en notifiers para facilitar tests.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  // ---------- Onboarding ----------
  static const String _kOnboardingDone = 'onboarding.done';

  bool get onboardingDone => _prefs.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool value) =>
      _prefs.setBool(_kOnboardingDone, value);

  // ---------- Sesión activa ----------
  static const String _kActiveSession = 'session.active';

  String? get activeSessionJson => _prefs.getString(_kActiveSession);
  Future<void> saveActiveSession(String json) =>
      _prefs.setString(_kActiveSession, json);
  Future<void> clearActiveSession() => _prefs.remove(_kActiveSession);

  // ---------- Sala online activa (para reconectar) ----------
  static const String _kSalaActiva = 'online.sala_activa';

  String? get salaActivaCodigo => _prefs.getString(_kSalaActiva);

  /// Observable para que Home muestre/oculte "Volver a la sala" al regresar.
  late final ValueNotifier<String?> salaActivaNotifier =
      ValueNotifier(salaActivaCodigo);

  Future<void> setSalaActivaCodigo(String codigo) async {
    salaActivaNotifier.value = codigo;
    await _prefs.setString(_kSalaActiva, codigo);
  }

  Future<void> clearSalaActiva() async {
    salaActivaNotifier.value = null;
    await _prefs.remove(_kSalaActiva);
  }

  // ---------- Gameplay ----------
  static const String _kSkipPasaTelefono = 'gameplay.skip_pasa_telefono';

  bool get skipPasaTelefono => _prefs.getBool(_kSkipPasaTelefono) ?? false;
  Future<void> setSkipPasaTelefono(bool value) =>
      _prefs.setBool(_kSkipPasaTelefono, value);

  static const String _kColorfulReveal = 'gameplay.colorful_reveal';
  bool get colorfulReveal => _prefs.getBool(_kColorfulReveal) ?? false;
  Future<void> setColorfulReveal(bool value) =>
      _prefs.setBool(_kColorfulReveal, value);
}
