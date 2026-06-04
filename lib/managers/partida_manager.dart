// lib/managers/partida_manager.dart

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/enums.dart';
import '../core/validators.dart';
import '../models/configuracion_partida.dart';
import '../models/jugador.dart';
import '../models/partida.dart';
import '../models/ronda.dart';

/// Excepción tipada para errores de lógica del juego. Permite a la UI
/// distinguir errores de juego (mostrar SnackBar) de errores genéricos
/// (mostrar diálogo de fallo).
class PartidaException implements Exception {
  PartidaException(this.message);
  final String message;

  @override
  String toString() => 'PartidaException: $message';
}

/// Manager de partida. Extiende [ChangeNotifier] para que la UI consumidora
/// (vía Provider) reaccione automáticamente cuando cambia el estado del
/// juego: nueva partida, jugador eliminado, fin de juego, etc.
class PartidaManager extends ChangeNotifier {
  PartidaManager({Random? random, Uuid? uuid})
      : _random = random ?? Random(),
        _uuid = uuid ?? const Uuid();

  final Random _random;
  final Uuid _uuid;

  Partida? _partidaActual;
  Partida? get partidaActual => _partidaActual;

  /// Garantiza que existe una partida activa. Devuelve la partida o lanza.
  Partida _requirePartida() {
    final p = _partidaActual;
    if (p == null) throw PartidaException('No hay partida activa');
    return p;
  }

  Partida crearPartida({
    required String tematica,
    required String personajeSecreto,
    required List<String> nombresJugadores,
    required ConfiguracionPartida configuracion,
    List<String>? ids,
  }) {
    final error = Validators.playerList(nombresJugadores);
    if (error != null) throw PartidaException(error);
    if (personajeSecreto.trim().isEmpty) {
      throw PartidaException('El personaje secreto no puede estar vacío');
    }

    // Validar y clampear cantidad de impostores. Máximo razonable: que los
    // civiles sigan siendo mayoría al iniciar, es decir, impostores < civiles.
    final n = nombresJugadores.length;
    final maxImpostores = ((n - 1) / 2).floor().clamp(1, n - 1);
    final numImpostores = configuracion.numeroImpostores
        .clamp(GameConstants.minImpostors, maxImpostores);

    // Elegir N índices distintos al azar para los impostores.
    final indices = List<int>.generate(n, (i) => i)..shuffle(_random);
    final impostorIndices = indices.take(numImpostores).toSet();

    if (ids != null && ids.length != n) {
      throw PartidaException('ids debe tener la misma longitud que nombres');
    }

    final jugadores = List.generate(
      n,
      (index) => Jugador(
        id: ids != null ? ids[index] : _uuid.v4(),
        nombre: nombresJugadores[index].trim(),
        numero: index + 1,
        esImpostor: impostorIndices.contains(index),
      ),
    );

    _partidaActual = Partida(
      id: _uuid.v4(),
      tematica: tematica,
      personajeSecreto: personajeSecreto,
      jugadores: jugadores,
      configuracion: configuracion,
    );
    notifyListeners();
    return _partidaActual!;
  }

  Ronda iniciarRonda() {
    final p = _requirePartida();
    final ronda = Ronda(
      numero: p.rondaActual,
      jugadoresVivos: p.jugadoresVivos,
    );
    ronda.jugadorInicial = elegirJugadorInicial(p.jugadoresVivos);
    p.agregarRonda(ronda);
    notifyListeners();
    return ronda;
  }

