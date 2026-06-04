// test/partida_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/core/enums.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/models/jugador.dart';
import 'package:impostor_game/models/partida.dart';

Partida _newPartida({bool conImpostor = true}) {
  final jugadores = [
    Jugador(id: 'a', nombre: 'Ana', numero: 1, esImpostor: false),
    Jugador(id: 'b', nombre: 'Bob', numero: 2, esImpostor: false),
    Jugador(
      id: 'c',
      nombre: 'Carlos',
      numero: 3,
      esImpostor: conImpostor,
    ),
    Jugador(id: 'd', nombre: 'Diana', numero: 4, esImpostor: false),
  ];
  return Partida(
    id: 'p1',
    tematica: 'Marvel',
    personajeSecreto: 'Spider-Man',
    jugadores: jugadores,
    configuracion: ConfiguracionPartida(),
  );
}

void main() {
  group('Partida helpers', () {
    test('jugadoresVivos excluye eliminados', () {
      final p = _newPartida();
      p.jugadores[0].eliminar(1);
      expect(p.cantidadJugadoresVivos, 3);
      expect(p.jugadoresVivos.any((j) => j.id == 'a'), isFalse);
    });

    test('impostorOrNull devuelve el impostor cuando existe', () {
      final p = _newPartida();
      expect(p.impostorOrNull?.id, 'c');
      expect(p.tieneImpostor, isTrue);
    });

    test('impostorOrNull devuelve null si no hay impostor', () {
      final p = _newPartida(conImpostor: false);
      expect(p.impostorOrNull, isNull);
      expect(p.tieneImpostor, isFalse);
      expect(p.impostorEstaVivo, isFalse);
    });

    test('impostor lanza StateError si no existe', () {
      final p = _newPartida(conImpostor: false);
      expect(() => p.impostor, throwsStateError);
    });

    test('finalizar setea ganador y flag', () {
      final p = _newPartida()..finalizar(TipoGanador.jugadores);
      expect(p.finalizada, isTrue);
      expect(p.ganador, TipoGanador.jugadores);
    });

    test('siguienteRonda incrementa rondaActual', () {
      final p = _newPartida();
      expect(p.rondaActual, 1);
      p.siguienteRonda();
      expect(p.rondaActual, 2);
    });
  });
}
