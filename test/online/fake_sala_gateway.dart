// test/online/fake_sala_gateway.dart
import 'dart:async';
import 'package:impostor_game/services/sala_gateway.dart';

/// Implementación en memoria de [SalaGateway] para tests. Guarda un árbol
/// de mapas anidados por ruta 'a/b/c' y notifica a los observadores.
class FakeSalaGateway implements SalaGateway {
  final Map<String, dynamic> _root = {};
  final Map<String, List<StreamController<Map<String, dynamic>?>>> _watchers = {};
  final Map<String, Object?> onDisconnects = {};

  Map<String, dynamic> get raiz => _root;

  List<String> _seg(String ruta) => ruta.split('/').where((s) => s.isNotEmpty).toList();

  Map<String, dynamic>? _leer(List<String> seg) {
    dynamic node = _root;
    for (final s in seg) {
      if (node is Map && node.containsKey(s)) {
        node = node[s];
      } else {
        return null;
      }
    }
    if (node is Map) return Map<String, dynamic>.from(node);
    return null;
  }

  dynamic _rawRead(List<String> seg) {
    dynamic node = _root;
    for (final s in seg) {
      if (node is Map && node.containsKey(s)) {
        node = node[s];
      } else {
        return null;
      }
    }
    return node;
  }

  void _set(List<String> seg, Object? valor) {
    if (seg.isEmpty) return;
    Map<String, dynamic> node = _root;
    for (var i = 0; i < seg.length - 1; i++) {
      node = (node[seg[i]] ??= <String, dynamic>{}) as Map<String, dynamic>;
    }
    if (valor == null) {
      node.remove(seg.last);
    } else {
      node[seg.last] = valor;
    }
  }

  void _notify(String ruta) {
    final seg = _seg(ruta);
    for (var i = seg.length; i >= 0; i--) {
      final prefijo = seg.sublist(0, i).join('/');
      final cs = _watchers[prefijo];
      if (cs != null) {
        final snap = _leer(_seg(prefijo));
        for (final c in cs) {
          if (!c.isClosed) c.add(snap);
        }
      }
    }
  }

  @override
  Future<Map<String, dynamic>?> leerUna(String ruta) async => _leer(_seg(ruta));

  @override
  Future<void> escribir(String ruta, Object? valor) async {
    _set(_seg(ruta), valor);
    _notify(ruta);
  }

  @override
  Future<void> actualizar(String ruta, Map<String, Object?> valores) async {
    valores.forEach((k, v) => _set(_seg('$ruta/$k'), v));
    _notify(ruta);
  }

  @override
  Stream<Map<String, dynamic>?> observar(String ruta) {
    late StreamController<Map<String, dynamic>?> c;
    c = StreamController<Map<String, dynamic>?>.broadcast(
      onCancel: () => _watchers[ruta]?.remove(c),
    );
    (_watchers[ruta] ??= []).add(c);
    scheduleMicrotask(() {
      if (!c.isClosed) c.add(_leer(_seg(ruta)));
    });
    return c.stream;
  }

  @override
  Future<bool> reservarSiAusente(String ruta, Object valor) async {
    if (_rawRead(_seg(ruta)) != null) return false;
    final seg = _seg(ruta);
    if (valor is Map) {
      _set(seg, Map<String, dynamic>.from(valor));
    } else {
      _set(seg, valor);
    }
    _notify(ruta);
    return true;
  }

  @override
  Future<void> alDesconectar(String ruta, Object? valor) async {
    onDisconnects[ruta] = valor;
  }

  @override
  Future<void> cancelarAlDesconectar(String ruta) async {
    onDisconnects.remove(ruta);
  }

  /// Helper de test: simula que este cliente se desconectó.
  Future<void> dispararDesconexion() async {
    for (final e in onDisconnects.entries) {
      _set(_seg(e.key), e.value);
      _notify(e.key);
    }
  }
}
