// lib/managers/sala_online_manager.dart
import 'dart:math';
import '../core/constants.dart';
import '../models/configuracion_partida.dart';
import '../services/sala_gateway.dart';
import 'sala_codigo.dart';

class SalaException implements Exception {
  SalaException(this.message);
  final String message;
  @override
  String toString() => 'SalaException: $message';
}

/// Maneja el ciclo de vida de una sala online desde la perspectiva de UN
/// cliente (sea host o invitado). No corre la lógica de juego (eso es
/// RondaOnlineSync); solo crea/une/sale y mantiene presencia.
class SalaOnlineManager {
  SalaOnlineManager({
    required SalaGateway gateway,
    required this.uid,
    Random? random,
  })  : _gw = gateway,
        _random = random ?? Random();

  final SalaGateway _gw;
  final String uid;
  final Random _random;

  String? _codigo;
  String? get codigo => _codigo;

  String? _hostUid;
  bool get esHost => _codigo != null && _hostUid == uid;

  /// Crea una sala con código único y deja al host como jugador #1.
  Future<String> crearSala({
    required String nombreHost,
    required String tematica,
    required ConfiguracionPartida configuracion,
  }) async {
    String? codigo;
    for (var intento = 0; intento < 6; intento++) {
      final candidato = generarCodigoSala(_random);
      final reservado =
          await _gw.reservarSiAusente('codigos/$candidato', {'host': uid});
      if (reservado) {
        codigo = candidato;
        break;
      }
    }
    if (codigo == null) {
      throw SalaException('No se pudo generar un código único, reintenta');
    }

    await _gw.escribir('salas/$codigo/meta', {
      'hostUid': uid,
      'estado': EstadoSala.lobby.name,
      'rondaActual': 1,
      'tematica': tematica,
      'configJson': configuracion.toJson(),
      'jugadorInicialUid': null,
      'hostConectado': true,
      'createdAt': 0,
    });
    await _gw.escribir(
        'salas/$codigo/jugadores/$uid', _jugadorMap(nombre: nombreHost, numero: 1));

    _codigo = codigo;
    _hostUid = uid;
    await _configurarPresencia();
    return codigo;
  }

  Future<void> unirseSala({
    required String codigo,
    required String nombre,
  }) async {
    final meta = await _gw.leerUna('salas/$codigo/meta');
    if (meta == null) {
      throw SalaException('La sala "$codigo" no existe');
    }
    final jugadores = await _gw.leerUna('salas/$codigo/jugadores') ?? {};
    // Si ya estaba en la sala (p. ej. se le cerró la app), vuelve a entrar
    // aunque la partida ya haya empezado.
    if (jugadores.containsKey(uid) && meta['hostUid'] != uid) {
      await reconectar(codigo);
      return;
    }
    if (estadoSalaFromName(meta['estado'] as String?) != EstadoSala.lobby) {
      throw SalaException('La partida ya empezó');
    }
    if (jugadores.length >= GameConstants.maxPlayers &&
        !jugadores.containsKey(uid)) {
      throw SalaException('La sala está llena (máx. ${GameConstants.maxPlayers})');
    }
    // NOTE: `jugadores.length + 1` se lee de un snapshot y se escribe sin
    // transacción; dos invitados uniéndose a la vez podrían recibir el mismo
    // número. Aceptable en V1 (host-authoritative sin transacción aquí).
    final numero = jugadores.containsKey(uid)
        ? (jugadores[uid] as Map)['numero'] as int
        : jugadores.length + 1;

    await _gw.escribir(
        'salas/$codigo/jugadores/$uid', _jugadorMap(nombre: nombre, numero: numero));

    _codigo = codigo;
    _hostUid = meta['hostUid'] as String?;
    await _configurarPresencia();
  }

