import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/models/partida.dart';
import 'package:impostor_game/models/configuracion_partida.dart';
import 'package:impostor_game/models/jugador.dart';

void main() {
  test('Partida round-trips through toJson/fromJson', () {
    final original = Partida(
      id: 'p1',
      tematica: 'Animales',
      personajeSecreto: 'León',
      configuracion: ConfiguracionPartida(numeroImpostores: 2),
      jugadores: [
        Jugador(id: 'u1', nombre: 'Ana', numero: 1, esImpostor: true),
        Jugador(id: 'u2', nombre: 'Beto', numero: 2, esImpostor: false),
      ],
    );

    final restored = Partida.fromJson(original.toJson());

    expect(restored.id, 'p1');
    expect(restored.tematica, 'Animales');
    expect(restored.personajeSecreto, 'León');
    expect(restored.jugadores.length, 2);
    expect(restored.jugadores.first.esImpostor, true);
    expect(restored.configuracion.numeroImpostores, 2);
    expect(restored.rondaActual, 1);
    expect(restored.finalizada, false);
  });
}
