# BrewMates – Flutter-App

Eine Codebasis für **Android, iOS und Windows**. Version 1.0 ist **local-first**:
alle Daten liegen in einer SQLite-Datenbank auf dem Gerät (Drift), es ist kein
Backend und kein Konto nötig. Der Supabase-Sync folgt in v2
(siehe `../docs/03-architektur.md`).

## Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.24 (Dart ≥ 3.5)
- **Windows-Build:** Windows 10/11 mit Visual Studio 2022 („Desktopentwicklung mit C++")
- **Android-Build:** Android Studio bzw. Android SDK (auf jedem OS) — mit **JDK 17** bauen (JDK 21 löst einen jlink-Fehler im Android-Gradle-Plugin 8.1 aus; Android Studio bringt ein passendes JDK mit)
- **iOS-Build:** Xcode (nur macOS)

Die Plattform-Ordner (`android/`, `ios/`, `windows/`) sind bereits im Repository.

## App starten

```bash
cd app
flutter pub get
flutter run -d windows    # auf einem Windows-Rechner
flutter run -d android    # Gerät/Emulator angeschlossen
```

Beim ersten Start wird die Datenbank angelegt und mit der Bier-Datenbank
(31 Biere, 14 Brauereien) sowie drei Demo-Freunden samt aktiver Session
befüllt – die App ist sofort „lebendig".

## Release-Builds

```bash
flutter build apk --release        # Android APK (direkt installierbar)
flutter build appbundle --release  # Android App Bundle (für Google Play)
flutter build windows --release    # Windows-Programm (build/windows/x64/runner/Release)
dart run msix:create               # MSIX-Paket für den Microsoft Store
```

Details und Store-Freigabe: `../docs/07-release-playbook.md`.

## Entwicklung

```bash
dart run build_runner build --delete-conflicting-outputs  # Drift-Codegen
dart run flutter_launcher_icons                           # Icons neu erzeugen
flutter analyze && flutter test
```

## Struktur

```
lib/
├── main.dart            # Einstieg
├── core/                # Theme, Router, Formatierung
├── domain/badges.dart   # Abzeichen-Katalog + Engine
├── data/
│   ├── db/database.dart # Drift-Schema + alle Queries
│   ├── seed.dart        # Bier-Datenbank & Demo-Inhalte
│   └── providers.dart   # Riverpod-Provider + Aktionen
├── widgets/             # Geteilte Widgets (CheckinCard, RatingStars, …)
└── features/            # feed, map, session, checkin, beers, profile, shell
```
