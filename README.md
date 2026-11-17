# Quran App

Offline-first Arabic Quran application for Android, built with Flutter.

## Requirements
- Flutter SDK (stable)
- Android Studio and Android SDK
- Git

## Run
```bash
flutter doctor
flutter pub get
flutter run
```

## Current milestone
This is Phase 1: application foundation, navigation, theme, and placeholder feature screens.
The Quran text, audio sources, prayer calculations, and adhkar content are intentionally not bundled yet. They must be added from verified sources with appropriate licenses and validation.

## Project structure
- `lib/app`: app setup and routing
- `lib/core`: shared theme and widgets
- `lib/features`: feature modules
- `assets`: local assets and verified content
- `test`: automated tests
