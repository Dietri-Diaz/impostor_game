// lib/screens/reglas_screen.dart

import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../widgets/auto_fit_title.dart';
import '../widgets/app_button.dart';
import '../services/audio_service.dart';

class ReglasScreen extends StatefulWidget {
  final bool esOnboarding;

  const ReglasScreen({super.key, this.esOnboarding = false});

  @override
  State<ReglasScreen> createState() => _ReglasScreenState();
}

class _ReglasScreenState extends State<ReglasScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_ReglaPage> _reglas = [
    _ReglaPage(
      icon: Icons.groups_rounded,
      titulo: 'Reúne a tus amigos',
      descripcion:
          'Junta de 3 a 8 jugadores alrededor de un solo celular. No necesitas internet ni nada más.',
      color: AppColors.accent,
      emoji: '👥',
    ),
    _ReglaPage(
      icon: Icons.category_rounded,
      titulo: 'Elige una temática',
      descripcion:
          'Selecciona una temática como Dragon Ball, Marvel, Naruto u One Piece. También puedes crear las tuyas propias.',
      color: AppColors.accentAlt,
      emoji: '🎭',
    ),
    _ReglaPage(
      icon: Icons.visibility_off_rounded,
      titulo: 'Descubre tu rol',
      descripcion:
          'Cada jugador ve su rol en secreto. Los civiles conocen el personaje secreto. El impostor NO sabe cuál es.',
      color: AppColors.purple,
      emoji: '🕵️',
    ),
    _ReglaPage(
      icon: Icons.question_answer_rounded,
      titulo: 'Discutan con pistas',
      descripcion:
          'Hablen sobre el personaje sin decir su nombre directamente. Hagan preguntas para descubrir quién no sabe la respuesta.',
      color: AppColors.primary,
      emoji: '🗣️',
    ),
    _ReglaPage(
      icon: Icons.how_to_vote_rounded,
      titulo: 'Voten al sospechoso',
      descripcion:
          'Cuando termine el tiempo, voten a quién creen que es el impostor. El más votado será eliminado.',
      color: AppColors.victory,
      emoji: '🗳️',
    ),
    _ReglaPage(
      icon: Icons.emoji_events_rounded,
      titulo: '¿Quién gana?',
      descripcion:
          'Los civiles ganan si eliminan al impostor. El impostor gana si sobrevive hasta que solo queden 2 jugadores.',
      color: AppColors.gold,
      emoji: '🏆',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              if (!widget.esOnboarding)
                AppHeader(
                  title: 'Cómo se juega',
                  onBack: () {
                    AudioService.playClick();
                    Navigator.pop(context);
                  },
                ),

              if (widget.esOnboarding)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Aprende a jugar',
                          style: AppType.titleL,
                        ),
                      ),
                      AppButton(
                        text: 'Saltar',
                        variant: AppButtonVariant.secondary,
                        height: 40,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

              // Page indicator — dots danger/border
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: List.generate(_reglas.length, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: index <= _currentPage
                              ? AppColors.danger
                              : AppColors.border,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Pages
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _reglas.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final regla = _reglas[index];
                    return Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Emoji grande con animación de entrada
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: child,
                              );
                            },
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: regla.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: regla.color.withValues(alpha: 0.25),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  regla.emoji,
                                  style: const TextStyle(fontSize: 70),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Título de la página
                          AutoFitTitle(
                            regla.titulo,
                            style: AppType.displayM,
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Descripción
                          Text(
                            regla.descripcion,
                            style: AppType.body_.copyWith(
                              height: 1.6,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 20),

                          // Número de paso — badge sobrio
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: Text(
                              'Paso ${index + 1} de ${_reglas.length}',
                              style: AppType.bodyS,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Bottom navigation
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    if (_currentPage > 0) ...[
                      Expanded(
                        child: AppButton(
                          text: 'Anterior',
                          icon: Icons.arrow_back_rounded,
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            AudioService.playClick();
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: AppButton(
                        text: _currentPage == _reglas.length - 1
                            ? (widget.esOnboarding ? 'Empezar' : 'Entendido')
                            : 'Siguiente',
                        icon: _currentPage == _reglas.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          AudioService.playClick();
                          if (_currentPage == _reglas.length - 1) {
                            Navigator.pop(context);
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReglaPage {
  final IconData icon;
  final String titulo;
  final String descripcion;
  final Color color;
  final String emoji;

  _ReglaPage({
    required this.icon,
    required this.titulo,
    required this.descripcion,
    required this.color,
    required this.emoji,
  });
}
