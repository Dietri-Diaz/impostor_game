// test/partida_manager_test.dart

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/core/enums.dart';
import 'package:impostor_game/managers/partida_manager.dart';
import 'package:impostor_game/models/configuracion_partida.dart';

ConfiguracionPartida _config({bool eliminarEnEmpate = false}) =>
    ConfiguracionPartida(eliminarEnEmpate: eliminarEnEmpate);

PartidaManager _newManager({int seed = 0}) =>
    PartidaManager(random: Random(seed));

void main() {
  group('crearPartida', () {
    test('asigna exactamente un impostor', () {
      final m = _newManager();
      final partida = m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: ['Ana', 'Bob', 'Carlos', 'Diana'],
        configuracion: _config(),
      );
      final impostores = partida.jugadores.where((j) => j.esImpostor).length;
      expect(impostores, 1);
    });

    test('lanza si hay nombres duplicados', () {
      final m = _newManager();
      expect(
        () => m.crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: ['Ana', 'Ana', 'Bob'],
          configuracion: _config(),
        ),
        throwsA(isA<PartidaException>()),
      );
    });

    test('lanza si hay menos del mínimo de jugadores', () {
      final m = _newManager();
      expect(
        () => m.crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: ['Ana', 'Bob'],
          configuracion: _config(),
        ),
        throwsA(isA<PartidaException>()),
      );
    });

    test('lanza si el personaje secreto está vacío', () {
      final m = _newManager();
      expect(
        () => m.crearPartida(
          tematica: 'Marvel',
          personajeSecreto: '   ',
          nombresJugadores: ['Ana', 'Bob', 'Carlos'],
          configuracion: _config(),
        ),
        throwsA(isA<PartidaException>()),
      );
    });
  });

  group('procesarVotacion', () {
    test('cuenta correctamente', () {
      final m = _newManager()
        ..crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: ['Ana', 'Bob', 'Carlos'],
          configuracion: _config(),
        );
      final conteo = m.procesarVotacion({'v1': 'a', 'v2': 'a', 'v3': 'b'});
      expect(conteo['a'], 2);
      expect(conteo['b'], 1);
    });
  });

  group('verificarEmpate', () {
    test('devuelve true cuando hay empate', () {
      final m = _newManager()
        ..crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: ['Ana', 'Bob', 'Carlos'],
          configuracion: _config(),
        );
      expect(m.verificarEmpate({'a': 2, 'b': 2}), isTrue);
    });

    test('devuelve false con ganador claro', () {
      final m = _newManager()
        ..crearPartida(
          tematica: 'Marvel',
          personajeSecreto: 'Spider-Man',
          nombresJugadores: ['Ana', 'Bob', 'Carlos'],
          configuracion: _config(),
        );
      expect(m.verificarEmpate({'a': 3, 'b': 1}), isFalse);
    });

    test('mapa vacío no es empate', () {
      final m = _newManager();
      expect(m.verificarEmpate({}), isFalse);
    });
  });

  group('obtenerJugadorEliminado', () {
    test('null si empate y no se elimina en empate', () {
      final m = _newManager();
      final r = m.obtenerJugadorEliminado({'a': 2, 'b': 2}, false);
      expect(r, isNull);
    });

    test('elimina aleatorio si empate y eliminarEnEmpate=true', () {
      final m = _newManager(seed: 42);
      final r = m.obtenerJugadorEliminado({'a': 2, 'b': 2}, true);
      expect(r, isIn(['a', 'b']));
    });

    test('elige al de más votos', () {
      final m = _newManager();
      expect(
        m.obtenerJugadorEliminado({'a': 3, 'b': 1}, false),
        'a',
      );
    });
  });

  group('verificarFinDeJuego', () {
    test('false sin partida', () {
      expect(_newManager().verificarFinDeJuego(), isFalse);
    });

    test('jugadores ganan si eliminan al impostor', () {
      final m = _newManager();
      final partida = m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: ['Ana', 'Bob', 'Carlos', 'Diana'],
        configuracion: _config(),
      );
      m.iniciarRonda();
      final impostor = partida.jugadores.firstWhere((j) => j.esImpostor);
      m.eliminarJugador(impostor.id);
      expect(m.verificarFinDeJuego(), isTrue);
      expect(partida.ganador, TipoGanador.jugadores);
    });

    test('impostor gana si quedan <= 2 jugadores vivos', () {
      final m = _newManager();
      final partida = m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: ['Ana', 'Bob', 'Carlos', 'Diana'],
        configuracion: _config(),
      );
      final noImpostores =
          partida.jugadores.where((j) => !j.esImpostor).toList();
      m.iniciarRonda();
      m.eliminarJugador(noImpostores[0].id);
      m.iniciarRonda();
      m.eliminarJugador(noImpostores[1].id);
      expect(m.verificarFinDeJuego(), isTrue);
      expect(partida.ganador, TipoGanador.impostor);
    });
  });

  group('eliminarJugador', () {
    test('lanza si jugador no existe', () {
      final m = _newManager();
      m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: ['Ana', 'Bob', 'Carlos'],
        configuracion: _config(),
      );
      m.iniciarRonda();
      expect(
        () => m.eliminarJugador('id-inexistente'),
        throwsA(isA<PartidaException>()),
      );
    });

    test('lanza si no hay ronda activa', () {
      final m = _newManager();
      final partida = m.crearPartida(
        tematica: 'Marvel',
        personajeSecreto: 'Spider-Man',
        nombresJugadores: ['Ana', 'Bob', 'Carlos'],
        configuracion: _config(),
      );
      expect(
        () => m.eliminarJugador(partida.jugadores.first.id),
        throwsA(isA<PartidaException>()),
      );
    });
  });
}
