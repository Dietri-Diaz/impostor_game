# IMPOSTOR Game

Juego social de deducción tipo "Among Us" para 3-20 jugadores en un solo dispositivo. Construido en Flutter con persistencia local en SQLite.

## Stack

- **Framework**: Flutter 3.1+ / Dart
- **State management**: `provider` + `ChangeNotifier`
- **Persistencia**: `sqflite` (SQLite) + `shared_preferences`
- **Animaciones**: `animated_text_kit`, `confetti`, animaciones nativas de Flutter
- **Audio**: `audioplayers`

## Features

- 14 temáticas predefinidas con imágenes de personajes (Dragon Ball, Marvel, Naruto, One Piece, Pokémon, Super Mario, Disney, Stranger Things, Harry Potter, DC, Demon Slayer, Attack on Titan, The Office, Breaking Bad)
- Temáticas personalizadas con CRUD completo
- Soporte para **multi-impostor** (configurable entre rondas)
- Historial de jugadores con autocompletar dinámico desde SQLite
- Persistencia de sesión activa — si cerrás la app a mitad de sesión, podés continuar después
- Modo claro / modo oscuro con toggle
- Animaciones: flip de carta, partículas confetti según rol, micro-animaciones en botones
- Pantalla "pasa el teléfono" con opción de saltarse en ajustes
- Reglas accesibles desde HomeScreen y durante la partida
- Scoreboard por sesión con puntos acumulados

## Arquitectura

```
Screens (UI)
    ↓
Managers (Lógica de negocio) → ChangeNotifier
    ↓
Repositories (Acceso a datos)
    ↓
Database (SQLite) / Services (Audio, Persistencia)
```

```
lib/
├── core/          # Enums, constantes, validators, AppTheme
├── data/          # Datos estáticos (temáticas predefinidas)
├── database/      # Servicio SQLite
├── managers/      # PartidaManager (lógica del juego)
├── models/        # Partida, Jugador, Ronda, Tematica, etc.
├── repositories/  # Capa de acceso a datos
├── services/      # Audio, persistencia de sesión, preferencias
├── screens/       # 12 pantallas del flujo
└── widgets/       # Widgets reutilizables
```

## Cómo correr

Requiere Flutter SDK 3.1+ y un emulador Android (API 33+) o dispositivo físico.

```bash
flutter pub get
flutter run                # debug con hot reload
flutter run --release      # release optimizado
flutter build apk --release  # generar APK
```

Hay un script `play.ps1` (PowerShell) que arranca el emulador y lanza la app:

```bash
.\play.ps1              # debug
.\play.ps1 -Release     # release
```

## Aviso legal

Esta app es un proyecto personal de aprendizaje y entretenimiento. Las imágenes y nombres de personajes pertenecen a sus respectivos dueños (Toei Animation, Marvel, Disney, Shueisha, Nintendo, Netflix, Warner Bros., AMC, etc.) y se usan únicamente bajo el concepto de uso nominativo con fines no comerciales.

## Autor

Dietri Diaz
