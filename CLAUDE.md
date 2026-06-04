# CLAUDE.md - Impostor Game

## Descripcion del Proyecto
Juego de fiesta multijugador local (3-8 jugadores, un solo dispositivo) donde los jugadores deben identificar al impostor entre ellos. El impostor no conoce el personaje secreto y debe sobrevivir sin ser descubierto.

## Stack Tecnologico
- **Framework:** Flutter (Dart)
- **SDK:** >= 3.1.0 < 4.0.0
- **Base de datos:** SQLite (sqflite)
- **Audio:** audioplayers
- **Animaciones:** animated_text_kit, confetti

## Arquitectura
```
Screens (UI) -> Managers (Logica) -> Repositories (Acceso a datos) -> Database/Services
```
- **Models:** Partida, Jugador, Ronda, ConfiguracionPartida, Tematica, TematicaPersonalizada
- **Managers:** PartidaManager (logica del juego)
- **Repositories:** TematicaRepository, ConfiguracionRepository
- **Services:** AudioService, DatabaseService

## Estructura de Carpetas
```
lib/
  core/          - Enums globales
  data/          - Datos estaticos (tematicas predefinidas)
  database/      - Servicio SQLite
  managers/      - Logica de negocio del juego
  models/        - Modelos de datos
  repositories/  - Capa de acceso a datos
  services/      - Servicios (audio)
  screens/       - Pantallas de la app
  widgets/       - Widgets reutilizables
```

## Flujo del Juego
HomeScreen -> ConfigurarPartida -> ListaTematicas -> ConfigurarJugadores -> RevelarRoles -> Votacion -> ResultadoRonda -> (siguiente ronda o ResultadoFinal)

## Tematicas Predefinidas
Dragon Ball, Marvel, Naruto, One Piece (14 personajes cada una con emojis)

## Comandos Utiles
```bash
flutter run          # Ejecutar la app
flutter build apk    # Generar APK
flutter test         # Ejecutar tests
flutter analyze      # Analizar codigo
```

---

## Estado actual

Modo local cerrado al 100%. Próximo gran feature pendiente: **modo multijugador online por salas** (Firebase Realtime DB + Auth anónimo). Ver historial en este archivo.

## Tareas Completadas

