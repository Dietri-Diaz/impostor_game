import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/managers/sala_codigo.dart';

void main() {
  test('código tiene 6 chars del alfabeto sin ambiguos', () {
    final r = Random(42);
    for (var i = 0; i < 200; i++) {
      final code = generarCodigoSala(r);
      expect(code.length, 6);
      expect(RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code),
          true, reason: 'código inválido: $code');
    }
  });

  test('es determinista con el mismo seed', () {
    expect(generarCodigoSala(Random(7)), generarCodigoSala(Random(7)));
  });
}
