# BrewMates – Flutter-App

Eine Codebasis für **Android, iOS und Windows** (macOS/Web optional).

## Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.24 (Dart ≥ 3.5)
- Für Windows-Builds: Visual Studio 2022 mit „Desktopentwicklung mit C++"
- Für Android: Android Studio / SDK · Für iOS: Xcode (nur macOS)

## Erste Schritte

Die Plattform-Shells (`android/`, `ios/`, `windows/`) sind generierter Code und
liegen nicht im Repository. Einmalig erzeugen:

```bash
cd app
flutter create --platforms=android,ios,windows --org de.brewmates .
flutter pub get
```

Supabase-Zugangsdaten konfigurieren (siehe `../supabase/README.md`), dann per
`--dart-define` starten:

```bash
flutter run --dart-define=SUPABASE_URL=https://<projekt>.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

Ohne Zugangsdaten startet die App im **Offline-Demo-Modus** (Platzhalterdaten) –
praktisch für UI-Arbeit.

## Struktur

```
lib/
├── main.dart          # Einstieg, Supabase-Init
├── core/              # Theme, Router, Konfiguration
├── domain/            # Modelle (Beer, CheckIn, Session, …)
├── data/              # Repositories (Supabase + Drift folgen hier)
└── features/          # Ein Ordner pro Feature (feed, map, session, …)
    └── shell/         # Adaptive Navigation (Tab-Bar mobil, Rail auf Desktop)
```

## Tests & Lint

```bash
flutter analyze
flutter test
```
