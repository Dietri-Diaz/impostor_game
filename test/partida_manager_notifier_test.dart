// test/partida_manager_notifier_test.dart
//
// Verifica que PartidaManager (ChangeNotifier) emite notificaciones en
// los puntos correctos. Importante porque la UI con Provider depende de
// estas señales para rebuildearse.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';

PartidaManager _new() => PartidaManager(random: Random(0));

void main() {
  group('PartidaManager ChangeNotifier', () {
    test('crearPartida notifica', () {
      final m = _new();
      var calls = 0;
      m.addListener(() => calls++);
      m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: const ['Ana', 'Bob', 'Carlos'],
        configuracion: ConfiguracionPartida(),
      );
      expect(calls, 1);
    });

    test('iniciarRonda notifica', () {
      final m = _new()
        ..crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: const ['Ana', 'Bob', 'Carlos'],
          configuracion: ConfiguracionPartida(),
        );
      var calls = 0;
      m.addListener(() => calls++);
      m.iniciarRonda();
      expect(calls, 1);
    });

    test('eliminarJugador notifica', () {
      final m = _new();
      final partida = m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: const ['Ana', 'Bob', 'Carlos', 'Diana'],
        configuracion: ConfiguracionPartida(),
      );
      m.iniciarRonda();
      var calls = 0;
      m.addListener(() => calls++);
      // Elegimos un no-impostor para no terminar el juego
      final target = partida.jugadores.firstWhere((j) => !j.esImpostor);
      m.eliminarJugador(target.id);
      expect(calls, greaterThanOrEqualTo(1));
    });

    test('reiniciar limpia partida y notifica', () {
      final m = _new()
        ..crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: const ['Ana', 'Bob', 'Carlos'],
          configuracion: ConfiguracionPartida(),
        );
      var calls = 0;
      m.addListener(() => calls++);
      m.reiniciar();
      expect(calls, 1);
      expect(m.partidaActual, isNull);
    });
  });
}
