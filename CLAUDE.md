# CLAUDE.md - Impostor Game

## Descripcion del Proyecto
Juego de fiesta (3-8 jugadores) en dos modos: **local** (un solo dispositivo, pasa-teléfono) y **Sala Online** (cada jugador en su celular, por código). Los jugadores los jugadores deben identificar al impostor entre ellos. El impostor no conoce el personaje secreto y debe sobrevivir sin ser descubierto.

## Stack Tecnologico
- **Framework:** Flutter (Dart)
- **SDK:** >= 3.1.0 < 4.0.0
- **Base de datos:** SQLite (sqflite)
- **Audio:** audioplayers
- **Animaciones:** animated_text_kit, confetti
- **Online:** Firebase Realtime Database + Firebase Auth anónima (plan Spark)

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
Local: HomeScreen -> ConfigurarPartida -> ListaTematicas -> ConfigurarJugadores -> RevelarRoles -> Votacion -> ResultadoRonda -> (siguiente ronda o ResultadoFinal)

Online: HomeScreen -> CrearSala / UnirseSala -> LobbyOnlineScreen. El lobby es un router: escucha `salas/{codigo}/meta/estado` y pinta la vista de cada fase (lobby, revelando, discusion, votando, resultado, finalizada, abandonada).

## Modo Sala Online (cómo funciona)
- **Host-authoritative:** el host corre el `PartidaManager` de siempre en su celular y publica el estado en RTDB (`RondaOnlineSync`). Los invitados solo leen y votan.
- **Anti-trampa:** el rol de cada jugador vive en `salas/{codigo}/privado/{uid}` y las reglas (`database.rules.json`) solo dejan leer el propio. Los votos solo los lee el host.
- **Seam `SalaGateway`:** `FirebaseSalaGateway` (real) y `test/online/fake_sala_gateway.dart` (en memoria) → la lógica de salas se testea sin Firebase.
- **Código:** `lib/managers/{sala_online_manager,ronda_online_sync,sala_codigo,sala_predicados}.dart`, pantallas en `lib/screens/online/`.
- **Presencia:** `onDisconnect` marca `conectado: false`; si el que se va es el host, además `meta.estado = abandonada` y todos ven "El anfitrión salió de la sala".
- **Reconexión (solo invitados):** el código de la sala se guarda en `PreferencesService.salaActivaCodigo`; Home muestra "Volver a la sala XXXXXX" y `SalaOnlineManager.reconectar()` lo devuelve a la fase actual con su rol (si ya votó, no se le vuelve a pedir). Unirse con el mismo código también reconecta. El host no puede retomar: su partida vive en memoria, así que si se va la sala termina.
- **Config Firebase:** `android/app/google-services.json` NO está en el repo (gitignored). Para regenerarlo: Firebase Console → proyecto `impostor-game-b3f9c` → Configuración del proyecto → app Android `com.dreamers.impostorgame` → descargar `google-services.json` a `android/app/`. La URL de la RTDB está fija en `FirebaseService`. Las reglas se publican pegando `database.rules.json` en Realtime Database → Rules.
- **Sin Firebase** (sin json, sin red o auth anónima apagada) la app arranca igual en modo local y los botones online avisan que no está disponible.
- Spec: `docs/superpowers/specs/2026-06-03-modo-sala-online-design.md` · Plan: `docs/superpowers/plans/2026-06-03-modo-sala-online.md`

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

Modo local y **modo Sala Online** terminados. Pendiente solo lo de "Nice to have".

## Tareas Completadas

### 🌐 Modo Sala Online (2026-06 → 2026-09) — rama `modo-sala-online`
- [x] Sala con código de 6 caracteres; cada jugador usa su propio celular (sin pasa-teléfono)
- [x] Firebase RTDB + Auth anónima, host-authoritative reusando `PartidaManager` (`crearPartida` acepta UIDs como ids)
- [x] `Partida.fromJson` / `Ronda.fromJson` para serializar hacia/desde RTDB
- [x] Lobby en vivo con "Estoy listo" (el host empieza con ≥3 conectados y todos listos)
- [x] Revelar rol por dispositivo, discusión, votación secreta con auto-cierre cuando todos votan (o el host fuerza), resultado de ronda, resultado final y nueva partida
- [x] Reglas de seguridad RTDB (rol privado por jugador, votos solo para el host, solo el host escribe meta/publico)
- [x] Aviso "El anfitrión salió de la sala" para todos cuando el host se va
- [x] Reconexión de invitados desde Home ("Volver a la sala") o reingresando el mismo código

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

### 🎁 Nice to have
- [ ] Importar / exportar temáticas personalizadas (share_plus + JSON)
- [ ] Conectar assets reales de audio (click, reveal, impostor, victory)
