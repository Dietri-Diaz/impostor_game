// lib/screens/configurar_partida_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/loadable_mixin.dart';
import '../data/tematicas_data.dart';
import '../services/audio_service.dart';
import '../widgets/app_button.dart';
import 'configurar_jugadores_screen.dart';
import 'lista_tematicas_screen.dart';
import '../repositories/tematica_repository.dart';
import '../models/tematica_personalizada.dart';

class ConfigurarPartidaScreen extends StatefulWidget {
  const ConfigurarPartidaScreen({super.key});

  @override
  State<ConfigurarPartidaScreen> createState() =>
      _ConfigurarPartidaScreenState();
}

class _ConfigurarPartidaScreenState extends State<ConfigurarPartidaScreen>
    with LoadableMixin {
  String? tematicaSeleccionada;
  List<TematicaPersonalizada> _tematicasPersonalizadas = [];
  final TematicaRepository _repository = TematicaRepository();

  @override
  void initState() {
    super.initState();
    _cargarTematicasPersonalizadas();
  }

  Future<void> _cargarTematicasPersonalizadas() => runLoading(() async {
        final tematicas = await _repository.obtenerTematicas();
        if (mounted) setState(() => _tematicasPersonalizadas = tematicas);
      });

  Future<void> _verTematicasPersonalizadas() async {
    await Navigator.push(
      context,
      SlidePageRoute(page: const ListaTematicasScreen()),
    );
    _cargarTematicasPersonalizadas();
  }

  void _continuarANombres() {
    if (tematicaSeleccionada == null) {
      AudioService.playClick();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Selecciona una temática'),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    AudioService.playReveal();

    Navigator.push(
      context,
      SlidePageRoute(
        page: ConfigurarJugadoresScreen(
          tematica: tematicaSeleccionada!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todasTematicas = [
      ...tematicasData.keys.map((nombre) => {
            'nombre': nombre,
            'cantidad': tematicasData[nombre]!.length,
            'esPersonalizada': false,
          }),
      ..._tematicasPersonalizadas.map((t) => {
            'nombre': t.nombre,
            'cantidad': t.personajes.length,
            'esPersonalizada': true,
          }),
    ];

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              AppHeader(
                title: 'Elige tu temática',
                onBack: () {
                  AudioService.playClick();
                  Navigator.pop(context);
                },
                actions: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_rounded,
                        color: AppColors.primary),
                    onPressed: _verTematicasPersonalizadas,
                  ),
                ],
              ),

              // Grid de temáticas
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: todasTematicas.length,
                          itemBuilder: (context, index) {
                            final tematica = todasTematicas[index];
                            final nombre = tematica['nombre'] as String;
                            final cantidad = tematica['cantidad'] as int;
                            final esPersonalizada =
                                tematica['esPersonalizada'] as bool;
                            final isSelected =
                                nombre == tematicaSeleccionada;

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                  milliseconds: 300 + (index * 80)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Opacity(
                                      opacity: value.clamp(0.0, 1.0),
                                      child: child),
                                );
                              },
                              child: GestureDetector(
                                onTap: () {
                                  AudioService.playClick();
                                  setState(() =>
                                      tematicaSeleccionada = nombre);
                                },
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.danger
                                          : AppColors.border,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.danger
                                                  .withValues(alpha: 0.22),
                                              blurRadius: 16,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      _TematicaLogo(
                                        nombre: nombre,
                                        isSelected: isSelected,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        nombre,
                                        style: AppType.titleM,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      // Chip de cantidad (sober pill)
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceHigh,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.border),
                                        ),
                                        child: Text(
                                          '$cantidad personajes',
                                          style: AppType.bodyS,
                                        ),
                                      ),
                                      if (esPersonalizada) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'CUSTOM',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontFamily: 'Inter',
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: tematicaSeleccionada != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppButton(
                text: 'Continuar',
                icon: Icons.arrow_forward_rounded,
                onPressed: _continuarANombres,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

/// Avatar circular del logo de la temática (predefinida). Para temáticas
/// personalizadas o cuando no hay logo, cae al ícono genérico.
class _TematicaLogo extends StatelessWidget {
  const _TematicaLogo({
    required this.nombre,
    required this.isSelected,
  });

  final String nombre;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final logo = tematicasLogos[nombre];
    // Rectángulo redondeado landscape: la mayoría de logos de series y
    // animes son horizontales, no encajan bien en un círculo. Un 120x68
    // (~1.77:1) muestra completos los logos sin distorsión.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 120,
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: logo == null
          ? Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.category_rounded,
              color: isSelected ? AppColors.danger : AppColors.textMuted,
              size: 32,
            )
          : Image.asset(
              logo,
              fit: BoxFit.contain,
              cacheWidth: 240, // 120 × 2 para HiDPI
              errorBuilder: (_, __, ___) => Icon(
                Icons.category_rounded,
                color: isSelected ? AppColors.danger : AppColors.textMuted,
                size: 32,
              ),
            ),
    );
  }
}
