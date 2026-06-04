import 'package:flutter_test/flutter_test.dart';
import 'fake_sala_gateway.dart';

void main() {
  test('escribir + leerUna round-trip en ruta anidada', () async {
    final gw = FakeSalaGateway();
    await gw.escribir('salas/ABC/meta', {'estado': 'lobby', 'rondaActual': 1});
    final m = await gw.leerUna('salas/ABC/meta');
    expect(m!['estado'], 'lobby');
    expect(m['rondaActual'], 1);
  });

  test('leerUna devuelve null si no existe', () async {
    final gw = FakeSalaGateway();
    expect(await gw.leerUna('salas/NOPE/meta'), isNull);
  });

  test('actualizar hace merge parcial sin borrar otros campos', () async {
    final gw = FakeSalaGateway();
    await gw.escribir('salas/ABC/meta', {'estado': 'lobby', 'rondaActual': 1});
    await gw.actualizar('salas/ABC/meta', {'estado': 'votando'});
    final m = await gw.leerUna('salas/ABC/meta');
    expect(m!['estado'], 'votando');
    expect(m['rondaActual'], 1);
  });

  test('observar emite el valor actual y luego los cambios', () async {
    final gw = FakeSalaGateway();
    await gw.escribir('salas/ABC/meta', {'estado': 'lobby'});
    final emisiones = <Map<String, dynamic>?>[];
    final sub = gw.observar('salas/ABC/meta').listen(emisiones.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await gw.actualizar('salas/ABC/meta', {'estado': 'votando'});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(emisiones.last!['estado'], 'votando');
    await sub.cancel();
  });

  test('reservarSiAusente: true la primera vez, false si ya existe', () async {
    final gw = FakeSalaGateway();
    expect(await gw.reservarSiAusente('codigos/ABC', {'host': 'u1'}), true);
    expect(await gw.reservarSiAusente('codigos/ABC', {'host': 'u2'}), false);
  });

  test('alDesconectar + dispararDesconexion aplica el valor', () async {
    final gw = FakeSalaGateway();
    await gw.escribir('salas/ABC/jugadores/u1', {'conectado': true});
    await gw.alDesconectar('salas/ABC/jugadores/u1/conectado', false);
    await gw.dispararDesconexion();
    final m = await gw.leerUna('salas/ABC/jugadores/u1');
    expect(m!['conectado'], false);
  });
}
