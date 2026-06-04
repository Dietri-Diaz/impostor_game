// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_typography.dart';
import '../services/audio_service.dart';
import '../services/preferences_service.dart';
import '../services/session_persistence.dart';
import '../widgets/app_button.dart';
import '../widgets/app_components.dart';
import '../widgets/auto_fit_title.dart';
import 'configurar_partida_screen.dart';
import 'lobby_screen.dart';
import 'reglas_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoController.forward();

    // Mostrar onboarding la primera vez que se abre la app.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeMostrarOnboarding();
    });
  }

  Future<void> _maybeMostrarOnboarding() async {
    if (!mounted) return;
    final prefs = context.read<PreferencesService>();
    if (prefs.onboardingDone) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ReglasScreen(esOnboarding: true),
      ),
    );
    await prefs.setOnboardingDone(true);
  }

  @override
  void dispose() {
    _logoController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _mostrarAjustes() {
    AudioService.playClick();
    final prefs = context.read<PreferencesService>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return AppSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Text('Ajustes', style: AppTheme.headingSmall),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Toggle: Saltar "Pasa el teléfono"
                  GestureDetector(
                    onTap: () async {
                      AudioService.playClick();
                      final nuevo = !prefs.skipPasaTelefono;
                      await prefs.setSkipPasaTelefono(nuevo);
                      setSheetState(() {});
                    },
                    child: AppCard(
                      borderColor: prefs.skipPasaTelefono
                          ? AppColors.danger.withValues(alpha: 0.5)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            prefs.skipPasaTelefono
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: prefs.skipPasaTelefono
                                ? AppColors.danger
                                : AppTheme.textMuted,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Saltar "Pasa el teléfono"',
                                    style: AppTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  prefs.skipPasaTelefono
                                      ? 'Se revela el rol del siguiente jugador sin pantalla intermedia.'
                                      : 'Muestra una pantalla "Pasa el teléfono a X" entre cada revelación.',
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Toggle: Pantalla a todo color
                  GestureDetector(
                    onTap: () async {
                      AudioService.playClick();
                      final nuevo = !prefs.colorfulReveal;
                      await prefs.setColorfulReveal(nuevo);
                      setSheetState(() {});
                    },
                    child: AppCard(
                      borderColor: prefs.colorfulReveal
                          ? AppColors.safe.withValues(alpha: 0.5)
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            prefs.colorfulReveal
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: prefs.colorfulReveal
                                ? AppColors.safe
                                : AppTheme.textMuted,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pantalla a todo color',
                                    style: AppTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Muestra la revelación de rol con fondo de color (rojo/verde). '
                                  'Por defecto es discreta para no delatar el rol.',
                                  style: AppTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  AppButton(
                    text: 'Cerrar',
                    icon: Icons.check_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      AudioService.playClick();
                      Navigator.pop(sheetCtx);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarAcercaDe() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.danger),
            const SizedBox(width: 10),
            Text('Acerca de', style: AppTheme.titleLarge),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'IMPOSTOR',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 5),
              Text('Versión 2.0.0', style: AppTheme.bodySmall),
              const SizedBox(height: 15),
              Text(
                'Un juego social de deducción para 3-8 jugadores.',
                style: AppTheme.bodyMedium,
              ),
              const SizedBox(height: 15),
              Divider(color: AppTheme.dividerColor),
              const SizedBox(height: 10),
              Text(
                'Este juego es una creación original de entretenimiento. '
                'No recopilamos datos personales. '
                'Las temáticas de personajes son solo referencias culturales con fines de entretenimiento. '
                'Todas las marcas mencionadas pertenecen a sus respectivos dueños.',
                style: TextStyle(
                    fontSize: 11, color: AppTheme.textMuted, height: 1.4),
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 15),
              Divider(color: AppTheme.dividerColor),
              const SizedBox(height: 10),
              Text(
                '© 2025 IMPOSTOR Game\nTodos los derechos reservados',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.playClick();
              Navigator.pop(context);
            },
            child: const Text('CERRAR',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final logoSize = (screenHeight * 0.14).clamp(100.0, 130.0);
    final iconSize = (logoSize * 0.5).clamp(50.0, 65.0);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Contenido principal
              Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                      vertical: 20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: screenHeight * 0.02),

                        // Logo animado
                        ScaleTransition(
                          scale: _logoScale,
                          child: Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppColors.danger.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.25),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.person_search_rounded,
                              size: iconSize,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.03),

                        // Título — Anton, auto-fit para evitar overflow
                        SizedBox(
                          width: screenWidth * 0.75,
                          child: AutoFitTitle(
                            'IMPOSTOR',
                            style: AppType.displayXL.copyWith(
                              shadows: [
                                Shadow(
                                  blurRadius: 18.0,
                                  color:
                                      AppColors.danger.withValues(alpha: 0.5),
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.012),

                        // Subtítulo — pill sobrio con tinte danger
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color:
                                AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  AppColors.danger.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '¿Confías en tus amigos?',
                            style: AppType.bodyS.copyWith(
                              color: AppColors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.05),

                        // Botón "Continuar partida" si hay una sesión guardada
                        Builder(
                          builder: (context) {
                            final sesionGuardada =
                                SessionPersistence.tryRestore(
                              context.read<PreferencesService>(),
                            );
                            if (sesionGuardada == null) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.only(
                                  bottom: screenHeight * 0.018),
                              child: AppButton(
                                text:
                                    'Continuar · ${sesionGuardada.rondasJugadas} rondas',
                                icon: Icons.play_circle_outline_rounded,
                                variant: AppButtonVariant.safe,
                                onPressed: () async {
                                  AudioService.playClick();
                                  await Navigator.push<void>(
                                    context,
                                    FadeScalePageRoute<void>(
                                      page: LobbyScreen(
                                          sesion: sesionGuardada),
                                    ),
                                  );
                                  if (mounted) setState(() {});
                                },
                              ),
                            );
                          },
                        ),

                        // Botón JUGAR AHORA
                        AppButton(
                          text: 'Jugar ahora',
                          icon: Icons.play_arrow_rounded,
                          variant: AppButtonVariant.primary,
                          onPressed: () async {
                            AudioService.playClick();
                            await Navigator.push<void>(
                              context,
                              FadeScalePageRoute<void>(
                                page: const ConfigurarPartidaScreen(),
                              ),
                            );
                            if (mounted) setState(() {});
                          },
                        ),

                        SizedBox(height: screenHeight * 0.025),

                        // Botón reglas — AppCard sober row
                        GestureDetector(
                          onTap: () {
                            AudioService.playClick();
                            Navigator.push(
                              context,
                              SlidePageRoute(page: const ReglasScreen()),
                            );
                          },
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.menu_book_rounded,
                                    color: AppColors.purple, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  '¿CÓMO SE JUEGA?',
                                  style: AppType.titleM.copyWith(
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Feature rows
                        _buildFeatureRow(
                          Icons.people_rounded,
                          '3-8 Jugadores',
                          'Juega con amigos',
                          AppColors.danger,
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureRow(
                          Icons.phone_android_rounded,
                          'Un solo celular',
                          'Pasen el dispositivo',
                          AppColors.safe,
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureRow(
                          Icons.category_rounded,
                          'Múltiples temáticas',
                          'Dragon Ball, Marvel y más',
                          AppColors.accentAlt,
                        ),
                        const SizedBox(height: 10),
                        _buildFeatureRow(
                          Icons.wifi_off_rounded,
                          'Sin internet',
                          'Juega en cualquier lugar',
                          AppColors.purple,
                        ),

                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
                  ),
                ),
              ),

              // Botones superiores: sonido + ajustes
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    // Sonido
                    IconButton(
                      icon: Icon(
                        AudioService.isSoundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: AppTheme.textPrimary,
                        size: 26,
                      ),
                      onPressed: () {
                        setState(() {
                          AudioService.toggleSound();
                        });
                      },
                    ),
                    // Ajustes
                    IconButton(
                      icon: Icon(
                        Icons.tune_rounded,
                        color: AppTheme.textPrimary,
                        size: 26,
                      ),
                      onPressed: _mostrarAjustes,
                    ),
                  ],
                ),
              ),

              // "Acerca de" abajo
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: TextButton.icon(
                    onPressed: _mostrarAcercaDe,
                    icon: Icon(Icons.info_outline_rounded,
                        color: AppTheme.textMuted, size: 16),
                    label: Text(
                      'Acerca de - v2.0.0',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
      IconData icon, String title, String subtitle, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTheme.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
