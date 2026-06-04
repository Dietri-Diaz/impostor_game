// lib/services/firebase_sala_gateway.dart
import 'package:firebase_database/firebase_database.dart';
import 'sala_gateway.dart';

/// Implementación real de [SalaGateway] sobre Firebase Realtime Database.
class FirebaseSalaGateway implements SalaGateway {
  FirebaseSalaGateway(this._db);
  final FirebaseDatabase _db;

  DatabaseReference _ref(String ruta) => _db.ref(ruta);

  Map<String, dynamic>? _asMap(Object? v) {
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    return null;
  }

  @override
  Future<Map<String, dynamic>?> leerUna(String ruta) async {
    final snap = await _ref(ruta).get();
    if (!snap.exists) return null;
    return _asMap(snap.value);
  }

  @override
  Future<void> escribir(String ruta, Object? valor) => _ref(ruta).set(valor);

  @override
  Future<void> actualizar(String ruta, Map<String, Object?> valores) =>
      _ref(ruta).update(valores);

  @override
  Stream<Map<String, dynamic>?> observar(String ruta) => _ref(ruta).onValue.map(
        (e) => e.snapshot.exists ? _asMap(e.snapshot.value) : null,
      );

  @override
  Future<bool> reservarSiAusente(String ruta, Object valor) async {
    final result = await _ref(ruta).runTransaction((current) {
      if (current != null) return Transaction.abort();
      return Transaction.success(valor);
    });
    return result.committed;
  }

  @override
  Future<void> alDesconectar(String ruta, Object? valor) =>
      _ref(ruta).onDisconnect().set(valor);

  @override
  Future<void> cancelarAlDesconectar(String ruta) =>
      _ref(ruta).onDisconnect().cancel();
}
