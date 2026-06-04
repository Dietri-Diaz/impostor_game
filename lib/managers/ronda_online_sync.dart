// lib/managers/ronda_online_sync.dart
import '../models/configuracion_partida.dart';
import '../models/partida.dart';
import '../services/sala_gateway.dart';
import 'partida_manager.dart';

/// Sincroniza una ronda entre el motor de juego del host ([PartidaManager])
/// y Realtime Database. Solo el host crea una instancia "activa" que escribe;
/// los clientes leen vía los streams de SalaOnlineManager.
class RondaOnlineSync {
  RondaOnlineSync({
    required SalaGateway gateway,
    required this.codigo,
    required this.uid,
    required PartidaManager manager,
  })  : _gw = gateway,
        _manager = manager;

  final SalaGateway _gw;
  final String codigo;
  final String uid;
  final PartidaManager _manager;

  String get _publico => 'salas/$codigo/publico';

  ConfiguracionPartida _configDesdeMeta(Map<String, dynamic> meta) =>
      ConfiguracionPartida.fromJson(
          (meta['configJson'] as Map?)?.cast<String, dynamic>() ?? const {});

  Map<String, Object?> _publicoDesdePartida(Partida p) => {
        'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
        'conteoVotos': <String, int>{},
        'ganador': null,
        'resultadoRonda': null,
      };

  /// HOST: lee el roster del lobby, crea la Partida con ids=uid, asigna roles,
  /// publica /privado/{uid} de cada jugador y pasa a 'revelando'.
  Future<void> iniciarPartida({required String personajeSecreto}) async {
    final jugRaw = await _gw.leerUna('salas/$codigo/jugadores') ?? {};
    final metaRaw = await _gw.leerUna('salas/$codigo/meta') ?? {};

    final entries = jugRaw.entries.toList()
      ..sort((a, b) => ((a.value as Map)['numero'] as int)
          .compareTo((b.value as Map)['numero'] as int));
    final uids = [for (final e in entries) e.key];
    final nombres = [for (final e in entries) (e.value as Map)['nombre'] as String];

    final partida = _manager.crearPartida(
      tematica: metaRaw['tematica'] as String? ?? '',
      personajeSecreto: personajeSecreto,
      nombresJugadores: nombres,
      ids: uids,
      configuracion: _configDesdeMeta(metaRaw),
    );
    final ronda = _manager.iniciarRonda();

    for (final j in partida.jugadores) {
      await _gw.escribir('salas/$codigo/privado/${j.id}', {
        'esImpostor': j.esImpostor,
        'personajeVisto': j.esImpostor ? null : personajeSecreto,
      });
    }

    await _gw.escribir(_publico, _publicoDesdePartida(partida));
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': EstadoSala.revelando.name,
      'jugadorInicialUid': ronda.jugadorInicial?.id,
    });
  }

  /// HOST: revelando → discusion.
  Future<void> irADiscusion() =>
      _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.discusion.name});

  /// HOST: discusion → votando (limpia votos previos).
  Future<void> abrirVotacion() async {
    await _gw.escribir('salas/$codigo/votos', null);
    await _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.votando.name});
  }

  /// HOST: lee los votos, cuenta, elimina, verifica fin y publica resultado.
  /// SIEMPRE deja la sala en 'resultado' (se muestra a quién eliminaron y, si
  /// el juego terminó, el ganador queda en publico.ganador). La transición a
  /// 'finalizada' la hace el host con [irAFinal].
  Future<void> contarVotosYResolver() async {
    final votosRaw = await _gw.leerUna('salas/$codigo/votos') ?? {};
    final votos = <String, String>{
      for (final e in votosRaw.entries)
        e.key: (e.value as Map)['objetivoUid'] as String,
    };

    final conteo = _manager.procesarVotacion(votos);
    final config = _manager.partidaActual!.configuracion;
    final eliminadoId =
        _manager.obtenerJugadorEliminado(conteo, config.eliminarEnEmpate);

    bool eraImpostor = false;
    if (eliminadoId != null) {
      final jug = _manager.partidaActual!.jugadores
          .firstWhere((j) => j.id == eliminadoId);
      eraImpostor = jug.esImpostor;
      _manager.eliminarJugador(eliminadoId);
      await _gw.actualizar(
          'salas/$codigo/jugadores/$eliminadoId', {'eliminado': true});
    }
    _manager.finalizarRonda();
    final fin = _manager.verificarFinDeJuego();
    final p = _manager.partidaActual!;

    await _gw.actualizar(_publico, {
      'conteoVotos': conteo,
      'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
      'resultadoRonda': {'eliminadoUid': eliminadoId, 'eraImpostor': eraImpostor},
      'ganador': fin ? p.ganador?.name : null,
      'reveal': fin
          ? {
              'personaje': p.personajeSecreto,
              'impostores': [for (final j in p.impostores) j.id],
            }
          : null,
    });
    await _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.resultado.name});
  }

  /// HOST: publica cuántos votos se han emitido (para mostrar progreso a todos).
  Future<void> publicarProgresoVotos(int emitidos) =>
      _gw.actualizar('salas/$codigo/publico', {'votosEmitidos': emitidos});

  /// HOST: avanza a la siguiente ronda de votación dentro de la MISMA partida
  /// (mismo impostor; roles ya revelados). Va a 'discusion'.
  Future<void> siguienteRonda() async {
    _manager.siguienteRonda();
    final ronda = _manager.iniciarRonda();
    final p = _manager.partidaActual!;
    await _gw.escribir('salas/$codigo/votos', null);
    await _gw.actualizar(_publico, {
      'jugadoresVivos': [for (final j in p.jugadoresVivos) j.id],
      'conteoVotos': <String, int>{},
      'resultadoRonda': null,
    });
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': EstadoSala.discusion.name,
      'rondaActual': p.rondaActual,
      'jugadorInicialUid': ronda.jugadorInicial?.id,
    });
  }

  /// HOST: resultado (con ganador) → finalizada.
  Future<void> irAFinal() =>
      _gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.finalizada.name});

  /// HOST: reinicia para una nueva partida (mismo grupo, nuevo impostor).
  Future<void> volverAlLobby() async {
    _manager.reiniciar();
    await _gw.escribir('salas/$codigo/privado', null);
    await _gw.escribir('salas/$codigo/votos', null);
    await _gw.escribir('salas/$codigo/publico', null);
    final jug = await _gw.leerUna('salas/$codigo/jugadores') ?? {};
    for (final uid in jug.keys) {
      await _gw.actualizar(
          'salas/$codigo/jugadores/$uid', {'listo': false, 'eliminado': false});
    }
    await _gw.actualizar('salas/$codigo/meta', {
      'estado': EstadoSala.lobby.name,
      'rondaActual': 1,
      'jugadorInicialUid': null,
    });
  }
}
