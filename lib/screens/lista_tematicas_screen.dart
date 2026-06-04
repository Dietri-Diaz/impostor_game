// lib/screens/lista_tematicas_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/loadable_mixin.dart';
import '../repositories/tematica_repository.dart';
import '../models/tematica_personalizada.dart';
import '../services/audio_service.dart';
import '../widgets/app_button.dart';
import 'crear_tematica_screen.dart';

class ListaTematicasScreen extends StatefulWidget {
  const ListaTematicasScreen({super.key});

  @override
  State<ListaTematicasScreen> createState() => _ListaTematicasScreenState();
}

class _ListaTematicasScreenState extends State<ListaTematicasScreen>
    with LoadableMixin {
  final TematicaRepository _repository = TematicaRepository();
  List<TematicaPersonalizada> _tematicas = [];

  @override
  void initState() {
    super.initState();
    _cargarTematicas();
  }

  Future<void> _cargarTematicas() => runLoading(() async {
        final tematicas = await _repository.obtenerTematicas();
        if (mounted) setState(() => _tematicas = tematicas);
      });

  Future<void> _eliminarTematica(TematicaPersonalizada tematica) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20))),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Text('Eliminar temática', style: AppType.titleL),
          ],
        ),
        content: Text(
          '¿Estás seguro de eliminar "${tematica.nombre}"?',
          style: AppType.body_,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: AppType.body_.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: AppType.titleM.copyWith(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _repository.eliminarTematica(tematica.id);
      AudioService.playClick();
      _cargarTematicas();
    }
  }

  void _editarTematica(TematicaPersonalizada tematica) {
    Navigator.push(
      context,
      SlidePageRoute(page: CrearTematicaScreen(tematicaExistente: tematica)),
    ).then((_) => _cargarTematicas());
  }

  void _crearNuevaTematica() {
    Navigator.push(
      context,
      SlidePageRoute(page: const CrearTematicaScreen()),
    ).then((_) => _cargarTematicas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Temáticas Personalizadas',
                onBack: () {
                  AudioService.playClick();
                  Navigator.pop(context);
                },
              ),

              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : _tematicas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.category_outlined,
                                    size: 72,
                                    color: AppColors.textMuted),
                                const SizedBox(height: 20),
                                const Text('No hay temáticas personalizadas',
                                    style: AppType.titleM),
                                const SizedBox(height: 8),
                                const Text('Crea una para personalizar tu juego',
                                    style: AppType.bodyS),
                                const SizedBox(height: 28),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 48),
                                  child: AppButton(
                                    text: 'Nueva Temática',
                                    icon: Icons.add_rounded,
                                    variant: AppButtonVariant.primary,
                                    onPressed: _crearNuevaTematica,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _tematicas.length,
                            itemBuilder: (context, index) {
                              final tematica = _tematicas[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(
                                      milliseconds: 300 + (index * 80)),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(50 * (1 - value), 0),
                                      child: Opacity(
                                          opacity: value.clamp(0.0, 1.0),
                                          child: child),
                                    );
                                  },
                                  child: AppCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceHigh,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: AppColors.border),
                                          ),
                                          child: const Icon(
                                              Icons.category_rounded,
                                              color: AppColors.textSecondary,
                                              size: 22),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(tematica.nombre,
                                                  style: AppType.titleM),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${tematica.personajes.length} personajes',
                                                style: AppType.bodyS,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded,
                                              color: AppColors.safe, size: 22),
                                          onPressed: () =>
                                              _editarTematica(tematica),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_rounded,
                                              color: AppColors.danger,
                                              size: 22),
                                          onPressed: () =>
                                              _eliminarTematica(tematica),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),

              // Create button — shown when list is non-empty
              if (!isLoading && _tematicas.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: AppButton(
                    text: 'Nueva Temática',
                    icon: Icons.add_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _crearNuevaTematica,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
