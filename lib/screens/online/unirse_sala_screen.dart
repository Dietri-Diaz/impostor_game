// lib/screens/online/unirse_sala_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../managers/sala_codigo.dart';
import '../../managers/sala_online_manager.dart';
import '../../services/firebase_sala_gateway.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import 'lobby_online_screen.dart';

/// Formateador que convierte la entrada a mayúsculas y solo permite
/// caracteres del alfabeto de códigos de sala.
class _CodigoSalaFormatter extends TextInputFormatter {
  static final _permitidos = RegExp('[${RegExp.escape(kAlfabetoCodigo)}]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    final filtrado = upper.split('').where((c) => _permitidos.hasMatch(c)).join();
    return newValue.copyWith(
      text: filtrado,
      selection: TextSelection.collapsed(offset: filtrado.length),
    );
  }
}

class UnirseSalaScreen extends StatefulWidget {
  const UnirseSalaScreen({super.key});

  @override
  State<UnirseSalaScreen> createState() => _UnirseSalaScreenState();
}

class _UnirseSalaScreenState extends State<UnirseSalaScreen> {
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _entrar() async {
    final code = _codigoCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      _showSnackBar('El código debe tener 6 caracteres.');
      return;
    }

    final errNombre = Validators.playerName(_nombreCtrl.text);
    if (errNombre != null) {
      _showSnackBar(errNombre);
      return;
    }

    final firebase = context.read<FirebaseService?>();
    if (firebase == null) {
      _showSnackBar('El modo online no está disponible (revisa tu conexión).');
      return;
    }

    setState(() => _cargando = true);
    try {
      final gw = FirebaseSalaGateway(firebase.db);
      final mgr = SalaOnlineManager(gateway: gw, uid: firebase.uid);
      await mgr.unirseSala(
        codigo: code,
        nombre: _nombreCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(SlidePageRoute(
        page: LobbyOnlineScreen(
          codigo: code,
          manager: mgr,
          esHost: false,
          tematica: null,
        ),
      ));
    } on SalaException catch (e) {
      if (mounted) _showSnackBar(e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          AppHeader(
            title: 'Unirse con código',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Código de sala
                  const Text('CÓDIGO DE SALA', style: AppType.label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _codigoCtrl,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [_CodigoSalaFormatter()],
                    style: AppType.displayM.copyWith(
                      letterSpacing: 8,
                      fontFamily: AppType.body,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'XXXXXX',
                      counterText: '',
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Nombre del jugador
                  const Text('TU NOMBRE', style: AppType.label),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nombreCtrl,
                    maxLength: GameConstants.maxPlayerNameLength,
                    textCapitalization: TextCapitalization.words,
                    style: AppType.titleM,
                    decoration: const InputDecoration(
                      hintText: 'Cómo te llamas',
                      counterText: '',
                    ),
                  ),

                  const SizedBox(height: 32),

                  AppButton(
                    text: _cargando ? 'Entrando…' : 'Entrar',
                    icon: _cargando ? null : Icons.login_rounded,
                    onPressed: _cargando ? null : _entrar,
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
