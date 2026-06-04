import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/services/sala_gateway.dart';

void main() {
  test('JugadorSala round-trip', () {
    const j = JugadorSala(
      uid: 'u1', nombre: 'Ana', numero: 1,
      conectado: true, listo: false, eliminado: false);
    final back = JugadorSala.fromMap('u1', j.toMap());
    expect(back.nombre, 'Ana');
    expect(back.numero, 1);
    expect(back.conectado, true);
    expect(back.eliminado, false);
  });

  test('EstadoSala se parsea por nombre con fallback a lobby', () {
    expect(estadoSalaFromName('votando'), EstadoSala.votando);
    expect(estadoSalaFromName('basura'), EstadoSala.lobby);
  });

  test('RolPrivado guarda null para impostor', () {
    const rol = RolPrivado(esImpostor: true, personajeVisto: null);
    final back = RolPrivado.fromMap(rol.toMap());
    expect(back.esImpostor, true);
    expect(back.personajeVisto, null);
  });
}