  /// Vuelve a entrar a una sala de la que el jugador ya formaba parte (se le
  /// cerró la app o perdió la conexión). Solo sirve para invitados: el estado
  /// de la partida del host vive en su memoria, así que si el host se va la
  /// sala termina (su onDisconnect la marca 'abandonada').
  Future<void> reconectar(String codigo) async {
    final meta = await _gw.leerUna('salas/$codigo/meta');
    if (meta == null) {
      throw SalaException('La sala "$codigo" ya no existe');
    }
    final estado = estadoSalaFromName(meta['estado'] as String?);
    final hostUid = meta['hostUid'] as String?;
    if (estado == EstadoSala.abandonada || hostUid == uid) {
      throw SalaException('La sala "$codigo" ya se cerró');
    }
    final yo = await _gw.leerUna('salas/$codigo/jugadores/$uid');
    if (yo == null) {
      throw SalaException('Ya no formas parte de la sala "$codigo"');
    }
    await _gw.actualizar('salas/$codigo/jugadores/$uid', {'conectado': true});

    _codigo = codigo;
    _hostUid = hostUid;
    await _configurarPresencia();
  }

  Map<String, Object?> _jugadorMap({required String nombre, required int numero}) =>
      JugadorSala(
        uid: uid,
        nombre: nombre,
        numero: numero,
        conectado: true,
        listo: false,
        eliminado: false,
      ).toMap();

  Future<void> _configurarPresencia() async {
    final c = _codigo!;
    await _gw.alDesconectar('salas/$c/jugadores/$uid/conectado', false);
    if (esHost) {
      await _gw.alDesconectar('salas/$c/meta/estado', EstadoSala.abandonada.name);
      await _gw.alDesconectar('salas/$c/meta/hostConectado', false);
    }
  }

  Future<void> marcarListo(bool listo) async {
    final c = _codigo;
    if (c == null) return;
    await _gw.actualizar('salas/$c/jugadores/$uid', {'listo': listo});
  }

  Future<void> cambiarNombre(String nombre) async {
    final c = _codigo;
    if (c == null) return;
    await _gw.actualizar('salas/$c/jugadores/$uid', {'nombre': nombre});
  }

  /// Sale de la sala. Si es host, marca la sala abandonada.
  Future<void> salir() async {
    final c = _codigo;
    if (c == null) return;
    await _gw.cancelarAlDesconectar('salas/$c/jugadores/$uid/conectado');
    if (esHost) {
      await _gw.cancelarAlDesconectar('salas/$c/meta/estado');
      await _gw.cancelarAlDesconectar('salas/$c/meta/hostConectado');
      await _gw.actualizar('salas/$c/meta', {
        'estado': EstadoSala.abandonada.name,
        'hostConectado': false,
      });
    } else {
      await _gw.actualizar('salas/$c/jugadores/$uid', {'conectado': false});
    }
    _codigo = null;
    _hostUid = null;
  }

  // ---- Observadores (Task 5.2) ----

  Stream<List<JugadorSala>> observarJugadores(String codigo) =>
      _gw.observar('salas/$codigo/jugadores').map((m) {
        if (m == null) return <JugadorSala>[];
        final lista = [
          for (final e in m.entries)
            JugadorSala.fromMap(e.key, (e.value as Map).cast<String, dynamic>()),
        ]..sort((a, b) => a.numero.compareTo(b.numero));
        return lista;
      });

  Stream<Map<String, dynamic>?> observarMeta(String codigo) =>
      _gw.observar('salas/$codigo/meta');

  Stream<Map<String, dynamic>?> observarPublico(String codigo) =>
      _gw.observar('salas/$codigo/publico');

  /// Stream del rol privado del jugador local (solo este uid puede leerlo).
  Stream<RolPrivado?> observarMiRol(String codigo) =>
      _gw.observar('salas/$codigo/privado/$uid')
          .map((m) => m == null ? null : RolPrivado.fromMap(m));

  /// Emite el voto del jugador local (solo válido en estado 'votando').
  Future<void> votar(String codigo, String objetivoUid) =>
      _gw.escribir('salas/$codigo/votos/$uid', {'objetivoUid': objetivoUid});

  /// True si el jugador local ya votó en la votación en curso (sirve al
  /// reconectar a mitad de votación: no se le vuelve a pedir el voto).
  Future<bool> yaVote(String codigo) async =>
      await _gw.leerUna('salas/$codigo/votos/$uid') != null;

  /// Stream de los votos emitidos (solo el host puede leer este nodo).
  Stream<Map<String, dynamic>?> observarVotos(String codigo) =>
      _gw.observar('salas/$codigo/votos');
}
