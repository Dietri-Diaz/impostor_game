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
}