### 🖤 Rediseño "Minimal Bold" (2026-06) — rama `rediseno-minimal-bold`
- [x] Dirección visual **Minimal Bold**: fondo casi negro, tipografía grande, paleta disciplinada (tinta + blanco + rojo `#E0223E` peligro/impostor + verde menta `#22C55E` seguro/civil/victoria + oro solo para el #1)
- [x] Tipografía **Anton** (títulos) + **Inter** (cuerpo), incrustadas como assets (offline) en `assets/fonts/`
- [x] **Solo modo oscuro**: eliminado `theme_notifier.dart`, el toggle y el `lightTheme` roto (un solo `AppTheme.darkTheme`)
- [x] Sistema de diseño nuevo: `core/app_colors.dart`, `core/app_typography.dart`, `widgets/auto_fit_title.dart` (anti-desborde), `widgets/app_button.dart` (variantes + háptica), `widgets/app_components.dart` (AppScaffold/AppChip/AppSheet). `app_theme.dart` reconstruido preservando su API legacy
- [x] **Revelación de rol discreta anti-spoiler por defecto**: impostor y civil con el mismo fondo oscuro (el resplandor no delata el rol a oscuras). Modo "Pantalla a todo color" opcional en Ajustes (`prefs.colorfulReveal`)
- [x] Las 11 pantallas re-skineadas con el nuevo lenguaje visual
- [x] **Fix:** "Jugar ahora" ya no borra la sesión guardada antes de empezar → regresar a media configuración no pierde la partida (test en `test/home_session_test.dart`)
- [x] **Fix:** `PopScope` con confirmación en Lobby y Votación (atrás físico ya no descarta la sesión/ronda sin avisar)
- [x] **Fix:** títulos grandes con auto-escalado (`AutoFitTitle`) → no se desbordan en celulares chicos
- [x] Spec: `docs/superpowers/specs/2026-06-02-...-design.md` · Plan: `docs/superpowers/plans/2026-06-02-rediseno-impostor-minimal-bold.md`

### 🎨 Rediseño Visual Completo
- [x] Identidad visual con paleta vibrante, tipografía y iconografía consistentes (`lib/core/app_theme.dart`)
- [x] HomeScreen con logo animado, fondo dinámico y botones con efectos
- [x] ConfigurarPartida, ListaTematicas y ConfigurarJugadores con cards y gradientes
- [x] RevelarRoles con flip de carta, glow por rol y partículas confetti
- [x] Votacion con countdown visual y fase de votación clara
- [x] ResultadoRonda y ResultadoFinal con confetti y celebraciones
- [x] Sistema de diseño consistente (AppCard, PrimaryButton, AppHeader, GradientBackground)
- [x] Modo oscuro / claro con toggle (`lib/core/theme_notifier.dart` + `services/preferences_service.dart`)

### ✨ Animaciones y Experiencia
- [x] Transiciones entre pantallas (SlidePageRoute, FadeScalePageRoute)
- [x] Flip de carta + glow rojo (impostor) / turquesa (civil) + anillo de pulso + burst de confetti según rol
- [x] Micro-animaciones en botones (ScaleTransition) y cards (AnimatedContainer)
- [x] Countdown de votación animado en tiempo real

### 📖 Pantalla de Reglas
- [x] ReglasScreen con PageView de 6 páginas (`lib/screens/reglas_screen.dart`)
- [x] Onboarding opcional la primera vez (`preferences_service.dart` flag `onboardingDone`)
- [x] Acceso desde HomeScreen, Lobby (durante la sesión) y Votación

### 🎭 Temáticas Personalizadas
- [x] Modelo `TematicaPersonalizada` con UUID, nombre, personajes, fechaCreacion
- [x] Crear / Editar / Eliminar (TematicaRepository)
- [x] Mostrar custom junto a predefinidas con badge "Custom"
- [x] Validaciones de min/max personajes con barra de progreso visual

### 📱 Pasa el Teléfono
- [x] Pantalla intermedia entre cada revelación con nombre y contador
- [x] Animación scale + fade elasticOut
- [x] Botón "Estoy listo" y advertencia visual
- [x] Toggle en Ajustes (HomeScreen) para saltarse la pantalla

### 👥 Historial de Jugadores
- [x] Guardar nombres en SQLite con UPSERT transaccional + índices
- [x] Modal de "nombres recientes" tappable
- [x] Eliminar nombres del historial
- [x] Autocompletar dinámico con debounce mientras se escribe (panel inline bajo el TextField)

### 🔄 Rondas y Gestión de Partida
- [x] LobbyScreen persistente entre rondas (no envía a HomeScreen)
- [x] Persistencia de sesión activa (SharedPreferences + debounce 250ms)
- [x] Botón "Continuar" en HomeScreen si hay sesión guardada
- [x] Cambiar temática entre rondas
- [x] Agregar / quitar / editar jugadores entre rondas
- [x] Cambiar número de impostores entre rondas (selector en lobby) + soporte multi-impostor real
- [x] Resumen / historial de rondas jugadas en la sesión
- [x] Scoreboard por sesión con puntos por jugador
- [x] Retorno automático al lobby tras ResultadoRonda con countdown cancelable

### ⚙️ Optimización General
- [x] Provider + ChangeNotifier para SesionJuego y PartidaManager
- [x] `const` extensivo en widgets repetidos
- [x] Índices SQLite en `tematicas.nombre`, `historial_jugadores`, `partidas.fecha`
- [x] Manejo de errores con try/catch + debugPrint en todos los repositories
- [x] Responsive con MediaQuery / clamp en HomeScreen y screens críticas
- [x] Optimizacion del timer de votación: `ValueNotifier<int>` + `ValueListenableBuilder` para evitar rebuilds del Scaffold completo cada segundo

## Tareas Pendientes (próximas fases)

### 🌐 Modo Multijugador Online (siguiente gran feature)
- [ ] Modo "Sala Online" con código de 6 letras donde cada jugador usa su propio celular conectándose por internet
- [ ] Cada jugador ve solo su rol en su pantalla (sin pasa-teléfono)
- [ ] Backend: Firebase Realtime Database (plan gratuito Spark) + Firebase Anonymous Auth
- [ ] Capa de abstracción `PartidaSource` con `LocalPartidaSource` (modo actual) y `OnlinePartidaSource` (Firebase)
- [ ] Host-authoritative con reglas de seguridad RTDB
- [ ] Sincronización de fases vía `meta.estado` con `StreamBuilder` raíz por screen
- [ ] Plan completo en `~/.claude/plans/snoopy-popping-adleman.md`

### 🎁 Nice to have
- [ ] Importar / exportar temáticas personalizadas (share_plus + JSON)
- [ ] Conectar assets reales de audio (click, reveal, impostor, victory)
