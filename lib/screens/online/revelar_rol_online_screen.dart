// lib/screens/online/revelar_rol_online_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_typography.dart';
import '../../managers/ronda_online_sync.dart';
import '../../managers/sala_online_manager.dart';
import '../../services/preferences_service.dart';
import '../../services/sala_gateway.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_components.dart';
import '../../widgets/auto_fit_title.dart';

/// Vista de revelación de rol para el modo online.
/// Cada jugador ve solo su propio rol en su dispositivo.
class RevelarRolOnlineView extends StatefulWidget {
  const RevelarRolOnlineView({
    super.key,
    required this.codigo,
    required this.manager,
    required this.esHost,
    this.sync,
  });

  final String codigo;
  final SalaOnlineManager manager;
  final bool esHost;
  final RondaOnlineSync? sync;

  @override
  State<RevelarRolOnlineView> createState() => _RevelarRolOnlineViewState();
}

class _RevelarRolOnlineViewState extends State<RevelarRolOnlineView> {
  bool _visto = false;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: StreamBuilder<RolPrivado?>(
        stream: widget.manager.observarMiRol(widget.codigo),
        builder: (context, snap) {
          if (!snap.hasData || snap.data == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.textMuted),
            );
          }

          final rol = snap.data!;
          return _buildContent(context, rol);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, RolPrivado rol) {
    final colorful = context.read<PreferencesService>().colorfulReveal;

    // Background gradient — discreet by default (same for both roles to avoid
    // shoulder-surf spoilers); colorful mode uses per-role tints.
    final List<Color> bgColors = colorful
        ? (rol.esImpostor
            ? [AppColors.dangerDark, AppColors.danger]
            : [AppColors.safeDark, AppColors.safe])
        : AppColors.darkBgGradient;

    final accentColor = rol.esImpostor ? AppColors.danger : AppColors.safe;
    final accentDark = rol.esImpostor ? AppColors.dangerDark : AppColors.safeDark;

    return GradientBackground(
      colors: bgColors,
      child: Column(
        children: [
          const AppHeader(
            title: 'Tu rol',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),

                  if (_visto) ...[
                    // Anti-spoiler: hide role after acknowledgement
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: AppColors.safe,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Esperando a los demás…',
                      style: AppType.titleL,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ya viste tu rol. El anfitrión iniciará\nla discusión cuando todos estén listos.',
                      style: AppType.body_,
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Role ring
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentColor, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.35),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                rol.esImpostor ? '☠️' : '🎭',
                                style: const TextStyle(fontSize: 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Label
                    Text(
                      rol.esImpostor ? 'TU ROL' : 'TU PERSONAJE',
                      style: AppType.label.copyWith(
                        color: colorful ? AppColors.textPrimary : AppColors.textMuted,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role chip / character name pill
                    Container(
                      constraints: const BoxConstraints(maxWidth: 320),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(60),
                        boxShadow: [
                          BoxShadow(
                            color: accentDark.withValues(alpha: 0.5),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: rol.esImpostor
                          ? Text(
                              'ERES EL IMPOSTOR',
                              style: AppType.displayM.copyWith(
                                color: AppColors.white,
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : AutoFitTitle(
                              rol.personajeVisto ?? '',
                              style: AppType.displayM.copyWith(
                                color: AppColors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Helper text
                    Text(
                      rol.esImpostor
                          ? 'Descúbrelo sin que te descubran.'
                          : 'Tu personaje.\nHay un impostor entre ustedes.',
                      style: AppType.body_.copyWith(
                        color: colorful
                            ? AppColors.white.withValues(alpha: 0.75)
                            : AppColors.textSecondary,
                        height: 1.55,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // "Entendido" button — hides the role card
                    AppButton(
                      text: 'Entendido',
                      icon: Icons.visibility_off_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () => setState(() => _visto = true),
                    ),
                  ],

                  // Host-only: continue to discussion
                  if (widget.esHost && widget.sync != null) ...[
                    const SizedBox(height: 16),
                    AppButton(
                      text: 'Continuar a discusión',
                      icon: Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: () => widget.sync!.irADiscusion(),
                    ),
                  ],

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
