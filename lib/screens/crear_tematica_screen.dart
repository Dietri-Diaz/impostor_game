// lib/screens/crear_tematica_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../core/constants.dart';
import '../core/validators.dart';
import '../repositories/tematica_repository.dart';
import '../models/tematica_personalizada.dart';
import '../services/audio_service.dart';
import '../widgets/app_button.dart';

class CrearTematicaScreen extends StatefulWidget {
  final TematicaPersonalizada? tematicaExistente;

  const CrearTematicaScreen({super.key, this.tematicaExistente});

  @override
  State<CrearTematicaScreen> createState() => _CrearTematicaScreenState();
}

class _CrearTematicaScreenState extends State<CrearTematicaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _personajeController = TextEditingController();
  final List<String> _personajes = [];
  final TematicaRepository _repository = TematicaRepository();
  bool _isEditing = false;

  static const int _minPersonajes = GameConstants.minCharacters;
  static const int _maxPersonajes = GameConstants.maxCharacters;

  @override
  void initState() {
    super.initState();
    if (widget.tematicaExistente != null) {
      _isEditing = true;
      _nombreController.text = widget.tematicaExistente!.nombre;
      _personajes.addAll(widget.tematicaExistente!.personajes);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _personajeController.dispose();
    super.dispose();
  }

  void _agregarPersonaje() {
    final personaje = _personajeController.text.trim();
    final error = Validators.characterName(personaje);
    if (error != null) {
      _showWarning(error);
      return;
    }

    final yaExiste = _personajes.any(
      (p) => p.toLowerCase() == personaje.toLowerCase(),
    );
    if (yaExiste) {
      _showWarning('Este personaje ya existe');
      return;
    }

    if (_personajes.length >= _maxPersonajes) {
      _showWarning('Máximo $_maxPersonajes personajes');
      return;
    }

    setState(() {
      _personajes.add(personaje);
      _personajeController.clear();
    });
    AudioService.playClick();
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _eliminarPersonaje(int index) {
    setState(() => _personajes.removeAt(index));
    AudioService.playClick();
  }

  Future<void> _guardarTematica() async {
    if (!_formKey.currentState!.validate()) return;

    final listError = Validators.characterList(_personajes);
    if (listError != null) {
      _showWarning(listError);
      return;
    }

    try {
      final tematica = TematicaPersonalizada(
        id: _isEditing ? widget.tematicaExistente!.id : null,
        nombre: _nombreController.text.trim(),
        personajes: _personajes,
        fechaCreacion:
            _isEditing ? widget.tematicaExistente!.fechaCreacion : null,
      );

      if (_isEditing) {
        await _repository.actualizarTematica(tematica);
      } else {
        await _repository.guardarTematica(tematica);
      }

      AudioService.playVictory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(_isEditing
                    ? 'Temática actualizada'
                    : 'Temática creada exitosamente'),
              ],
            ),
            backgroundColor: AppColors.victory,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppHeader(
                    title: _isEditing ? 'Editar Temática' : 'Crear Temática',
                    onBack: () {
                      AudioService.playClick();
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Nombre field
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: TextFormField(
                      controller: _nombreController,
                      style: AppType.titleM,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la temática',
                        labelStyle:
                            AppType.bodyS.copyWith(color: AppColors.textMuted),
                        hintText: 'Ej: Mis Amigos, Familia, etc.',
                        hintStyle:
                            AppType.bodyS.copyWith(color: AppColors.textMuted),
                        prefixIcon: const Icon(Icons.category_rounded,
                            color: AppColors.textSecondary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 18),
                      ),
                      validator: Validators.topicName,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Add character field
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _personajeController,
                            style: AppType.titleM,
                            decoration: InputDecoration(
                              labelText: 'Agregar personaje',
                              labelStyle: AppType.bodyS
                                  .copyWith(color: AppColors.textMuted),
                              hintText: 'Ej: Juan, Goku, etc.',
                              hintStyle: AppType.bodyS
                                  .copyWith(color: AppColors.textMuted),
                              prefixIcon: const Icon(Icons.person_add_rounded,
                                  color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 18),
                            ),
                            onFieldSubmitted: (_) => _agregarPersonaje(),
                          ),
                        ),
                        // Add button — safe tint, sober
                        GestureDetector(
                          onTap: _agregarPersonaje,
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.safe.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.safe.withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: AppColors.safe, size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Counter + progress bar
                  _CounterCard(
                    cantidad: _personajes.length,
                    minPersonajes: _minPersonajes,
                    maxPersonajes: _maxPersonajes,
                  ),
                  const SizedBox(height: 12),

                  // Characters list
                  Expanded(
                    child: AppCard(
                      padding: const EdgeInsets.all(12),
                      child: _personajes.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_off_outlined,
                                      size: 50, color: AppColors.textMuted),
                                  SizedBox(height: 12),
                                  Text('No hay personajes agregados',
                                      style: AppType.bodyS),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _personajes.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceHigh,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.surfaceHigh,
                                        child: Text(
                                          '${index + 1}',
                                          style: AppType.bodyS.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _personajes[index],
                                          style: AppType.titleM,
                                        ),
                                      ),
                                      // Delete button — danger tint, sober
                                      GestureDetector(
                                        onTap: () =>
                                            _eliminarPersonaje(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.danger
                                                .withValues(alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: AppColors.danger
                                                    .withValues(alpha: 0.25)),
                                          ),
                                          child: const Icon(
                                              Icons.delete_rounded,
                                              color: AppColors.danger,
                                              size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  AppButton(
                    text: _isEditing ? 'ACTUALIZAR' : 'GUARDAR TEMÁTICA',
                    icon: Icons.save_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _guardarTematica,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta con contador y barra de progreso para visualizar el rango
/// permitido de personajes. Verde si estás en rango, rojo si te falta para
/// el mínimo, naranja cuando llegas al tope.
class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.cantidad,
    required this.minPersonajes,
    required this.maxPersonajes,
  });

  final int cantidad;
  final int minPersonajes;
  final int maxPersonajes;

  @override
  Widget build(BuildContext context) {
    final faltaMinimo = cantidad < minPersonajes;
    final enMaximo = cantidad >= maxPersonajes;
    final progress = (cantidad / maxPersonajes).clamp(0.0, 1.0);

    final Color barColor;
    final String mensaje;
    if (faltaMinimo) {
      barColor = AppColors.danger;
      mensaje = 'Faltan ${minPersonajes - cantidad} para el mínimo';
    } else if (enMaximo) {
      barColor = AppColors.safe;
      mensaje = 'Máximo alcanzado';
    } else {
      barColor = AppColors.safe;
      mensaje = 'Listo (puedes seguir agregando)';
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.people_rounded,
                  color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personajes: $cantidad / $maxPersonajes',
                style: AppType.titleM,
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: barColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  mensaje,
                  style: AppType.bodyS.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      color: AppColors.border.withValues(alpha: 0.4),
                    ),
                    FractionallySizedBox(
                      widthFactor: value,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Marca visual del mínimo requerido.
                    Align(
                      alignment: Alignment(
                        (minPersonajes / maxPersonajes) * 2 - 1,
                        0,
                      ),
                      child: Container(
                        width: 2,
                        height: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
