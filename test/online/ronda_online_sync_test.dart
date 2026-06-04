import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/managers/ronda_online_sync.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'fake_sala_gateway.dart';

Future<void> _seedLobby(FakeSalaGateway gw, String codigo,
    {int n = 3}) async {
  await gw.escribir('salas/$codigo/meta', {
    'hostUid': 'h', 'estado': EstadoSala.lobby.name, 'rondaActual': 1,
    'tematica': 'Animales', 'configJson': ConfiguracionPartida().toJson(),
  });
  final jugadores = <String, Object?>{};
  for (var i = 0; i < n; i++) {
    final uid = i == 0 ? 'h' : 'g$i';
    jugadores[uid] = {
      'nombre': 'P$i', 'numero': i + 1,
      'conectado': true, 'listo': true, 'eliminado': false,
    };
  }
  await gw.escribir('salas/$codigo/jugadores', jugadores);
}

Future<String> _hallarImpostor(FakeSalaGateway gw, String codigo, List<String> uids) async {
  for (final u in uids) {
    final m = await gw.leerUna('salas/$codigo/privado/$u');
    if (m != null && (m['esImpostor'] as bool)) return u;
  }
  throw StateError('sin impostor');
}

void main() {
  test('iniciarPartida asigna 1 impostor, escribe /privado y pasa a revelando', () async {
    final gw = FakeSalaGateway();
    const codigo = 'ABC234';
    await _seedLobby(gw, codigo);
    final host = RondaOnlineSync(
      gateway: gw, codigo: codigo, uid: 'h', manager: PartidaManager(random: Random(1)));

    await host.iniciarPartida(personajeSecreto: 'León');

    final privados = <RolPrivado>[];
    for (final u in ['h', 'g1', 'g2']) {
      privados.add(RolPrivado.fromMap((await gw.leerUna('salas/$codigo/privado/$u'))!));
    }
    expect(privados.where((r) => r.esImpostor).length, 1);
    for (final r in privados) {
      expect(r.personajeVisto, r.esImpostor ? null : 'León');
    }
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.revelando.name);
    expect(meta['jugadorInicialUid'], isNotNull);

    await host.irADiscusion();
    expect((await gw.leerUna('salas/$codigo/meta'))!['estado'], EstadoSala.discusion.name);
  });

  test('todos votan al impostor: lo elimina, resultado + ganador jugadores, luego final', () async {
    final gw = FakeSalaGateway();
    const codigo = 'ABC235';
    await _seedLobby(gw, codigo);
    final host = RondaOnlineSync(
      gateway: gw, codigo: codigo, uid: 'h', manager: PartidaManager(random: Random(1)));
    await host.iniciarPartida(personajeSecreto: 'León');
    await host.irADiscusion();
    await host.abrirVotacion();

    final impostor = await _hallarImpostor(gw, codigo, ['h', 'g1', 'g2']);
    for (final v in ['h', 'g1', 'g2']) {
      await gw.escribir('salas/$codigo/votos/$v', {'objetivoUid': impostor});
    }
    await host.contarVotosYResolver();

    expect((await gw.leerUna('salas/$codigo/meta'))!['estado'], EstadoSala.resultado.name);
    final pub = await gw.leerUna('salas/$codigo/publico');
    final res = pub!['resultadoRonda'] as Map;
    expect(res['eliminadoUid'], impostor);
    expect(res['eraImpostor'], true);
    expect(pub['ganador'], 'jugadores');

    await host.irAFinal();
    expect((await gw.leerUna('salas/$codigo/meta'))!['estado'], EstadoSala.finalizada.name);
  });

  test('eliminan a un civil: no termina, siguienteRonda va a discusion y limpia votos', () async {
    final gw = FakeSalaGateway();
    const codigo = 'ABC236';
    await _seedLobby(gw, codigo, n: 5);
    final uids = ['h', 'g1', 'g2', 'g3', 'g4'];
    final host = RondaOnlineSync(
      gateway: gw, codigo: codigo, uid: 'h', manager: PartidaManager(random: Random(3)));
    await host.iniciarPartida(personajeSecreto: 'León');
    await host.irADiscusion();
    await host.abrirVotacion();

    final impostor = await _hallarImpostor(gw, codigo, uids);
    final civil = uids.firstWhere((u) => u != impostor);
    for (final v in uids) {
      await gw.escribir('salas/$codigo/votos/$v', {'objetivoUid': civil});
    }
    await host.contarVotosYResolver();

    final pub = await gw.leerUna('salas/$codigo/publico');
    expect((pub!['resultadoRonda'] as Map)['eliminadoUid'], civil);
    expect((pub['resultadoRonda'] as Map)['eraImpostor'], false);
    expect(pub['ganador'], isNull); // sigue el juego
    expect((await gw.leerUna('salas/$codigo/meta'))!['estado'], EstadoSala.resultado.name);

    await host.siguienteRonda();
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.discusion.name);
    expect(meta['rondaActual'], 2);
    expect(meta['jugadorInicialUid'], isNotNull);
    expect(await gw.leerUna('salas/$codigo/votos'), isNull); // votos limpiados
    // el civil eliminado ya no está en jugadoresVivos del publico:
    final vivos = (await gw.leerUna('salas/$codigo/publico'))!['jugadoresVivos'] as List;
    expect(vivos.contains(civil), false);
  });
}
