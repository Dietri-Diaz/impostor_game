import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/services/sala_gateway.dart';
import 'package:impostor_game/managers/sala_predicados.dart';

JugadorSala j(String uid, {bool conectado = true, bool listo = false, bool eliminado = false}) =>
    JugadorSala(uid: uid, nombre: uid, numero: 1,
        conectado: conectado, listo: listo, eliminado: eliminado);

void main() {
  test('puedeIniciar requiere >=3 conectados', () {
    expect(puedeIniciar([j('a'), j('b')]), false);
    expect(puedeIniciar([j('a'), j('b'), j('c')]), true);
  });

  test('todosVotaron ignora eliminados y desconectados', () {
    final jugadores = [
      j('a'), j('b'), j('c', eliminado: true), j('d', conectado: false),
    ];
    expect(todosVotaron(jugadores, {'a': 'b'}), false);
    expect(todosVotaron(jugadores, {'a': 'b', 'b': 'a'}), true);
  });
}
