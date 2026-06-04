import 'package:flutter_test/flutter_test.dart';
import 'package:impostor_game/widgets/adaptive_avatar_grid.dart';

void main() {
  group('computeAvatarLayout', () {
    test('4 caras en área tipo retrato → 2 columnas (2x2 simétrico)', () {
      final l = computeAvatarLayout(count: 4, maxWidth: 160, maxHeight: 240);
      expect(l.columns, 2);
      expect(l.cell, greaterThan(0));
    });
    test('1 cara → 1 columna', () {
      final l = computeAvatarLayout(count: 1, maxWidth: 160, maxHeight: 240);
      expect(l.columns, 1);
    });
    test('tope de tamaño: con pocas caras la celda no supera maxCell', () {
      final l = computeAvatarLayout(count: 2, maxWidth: 400, maxHeight: 400, maxCell: 72);
      expect(l.cell, lessThanOrEqualTo(72));
    });
    test('muchas caras: 11 en retrato dan celda > 0 y columnas >= 3', () {
      final l = computeAvatarLayout(count: 11, maxWidth: 160, maxHeight: 240);
      expect(l.columns, greaterThanOrEqualTo(3));
      expect(l.cell, greaterThan(0));
    });
    test('count 0 no rompe', () {
      final l = computeAvatarLayout(count: 0, maxWidth: 160, maxHeight: 240);
      expect(l.cell, 0);
    });
  });
}
