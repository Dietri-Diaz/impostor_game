// lib/screens/online/crear_sala_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../core/constants.dart';
import '../../core/validators.dart';
import '../../data/tematicas_data.dart';
import '../../managers/sala_online_manager.dart';
import '../../models/configuracion_partida.dart';
import '../../services/firebase_sala_gateway.dart';
import '../../services/firebase_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import 'lobby_online_screen.dart';

class CrearSalaScreen extends StatefulWidget {
  const CrearSalaScreen({super.key});

  @override
  State<CrearSalaScreen> createState() => _CrearSalaScreenState();
}

class _CrearSalaScreenState extends State<CrearSalaScreen> {
  final _nombreCtrl = TextEditingController();
  String _tematica = tematicasData.keys.first;
  int _numImpostores = GameConstants.minImpostors;
  bool _eliminarEnEmpate = false;
  bool _cargando = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _crearSala() async {
    final err = Validators.playerName(_nombreCtrl.text);
    if (err != null) {
      _showSnackBar(err);
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
      final codigo = await mgr.crearSala(
        nombreHost: _nombreCtrl.text.trim(),
        tematica: _tematica,
        configuracion: ConfiguracionPartida(
          numeroImpostores: _numImpostores,
          eliminarEnEmpate: _eliminarEnEmpate,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(SlidePageRoute(
        page: LobbyOnlineScreen(
          codigo: codigo,
          manager: mgr,
          esHost: true,
          tematica: _tematica,
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
            title: 'Crear sala',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Nombre del anfitrión
                  const _SectionLabel('TU NOMBRE'),
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

                  const SizedBox(height: 24),

                  // Temática
                  const _SectionLabel('TEMÁTICA'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tematicasData.keys.map((t) {
                      final seleccionado = t == _tematica;
                      return GestureDetector(
                        onTap: () => setState(() => _tematica = t),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: seleccionado
                                ? AppColors.danger.withValues(alpha: 0.18)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: seleccionado
                                  ? AppColors.danger.withValues(alpha: 0.7)
                                  : AppColors.border,
                              width: seleccionado ? 1.5 : 1,
                            ),
                          ),
                          child: Text(
                            t,
                            style: AppType.bodyS.copyWith(
                              color: seleccionado
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Número de impostores
                  const _SectionLabel('IMPOSTORES'),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Número de impostores',
                            style: AppType.titleM),
                        Row(
                          children: [
                            _StepButton(
                              icon: Icons.remove_rounded,
                              enabled: _numImpostores >
                                  GameConstants.minImpostors,
                              onTap: () =>
                                  setState(() => _numImpostores--),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16),
                              child: Text(
                                '$_numImpostores',
                                style: AppType.titleL,
                              ),
                            ),
                            _StepButton(
                              icon: Icons.add_rounded,
                              enabled: _numImpostores < 3,
                              onTap: () =>
                                  setState(() => _numImpostores++),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Eliminar en empate
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 4),
                    child: SwitchListTile(
                      value: _eliminarEnEmpate,
                      onChanged: (v) =>
                          setState(() => _eliminarEnEmpate = v),
                      title: const Text('Eliminar en empate',
                          style: AppType.titleM),
                      subtitle: const Text(
                        'Si hay empate de votos, se elimina a uno al azar.',
                        style: AppType.bodyS,
                      ),
                      activeThumbColor: AppColors.danger,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Botón crear
                  AppButton(
                    text: _cargando ? 'Creando sala…' : 'Crear sala',
                    icon: _cargando ? null : Icons.add_rounded,
                    onPressed: _cargando ? null : _crearSala,
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

/// Etiqueta de sección reutilizable (evita los `Text(x, style: AppType.label)`
/// no-const que disparan prefer_const_constructors).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppType.label);
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? AppColors.surfaceHigh : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}
