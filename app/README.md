# BrewMates – Flutter-App

Eine Codebasis für **Android, Web, iOS und Windows**. Im Einsatz sind
Android und Web; Web ist Zweitgerät mit vollem Funktionsumfang, kein
Entwickler-Target.

Die App ist **local-first**: Alle Daten liegen in einer SQLite-Datenbank auf
dem Gerät (Drift), Einchecken und Tagebuch funktionieren ohne Netz. Der
**Supabase-Sync ist seit der Online-Beta 0.9.2 live** — Konto, Freunde,
Beacons und Wiederherstellung laufen darüber
(siehe `../docs/03-architektur.md`).

## Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.24 (Dart ≥ 3.5)
- **Windows-Build:** Windows 10/11 mit Visual Studio 2022 („Desktopentwicklung mit C++")
- **Android-Build:** Android Studio bzw. Android SDK (auf jedem OS) — mit **JDK 17** bauen (JDK 21 löst einen jlink-Fehler im Android-Gradle-Plugin 8.1 aus; Android Studio bringt ein passendes JDK mit)
- **iOS-Build:** Xcode (nur macOS)
- **Web-Build:** nichts zusätzlich — `flutter build web` läuft überall

Die Plattform-Ordner (`android/`, `ios/`, `windows/`) sind bereits im Repository.

## App starten

```bash
cd app
flutter pub get
flutter run -d windows    # auf einem Windows-Rechner
flutter run -d android    # Gerät/Emulator angeschlossen
flutter run -d chrome     # Web
```

Beim ersten Start legt `seed.dart` **nur das eigene Profil** an. Die Biere
kommen aus der gebündelten Community-Datenbank unter `assets/data/`
(660 Biere, 137 Brauereien). Demo-Freunde gab es bis Schema v4; sie sind
entfernt, seit die Beta mit echten Nutzern läuft.

## Release-Builds

```bash
flutter build apk --release        # Android APK (direkt installierbar)
flutter build appbundle --release  # Android App Bundle (für Google Play)
flutter build windows --release    # Windows-Programm (build/windows/x64/runner/Release)
flutter build web --base-href /BrewMates/   # Web (in Git Bash: MSYS_NO_PATHCONV=1 davor)
dart run msix:create               # MSIX-Paket für den Microsoft Store
```

Der **Android-Release-Build gehört in die CI** („Release" → „Run workflow"):
Nur dort liegt der Upload-Keystore, und nur eine stabile Signatur erlaubt
Updates über eine bestehende Installation.

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
├── domain/              # Regeln ohne Flutter und ohne Datenbank
│                        # (badges, challenges, statistics, streak, …)
├── data/
│   ├── db/database.dart # Drift-Schema + alle Queries
│   ├── online/          # Supabase-Zugriff, je Bereich eine API-Datei
│   ├── providers/       # Riverpod-Provider, je Thema eine Datei
│   ├── seed.dart        # legt beim ersten Start nur das eigene Profil an
│   └── *_queue.dart     # Offline-Warteschlangen (FIFO, idempotent)
├── widgets/             # Geteilte Widgets (CheckinCard, RatingStars, …)
└── features/            # 19 Bereiche: feed, map, session, checkin, beers,
                         # discover, crews, stats, rueckblick, profile, …
```