  /// Elige quién empieza a dar pistas/describir en una ronda.
  ///
  /// El turno avanza en el orden de [vivos] (circular) desde el iniciador.
  /// Queremos que el/los impostor(es) hablen **tarde** (para que no empiecen
  /// "a ciegas" sin haber oído pistas), pero de forma **aleatoria**: a veces
  /// el impostor queda a 1, 2 o 3 turnos del inicio, y de vez en cuando incluso
  /// empieza — así no se nota el patrón "el primero nunca es el impostor".
  ///
  /// Para cada posible iniciador `s` calculamos la posición de habla (1..n) del
  /// impostor más temprano y la usamos como **peso**: los iniciadores que dejan
  /// al impostor más tarde son más probables, pero todos (incluido "impostor
  /// primero", peso 1) tienen probabilidad > 0. Con varios impostores se usa la
  /// posición del que hablaría primero, protegiéndolos a todos.
  Jugador? elegirJugadorInicial(List<Jugador> vivos) {
    final n = vivos.length;
    if (n == 0) return null;

    final impostorIdx = <int>[
      for (int i = 0; i < n; i++)
        if (vivos[i].esImpostor) i,
    ];
    // Sin impostores vivos (estado terminal): iniciador uniforme.
    if (impostorIdx.isEmpty) return vivos[_random.nextInt(n)];

    final pesos = List<int>.generate(n, (s) {
      var earliest = n;
      for (final imp in impostorIdx) {
        final pos = ((imp - s) % n) + 1; // turno: s, s+1, ... (1-indexed)
        if (pos < earliest) earliest = pos;
      }
      return earliest;
    });

    final total = pesos.fold<int>(0, (a, b) => a + b);
    var r = _random.nextInt(total);
    for (int s = 0; s < n; s++) {
      if (r < pesos[s]) return vivos[s];
      r -= pesos[s];
    }
    return vivos[n - 1]; // inalcanzable; salvaguarda
  }

  /// Cuenta los votos. La firma se mantiene compatible con la versión
  /// anterior: el mapa es `votanteId -> votadoId`.
  Map<String, int> procesarVotacion(Map<String, String> votos) {
    _requirePartida();
    final conteo = <String, int>{};
    for (final votado in votos.values) {
      conteo[votado] = (conteo[votado] ?? 0) + 1;
    }
    return conteo;
  }

  bool verificarEmpate(Map<String, int> conteoVotos) {
    if (conteoVotos.isEmpty) return false;
    final maxVotos = conteoVotos.values.reduce(max);
    final empatados = conteoVotos.values.where((v) => v == maxVotos).length;
    return empatados > 1;
  }

  String? obtenerJugadorEliminado(
    Map<String, int> conteoVotos,
    bool eliminarEnEmpate,
  ) {
    if (conteoVotos.isEmpty) return null;
    final maxVotos = conteoVotos.values.reduce(max);
    final candidatos = conteoVotos.entries
        .where((e) => e.value == maxVotos)
        .map((e) => e.key)
        .toList();

    if (candidatos.length > 1 && !eliminarEnEmpate) return null;
    if (candidatos.length > 1) {
      return candidatos[_random.nextInt(candidatos.length)];
    }
    return candidatos.first;
  }

  void eliminarJugador(String jugadorId) {
    final p = _requirePartida();
    final jugador = p.jugadores.firstWhere(
      (j) => j.id == jugadorId,
      orElse: () => throw PartidaException('Jugador no encontrado'),
    );
    if (!jugador.estaVivo) {
      throw PartidaException('El jugador ya está eliminado');
    }
    jugador.eliminar(p.rondaActual);
    if (p.rondas.isEmpty) {
      throw PartidaException(
        'No se puede eliminar sin una ronda activa',
      );
    }
    p.rondas.last.jugadorEliminado = jugador;
    notifyListeners();
  }

  /// Verifica si el juego terminó. Soporta multi-impostor:
  /// - Civiles ganan cuando TODOS los impostores fueron eliminados.
  /// - Impostores ganan cuando alcanzan o superan en número a los civiles
  ///   vivos (porque pueden imponer su voto).
  bool verificarFinDeJuego() {
    final p = _partidaActual;
    if (p == null) return false;
    if (p.finalizada) return true;

    if (!p.tieneImpostor) {
      p.finalizar(TipoGanador.jugadores);
      notifyListeners();
      return true;
    }

    // Sin impostores vivos → civiles ganan.
    if (p.cantidadImpostoresVivos == 0) {
      p.finalizar(TipoGanador.jugadores);
      notifyListeners();
      return true;
    }

    // Impostores >= civiles vivos → impostores ganan.
    if (p.cantidadImpostoresVivos >= p.cantidadCivilesVivos) {
      p.finalizar(TipoGanador.impostor);
      notifyListeners();
      return true;
    }
    return false;
  }

  void siguienteRonda() {
    if (_partidaActual == null) return;
    _partidaActual!.siguienteRonda();
    notifyListeners();
  }

  void finalizarRonda() {
    final p = _partidaActual;
    if (p == null || p.rondas.isEmpty) return;
    p.rondas.last.finalizarRonda();
    notifyListeners();
  }

  void reiniciar() {
    _partidaActual = null;
    notifyListeners();
  }
}
