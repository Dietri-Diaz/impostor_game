// lib/screens/online/resultado_final_online_screen.dart

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import '../../widgets/auto_fit_title.dart';

class ResultadoFinalOnlineView extends StatefulWidget {
  const ResultadoFinalOnlineView({
    super.key,
    required this.codigo,
    required this.manager,
    required this.esHost,
    this.sync,
    required this.onNuevaPartida,
  });

  final String codigo;
  final SalaOnlineManager manager;
  final bool esHost;
  final RondaOnlineSync? sync;
  final Future<void> Function() onNuevaPartida;

  @override
  State<ResultadoFinalOnlineView> createState() =>
      _ResultadoFinalOnlineViewState();
}

class _ResultadoFinalOnlineViewState extends State<ResultadoFinalOnlineView> {
  bool _cargando = false;

  Future<void> _handleNuevaPartida() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    await widget.onNuevaPartida();
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _handleSalir() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    await widget.manager.salir();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        children: [
          const AppHeader(title: 'Resultado final'),
          Expanded(
            child: StreamBuilder<Map<String, dynamic>?>(
              stream: widget.manager.observarPublico(widget.codigo),
              builder: (context, publicoSnap) {
                return StreamBuilder<List<JugadorSala>>(
                  stream: widget.manager.observarJugadores(widget.codigo),
                  builder: (context, jugSnap) {
                    final publico = publicoSnap.data;
                    final jugadores = jugSnap.data ?? [];

                    if (publico == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.textSecondary),
                      );
                    }

                    final ganador = publico['ganador'] as String?;
                    final reveal =
                        (publico['reveal'] as Map?)
                            ?.cast<String, dynamic>();

                    final ganaronCiviles = ganador == 'jugadores';
                    final Color accent =
                        ganaronCiviles ? AppColors.safe : AppColors.danger;

                    // Resolve impostor names from reveal
                    final impostorUids = reveal == null
                        ? <String>[]
                        : (reveal['impostores'] as List?)
                                ?.map((e) => e.toString())
                                .toList() ??
                            <String>[];
                    final personaje =
                        reveal?['personaje'] as String? ?? '?';

                    final nombresImpostores = impostorUids.map((uid) {
                      return jugadores
                              .where((j) => j.uid == uid)
                              .map((j) => j.nombre)
                              .firstOrNull ??
                          uid;
                    }).toList();

                    final hayMultiples = nombresImpostores.length > 1;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),

                          // Icon circle
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: accent.withValues(alpha: 0.35),
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              ganaronCiviles
                                  ? Icons.celebration_rounded
                                  : Icons.sentiment_very_dissatisfied_rounded,
                              size: 80,
                              color: accent,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Main title
                          AutoFitTitle(
                            ganaronCiviles
                                ? 'GANAN LOS CIVILES'
                                : 'GANA EL IMPOSTOR',
                            style: AppType.displayL.copyWith(color: accent),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),

                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.30)),
                            ),
                            child: Text(
                              ganaronCiviles
                                  ? (hayMultiples
                                      ? 'Eliminaron a los impostores'
                                      : 'Eliminaron al impostor')
                                  : (hayMultiples
                                      ? 'Los impostores sobrevivieron'
                                      : 'El impostor sobrevivió'),
                              style: AppType.bodyS.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Reveal card
                          AppCard(
                            child: Column(
                              children: [
                                Text(
                                  'El personaje era:',
                                  style: AppType.body_.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                AutoFitTitle(
                                  personaje,
                                  style: AppType.displayM.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Divider(
                                      thickness: 1,
                                      color: AppColors.border),
                                ),
                                Text(
                                  hayMultiples
                                      ? 'Los impostores eran:'
                                      : 'El impostor era:',
                                  style: AppType.body_.copyWith(
                                      color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children:
                                      nombresImpostores.map((nombre) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.danger
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(15),
                                        border: Border.all(
                                          color: AppColors.danger
                                              .withValues(alpha: 0.40),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.person_rounded,
                                              color: AppColors.danger,
                                              size: 22),
                                          const SizedBox(width: 6),
                                          Text(
                                            nombre,
                                            style: AppType.titleL.copyWith(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Buttons
                          if (widget.esHost) ...[
                            AppButton(
                              text: 'Nueva partida',
                              icon: Icons.replay_rounded,
                              variant: AppButtonVariant.primary,
                              onPressed: _cargando ? null : _handleNuevaPartida,
                            ),
                            const SizedBox(height: 12),
                            AppButton(
                              text: 'Cerrar sala',
                              icon: Icons.close_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: _cargando ? null : _handleSalir,
                            ),
                          ] else ...[
                            AppButton(
                              text: 'Volver al inicio',
                              icon: Icons.home_rounded,
                              variant: AppButtonVariant.secondary,
                              onPressed: _cargando ? null : _handleSalir,
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
