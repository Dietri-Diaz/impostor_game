// test/jugador_inicial_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/jugador.dart';

/// Construye [n] jugadores vivos en orden de número, con el impostor en
/// el índice [impostorIdx].
List<Jugador> _jugadores(int n, {required int impostorIdx}) => [
      for (int i = 0; i < n; i++)
        Jugador(
          id: 'j$i',
          nombre: 'J${i + 1}',
          numero: i + 1,
          esImpostor: i == impostorIdx,
        ),
    ];

/// Posición (1..n) en la que habla el impostor si el turno empieza en [starter]
/// y avanza en orden circular.
int _posImpostor(int n, int impostorIdx, int starterIdx) =>
    ((impostorIdx - starterIdx) % n) + 1;

void main() {
  group('elegirJugadorInicial', () {
    test('siempre devuelve un jugador vivo de la lista', () {
      final manager = PartidaManager(random: Random(1));
      final vivos = _jugadores(5, impostorIdx: 2);
      for (var i = 0; i < 100; i++) {
        final elegido = manager.elegirJugadorInicial(vivos);
        expect(vivos, contains(elegido));
      }
    });

    test('sesga a que el impostor hable tarde, pero a veces empieza', () {
      const n = 6;
      const impostorIdx = 2;
      final manager = PartidaManager(random: Random(7));
      final vivos = _jugadores(n, impostorIdx: impostorIdx);

      var impostorPrimero = 0;
      var impostorUltimo = 0;
      final startersDistintos = <int>{};

      const trials = 3000;
      for (var t = 0; t < trials; t++) {
        final elegido = manager.elegirJugadorInicial(vivos)!;
        final s = vivos.indexOf(elegido);
        startersDistintos.add(s);
        final pos = _posImpostor(n, impostorIdx, s);
        if (pos == 1) impostorPrimero++;
        if (pos == n) impostorUltimo++;
      }

      // El impostor habla al final mucho más seguido que de primero (sesgo).
      expect(impostorUltimo, greaterThan(impostorPrimero));
      // Pero "impostor primero" SÍ ocurre de vez en cuando (no es imposible).
      expect(impostorPrimero, greaterThan(0));
      // Y varía: no siempre empieza el mismo jugador.
      expect(startersDistintos.length, greaterThan(1));
    });

    test('sin impostores vivos no lanza y devuelve un jugador', () {
      final manager = PartidaManager(random: Random(3));
      final vivos = [
        Jugador(id: 'a', nombre: 'A', numero: 1, esImpostor: false),
        Jugador(id: 'b', nombre: 'B', numero: 2, esImpostor: false),
      ];
      final elegido = manager.elegirJugadorInicial(vivos);
      expect(vivos, contains(elegido));
    });

    test('lista vacía devuelve null', () {
      final manager = PartidaManager(random: Random(3));
      expect(manager.elegirJugadorInicial([]), isNull);
    });
  });
}
