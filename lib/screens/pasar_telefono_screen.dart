// lib/screens/pasar_telefono_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../widgets/auto_fit_title.dart';
import '../widgets/app_button.dart';
import '../services/audio_service.dart';

class PasarTelefonoScreen extends StatefulWidget {
  final String nombreJugador;
  final int numeroJugador;
  final int totalJugadores;
  final VoidCallback onReady;

  const PasarTelefonoScreen({
    super.key,
    required this.nombreJugador,
    required this.numeroJugador,
    required this.totalJugadores,
    required this.onReady,
  });

  @override
  State<PasarTelefonoScreen> createState() => _PasarTelefonoScreenState();
}

class _PasarTelefonoScreenState extends State<PasarTelefonoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapReady() {
    if (_ready) return;
    setState(() => _ready = true);
    AudioService.playClick();

    // Pequeña animación de salida
    _controller.reverse().then((_) {
      widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icono de pasar teléfono — círculo sobrio con tinte danger
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.28),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          size: 56,
                          color: AppColors.danger,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Instrucción
                      Text(
                        'Pasa el teléfono a',
                        style: AppType.body_.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 17,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Nombre del jugador — pill sobrio con borde danger
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: AutoFitTitle(
                          widget.nombreJugador,
                          style: AppType.displayM,
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Contador
                      Text(
                        'Jugador ${widget.numeroJugador} de ${widget.totalJugadores}',
                        style: AppType.bodyS,
                      ),

                      const SizedBox(height: 50),

                      // Botón principal
                      AppButton(
                        text: 'Estoy listo',
                        icon: Icons.visibility_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: _onTapReady,
                      ),

                      const SizedBox(height: 20),

                      // Aviso — AppCard sobria
                      const AppCard(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.gold,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Asegúrate de que nadie más vea la pantalla',
                                style: AppType.bodyS,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
