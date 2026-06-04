import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';

void main() {
  test('crearPartida usa los ids provistos como id de jugador', () {
    final manager = PartidaManager(random: Random(1));
    final partida = manager.crearPartida(
      tematica: 'Animales',
      personajeSecreto: 'León',
      nombresJugadores: ['Ana', 'Beto', 'Caro'],
      ids: ['uidA', 'uidB', 'uidC'],
      configuracion: ConfiguracionPartida(),
    );
    expect(partida.jugadores.map((j) => j.id).toList(),
        ['uidA', 'uidB', 'uidC']);
    expect(partida.jugadores.where((j) => j.esImpostor).length, 1);
  });

  test('crearPartida sin ids sigue generando uuids (modo local intacto)', () {
    final manager = PartidaManager(random: Random(1));
    final partida = manager.crearPartida(
      tematica: 'Animales',
      personajeSecreto: 'León',
      nombresJugadores: ['Ana', 'Beto', 'Caro'],
      configuracion: ConfiguracionPartida(),
    );
    expect(partida.jugadores.every((j) => j.id.isNotEmpty), true);
    expect(partida.jugadores.map((j) => j.id).toSet().length, 3);
  });

  test('crearPartida con ids de longitud incorrecta lanza', () {
    final manager = PartidaManager(random: Random(1));
    expect(
      () => manager.crearPartida(
        tematica: 'Animales',
        personajeSecreto: 'León',
        nombresJugadores: ['Ana', 'Beto', 'Caro'],
        ids: ['uidA', 'uidB'],
        configuracion: ConfiguracionPartida(),
      ),
      throwsA(isA<PartidaException>()),
    );
  });
}
