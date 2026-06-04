// lib/core/loadable_mixin.dart

import 'package:flutter/widgets.dart';

/// Mixin para pantallas que cargan datos asíncronos. Centraliza el patrón
/// `setState(_isLoading = true) -> try -> catch -> finally setState(false)`
/// que se duplicaba en muchas pantallas.
///
/// Uso:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with LoadableMixin {
///   Future<void> _load() => runLoading(() async {
///     final data = await repo.fetch();
///     setState(() => _data = data);
///   });
/// }
/// ```
mixin LoadableMixin<T extends StatefulWidget> on State<T> {
  bool _isLoading = false;
  Object? _lastError;

  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  /// Ejecuta [action] envuelto en un flag de loading que se refleja en
  /// [isLoading]. Si [action] lanza, el error se guarda en [lastError] y
  /// se invoca [onError] (si se provee). Nunca rethrow por defecto: la UI
  /// debe consultar [lastError].
  Future<void> runLoading(
    Future<void> Function() action, {
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    try {
      await action();
    } catch (e, st) {
      if (mounted) {
        setState(() => _lastError = e);
      }
      if (onError != null) onError(e, st);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
