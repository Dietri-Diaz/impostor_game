// lib/managers/sala_codigo.dart
import 'dart:math';

/// Alfabeto sin caracteres ambiguos (sin O/0, I/1/L) para dictar el código
/// en voz alta sin confusión.
const String kAlfabetoCodigo = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Genera un código de sala de 6 caracteres. La unicidad (no colisión) la
/// garantiza [SalaOnlineManager] reservando el código en la base.
String generarCodigoSala(Random random) {
  final buffer = StringBuffer();
  for (var i = 0; i < 6; i++) {
    buffer.write(kAlfabetoCodigo[random.nextInt(kAlfabetoCodigo.length)]);
  }
  return buffer.toString();
}
