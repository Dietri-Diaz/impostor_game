// test/validators_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/core/validators.dart';

void main() {
  group('Validators.playerName', () {
    test('rechaza vacío', () {
      expect(Validators.playerName(''), isNotNull);
      expect(Validators.playerName('   '), isNotNull);
      expect(Validators.playerName(null), isNotNull);
    });

    test('rechaza demasiado corto', () {
      expect(Validators.playerName('A'), isNotNull);
    });

    test('acepta nombres válidos', () {
      expect(Validators.playerName('Ana'), isNull);
      expect(Validators.playerName('Bo'), isNull);
    });
  });

  group('Validators.findDuplicate', () {
    test('detecta duplicados case-insensitive', () {
      expect(Validators.findDuplicate(['Ana', 'ana']), 'ana');
    });

    test('ignora espacios', () {
      expect(Validators.findDuplicate(['Ana', ' Ana ']), 'Ana');
    });

    test('devuelve null si no hay duplicados', () {
      expect(Validators.findDuplicate(['Ana', 'Bob', 'Carlos']), isNull);
    });
  });

  group('Validators.playerList', () {
    test('rechaza menos del mínimo', () {
      expect(Validators.playerList(['Ana', 'Bob']), isNotNull);
    });

    test('rechaza si hay duplicado (case-insensitive)', () {
      final r = Validators.playerList(['Ana', 'Bob', 'ANA']);
      expect(r, isNotNull);
      expect(r!.toLowerCase(), contains('ana'));
    });

    test('acepta lista válida', () {
      expect(Validators.playerList(['Ana', 'Bob', 'Carlos']), isNull);
    });
  });

  group('Validators.characterList', () {
    test('rechaza menos del mínimo', () {
      expect(Validators.characterList(['Goku']), isNotNull);
    });

    test('detecta duplicados', () {
      final r = Validators.characterList(['Goku', 'Vegeta', 'goku']);
      expect(r, isNotNull);
    });

    test('acepta lista válida', () {
      expect(
        Validators.characterList(['Goku', 'Vegeta', 'Piccolo']),
        isNull,
      );
    });
  });
}
