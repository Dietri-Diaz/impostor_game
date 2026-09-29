import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/sala_online_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'fake_sala_gateway.dart';

void main() {
  test('crearSala reserva código, escribe meta y al host como jugador', () async {
    final gw = FakeSalaGateway();
    final mgr = SalaOnlineManager(gateway: gw, uid: 'hostUid', random: Random(1));

    final codigo = await mgr.crearSala(
      nombreHost: 'Ana',
      tematica: 'Animales',
      configuracion: ConfiguracionPartida(),
    );

    expect(codigo.length, 6);
    expect(mgr.esHost, true);
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['hostUid'], 'hostUid');
    expect(meta['estado'], EstadoSala.lobby.name);
    final jug = await gw.leerUna('salas/$codigo/jugadores/hostUid');
    expect(jug!['nombre'], 'Ana');
    expect(jug['numero'], 1);
    expect(jug['conectado'], true);
  });

  test('unirseSala agrega al jugador con número incremental', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'hostUid', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());

    final guest = SalaOnlineManager(gateway: gw, uid: 'guestUid', random: Random(2));
    await guest.unirseSala(codigo: codigo, nombre: 'Beto');

    expect(guest.esHost, false);
    final jug = await gw.leerUna('salas/$codigo/jugadores/guestUid');
    expect(jug!['nombre'], 'Beto');
    expect(jug['numero'], 2);
  });

  test('unirseSala a código inexistente lanza SalaException', () async {
    final gw = FakeSalaGateway();
    final guest = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(2));
    expect(
      () => guest.unirseSala(codigo: 'ZZZZZZ', nombre: 'Beto'),
      throwsA(isA<SalaException>()),
    );
  });

  test('salir como host marca la sala abandonada', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());
    await host.salir();
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.abandonada.name);
  });

  test('observarJugadores emite la lista actual ordenada por numero', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());

    final emisiones = <List<JugadorSala>>[];
    final sub = host.observarJugadores(codigo).listen(emisiones.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final guest = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(2));
    await guest.unirseSala(codigo: codigo, nombre: 'Beto');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(emisiones.last.map((j) => j.nombre), containsAll(['Ana', 'Beto']));
    expect(emisiones.last.map((j) => j.numero).toList(), [1, 2]);
    await sub.cancel();
  });

  test('salir como host cancela los onDisconnect de meta y jugador', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());
    await host.salir();
    expect(gw.onDisconnects.containsKey('salas/$codigo/meta/estado'), false);
    expect(gw.onDisconnects.containsKey('salas/$codigo/meta/hostConectado'), false);
    expect(gw.onDisconnects.containsKey('salas/$codigo/jugadores/h/conectado'), false);
  });

  test('presencia: onDisconnect del host marca estado abandonada', () async {
    final gw = FakeSalaGateway();
    final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
    final codigo = await host.crearSala(
        nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());
    // Simula que el host pierde conexión:
    await gw.dispararDesconexion();
    final meta = await gw.leerUna('salas/$codigo/meta');
    expect(meta!['estado'], EstadoSala.abandonada.name);
    expect(meta['hostConectado'], false);
    final jug = await gw.leerUna('salas/$codigo/jugadores/h');
    expect(jug!['conectado'], false);
  });

  group('reconexión', () {
    Future<(FakeSalaGateway, String)> salaEnJuego() async {
      final gw = FakeSalaGateway();
      final host = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(1));
      final codigo = await host.crearSala(
          nombreHost: 'Ana', tematica: 'Animales', configuracion: ConfiguracionPartida());
      final guest = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(2));
      await guest.unirseSala(codigo: codigo, nombre: 'Beto');
      // La partida empieza y al invitado se le cierra la app.
      await gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.votando.name});
      await gw.actualizar('salas/$codigo/jugadores/g', {'conectado': false});
      return (gw, codigo);
    }

    test('el invitado vuelve a su sala a mitad de partida', () async {
      final (gw, codigo) = await salaEnJuego();
      final vuelta = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(3));
      await vuelta.reconectar(codigo);

      expect(vuelta.codigo, codigo);
      expect(vuelta.esHost, false);
      final jug = await gw.leerUna('salas/$codigo/jugadores/g');
      expect(jug!['conectado'], true);
      expect(jug['numero'], 2, reason: 'conserva su número');
      expect(gw.onDisconnects.containsKey('salas/$codigo/jugadores/g/conectado'), true);
    });

    test('unirse con el mismo código a una partida empezada = reconectar', () async {
      final (gw, codigo) = await salaEnJuego();
      final vuelta = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(3));
      await vuelta.unirseSala(codigo: codigo, nombre: 'Beto');
      final jug = await gw.leerUna('salas/$codigo/jugadores/g');
      expect(jug!['conectado'], true);
    });

    test('un desconocido no puede entrar a una partida empezada', () async {
      final (gw, codigo) = await salaEnJuego();
      final otro = SalaOnlineManager(gateway: gw, uid: 'x', random: Random(3));
      expect(() => otro.unirseSala(codigo: codigo, nombre: 'Caro'),
          throwsA(isA<SalaException>()));
      expect(() => otro.reconectar(codigo), throwsA(isA<SalaException>()));
    });

    test('no reconecta a una sala abandonada por el host', () async {
      final (gw, codigo) = await salaEnJuego();
      await gw.actualizar('salas/$codigo/meta', {'estado': EstadoSala.abandonada.name});
      final vuelta = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(3));
      expect(() => vuelta.reconectar(codigo), throwsA(isA<SalaException>()));
    });

    test('no reconecta a una sala que ya no existe', () async {
      final gw = FakeSalaGateway();
      final vuelta = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(3));
      expect(() => vuelta.reconectar('ZZZZZZ'), throwsA(isA<SalaException>()));
    });

    test('el host no puede retomar su sala (su partida vivía en memoria)', () async {
      final (gw, codigo) = await salaEnJuego();
      final hostDeVuelta = SalaOnlineManager(gateway: gw, uid: 'h', random: Random(3));
      expect(() => hostDeVuelta.reconectar(codigo), throwsA(isA<SalaException>()));
    });

    test('yaVote refleja si el jugador ya emitió su voto', () async {
      final (gw, codigo) = await salaEnJuego();
      final vuelta = SalaOnlineManager(gateway: gw, uid: 'g', random: Random(3));
      await vuelta.reconectar(codigo);
      expect(await vuelta.yaVote(codigo), false);
      await vuelta.votar(codigo, 'h');
      expect(await vuelta.yaVote(codigo), true);
    });
  });
}
