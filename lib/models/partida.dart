// lib/models/partida.dart

import 'jugador.dart';
import 'ronda.dart';
import 'configuracion_partida.dart';
import '../core/enums.dart';

class Partida {
  final String id;
  final String tematica;
  final String personajeSecreto;
  final List<Jugador> jugadores;
  final ConfiguracionPartida configuracion;
  final List<Ronda> rondas;
  int rondaActual;
  bool finalizada;
  TipoGanador? ganador;

  Partida({
    required this.id,
    required this.tematica,
    required this.personajeSecreto,
    required this.jugadores,
    required this.configuracion,
    List<Ronda>? rondas,
    this.rondaActual = 1,
    this.finalizada = false,
    this.ganador,
  }) : rondas = rondas ?? [];

  int get numeroJugadores => jugadores.length;

  List<Jugador> get jugadoresVivos =>
      jugadores.where((j) => j.estaVivo).toList();

  int get cantidadJugadoresVivos => jugadoresVivos.length;

  bool get tieneImpostor => jugadores.any((j) => j.esImpostor);

  /// Todos los impostores (puede haber más de uno).
  List<Jugador> get impostores =>
      jugadores.where((j) => j.esImpostor).toList();

  /// Impostores aún vivos. Útil para condiciones de fin de juego.
  List<Jugador> get impostoresVivos =>
      jugadores.where((j) => j.esImpostor && j.estaVivo).toList();

  int get cantidadImpostoresVivos => impostoresVivos.length;

  /// Civiles aún vivos (no impostores).
  int get cantidadCivilesVivos =>
      jugadores.where((j) => !j.esImpostor && j.estaVivo).length;

  /// Devuelve el primer impostor o `null` si no hay (estado inválido).
  Jugador? get impostorOrNull {
    for (final j in jugadores) {
      if (j.esImpostor) return j;
    }
    return null;
  }

  /// Primer impostor. Útil para displays que solo necesitan un nombre.
  /// Para casos multi-impostor usa `impostores`.
  Jugador get impostor {
    final i = impostorOrNull;
    if (i == null) {
      throw StateError('La partida no tiene impostor asignado');
    }
    return i;
  }

  bool get impostorEstaVivo => impostoresVivos.isNotEmpty;

  void agregarRonda(Ronda ronda) {
    rondas.add(ronda);
  }

  void siguienteRonda() {
    rondaActual++;
  }

  void finalizar(TipoGanador tipoGanador) {
    finalizada = true;
    ganador = tipoGanador;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tematica': tematica,
      'personajeSecreto': personajeSecreto,
      'jugadores': jugadores.map((j) => j.toJson()).toList(),
      'configuracion': configuracion.toJson(),
      'rondas': rondas.map((r) => r.toJson()).toList(),
      'rondaActual': rondaActual,
      'finalizada': finalizada,
      'ganador': ganador?.name,
    };
  }

  factory Partida.fromJson(Map<String, dynamic> json) {
    final ganadorRaw = json['ganador'] as String?;
    return Partida(
      id: json['id'] as String,
      tematica: json['tematica'] as String,
      personajeSecreto: json['personajeSecreto'] as String,
      jugadores: [
        for (final j in (json['jugadores'] as List? ?? const []))
          Jugador.fromJson((j as Map).cast<String, dynamic>()),
      ],
      configuracion: ConfiguracionPartida.fromJson(
        (json['configuracion'] as Map).cast<String, dynamic>(),
      ),
      rondas: [
        for (final r in (json['rondas'] as List? ?? const []))
          Ronda.fromJson((r as Map).cast<String, dynamic>()),
      ],
      rondaActual: (json['rondaActual'] as int?) ?? 1,
      finalizada: (json['finalizada'] as bool?) ?? false,
      ganador: ganadorRaw == null
          ? null
          : TipoGanador.values.firstWhere((g) => g.name == ganadorRaw),
    );
  }
}