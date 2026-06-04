// lib/models/sesion_juego.dart

import 'package:flutter/foundation.dart';

import 'configuracion_partida.dart';
import 'partida.dart';

class ResultadoRondaSesion {
  ResultadoRondaSesion({
    required this.numeroRonda,
    required this.impostorNombre,
    required this.personajeSecreto,
    required this.ganador,
    required this.puntos,
  });

  final int numeroRonda;
  final String impostorNombre;
  final String personajeSecreto;
  final String ganador; // 'impostor' o 'jugadores'
  final Map<String, int> puntos; // jugadorNombre: puntos ganados

  Map<String, dynamic> toJson() => {
        'numeroRonda': numeroRonda,
        'impostorNombre': impostorNombre,
        'personajeSecreto': personajeSecreto,
        'ganador': ganador,
        'puntos': puntos,
      };

  factory ResultadoRondaSesion.fromJson(Map<String, dynamic> json) {
    final puntosRaw = (json['puntos'] as Map?) ?? const {};
    return ResultadoRondaSesion(
      numeroRonda: json['numeroRonda'] as int,
      impostorNombre: json['impostorNombre'] as String,
      personajeSecreto: json['personajeSecreto'] as String,
      ganador: json['ganador'] as String,
      puntos: {
        for (final e in puntosRaw.entries) e.key as String: e.value as int,
      },
    );
  }
}

/// Estado de una sesión de juego (varias rondas con los mismos jugadores).
///
/// Ahora extiende [ChangeNotifier] para que la UI consumidora pueda
/// suscribirse vía Provider y rebuildear automáticamente cuando cambie
/// la temática, los jugadores, o se registre el resultado de una ronda.
/// Antes la `LobbyScreen` necesitaba un `setState(() {})` manual tras
/// volver de una ronda — eso ya no hace falta.
class SesionJuego extends ChangeNotifier {
  SesionJuego({
    required String tematica,
    required List<String> nombresJugadores,
    required ConfiguracionPartida configuracion,
  })  : _tematica = tematica,
        _nombresJugadores = List.of(nombresJugadores),
        _configuracion = configuracion,
        historialRondas = [],
        puntuacion = {};

  String _tematica;
  List<String> _nombresJugadores;
  ConfiguracionPartida _configuracion;

  String get tematica => _tematica;
  set tematica(String value) {
    if (_tematica == value) return;
    _tematica = value;
    notifyListeners();
  }

  List<String> get nombresJugadores => List.unmodifiable(_nombresJugadores);
  set nombresJugadores(List<String> value) {
    final oldNames = List<String>.from(_nombresJugadores);
    final newNames = List<String>.from(value);

    // Mapeo posicional: cada nombre nuevo hereda los puntos del nombre que
    // ocupaba la misma posición antes. Posiciones que ya no existen (lista
    // encogió) se descartan, posiciones nuevas arrancan en 0.
    final puntuacionRenovada = <String, int>{};
    for (int i = 0; i < newNames.length; i++) {
      final newName = newNames[i];
      final puntosPrevios =
          (i < oldNames.length) ? (puntuacion[oldNames[i]] ?? 0) : 0;
      puntuacionRenovada[newName] = puntosPrevios;
    }

    _nombresJugadores = newNames;
    puntuacion
      ..clear()
      ..addAll(puntuacionRenovada);

    // Re-clampear impostores: con menos jugadores el máximo puede bajar.
    final maxImp = ((_nombresJugadores.length - 1) / 2)
        .floor()
        .clamp(1, _nombresJugadores.length - 1);
    if (_configuracion.numeroImpostores > maxImp) {
      _configuracion = _configuracion.copyWith(numeroImpostores: maxImp);
    }
    notifyListeners();
  }

  ConfiguracionPartida get configuracion => _configuracion;
  set configuracion(ConfiguracionPartida value) {
    _configuracion = value;
    notifyListeners();
  }

  final List<ResultadoRondaSesion> historialRondas;
  final Map<String, int> puntuacion;

  void inicializarPuntuacion() {
    for (final nombre in _nombresJugadores) {
      puntuacion.putIfAbsent(nombre, () => 0);
    }
  }

  void registrarResultado({
    required Partida partida,
    required int numeroRonda,
  }) {
    final esVictoriaJugadores = partida.ganador?.name == 'jugadores';
    // Soporte multi-impostor: si hay más de uno, se guardan separados por coma.
    final impostorNombre =
        partida.impostores.map((j) => j.nombre).join(', ');
    final puntosPorRonda = <String, int>{};

    for (final jugador in partida.jugadores) {
      if (jugador.esImpostor) {
        final pts = esVictoriaJugadores ? 0 : 3;
        puntosPorRonda[jugador.nombre] = pts;
        puntuacion[jugador.nombre] = (puntuacion[jugador.nombre] ?? 0) + pts;
      } else {
        var pts = esVictoriaJugadores ? 2 : 0;
        if (jugador.estaVivo && esVictoriaJugadores) pts += 1;
        puntosPorRonda[jugador.nombre] = pts;
        puntuacion[jugador.nombre] = (puntuacion[jugador.nombre] ?? 0) + pts;
      }
    }

    historialRondas.add(ResultadoRondaSesion(
      numeroRonda: historialRondas.length + 1,
      impostorNombre: impostorNombre,
      personajeSecreto: partida.personajeSecreto,
      ganador: esVictoriaJugadores ? 'jugadores' : 'impostor',
      puntos: puntosPorRonda,
    ));

    notifyListeners();
  }

  int get rondasJugadas => historialRondas.length;

  List<MapEntry<String, int>> get rankingOrdenado {
    final entries = puntuacion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Serializa el estado relevante para persistencia. La partida activa
  /// (en `PartidaManager.partidaActual`) NO se serializa: si hay una
  /// ronda en curso al cerrar la app, el usuario reinicia desde el lobby
  /// con los datos de sesión intactos.
  Map<String, dynamic> toJson() => {
        'tematica': _tematica,
        'nombresJugadores': _nombresJugadores,
        'configuracion': _configuracion.toJson(),
        'historialRondas': historialRondas.map((r) => r.toJson()).toList(),
        'puntuacion': puntuacion,
      };

  /// Reconstruye una sesión desde su JSON. Restaura historial y puntuación
  /// para que el lobby muestre exactamente lo que el usuario tenía antes
  /// de cerrar la app.
  factory SesionJuego.fromJson(Map<String, dynamic> json) {
    final nombres = (json['nombresJugadores'] as List).cast<String>();
    final config = ConfiguracionPartida.fromJson(
      (json['configuracion'] as Map).cast<String, dynamic>(),
    );
    final s = SesionJuego(
      tematica: json['tematica'] as String,
      nombresJugadores: nombres,
      configuracion: config,
    );
    final historial =
        (json['historialRondas'] as List?) ?? const <dynamic>[];
    for (final r in historial) {
      s.historialRondas.add(ResultadoRondaSesion.fromJson(
        (r as Map).cast<String, dynamic>(),
      ));
    }
    final puntos = (json['puntuacion'] as Map?) ?? const {};
    s.puntuacion.clear();
    for (final e in puntos.entries) {
      s.puntuacion[e.key as String] = e.value as int;
    }
    return s;
  }
}
