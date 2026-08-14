# CLAUDE.md — Arbeitsanleitung für Claude-Sessions

BrewMates: Android-Bier-App (Untappd × Beer with Me), Flutter, deutschsprachig,
Fokus DACH-Raum (Herz: Österreich + Bayern). Antworte dem Nutzer auf Deutsch.

## Aktueller Stand (2026-08-14)

- **Branch**: PRs #2–#4 sind in `main` gemerged; neue Arbeit startet auf
  frischen Branches von `main`.
  Version `0.9.13-beta+17` (Beta 0.x bis
  zum Play-Store-1.0; Android-`versionCode` zählt immer weiter hoch; die
  frühen Alpha-Releases wurden von 1.1/1.2 auf 0.1.0/0.2.0 umbenannt).
  Versions-Bump = IMMER beide Stellen: `app/pubspec.yaml` UND
  `AppConfig.appVersion` in `core/config.dart` (Test erzwingt Gleichstand).
- **Backend**: Supabase-Projekt `swlqkwlpnxwthbneblww` (EU). Migrationen
  `supabase/migrations/0001–0018` sind LIVE (0011 Gasthäuser, 0012
  Challenges, 0013 Vertrauensstufen + edit_log, 0014 complete_challenge-RPC
  + contribution_leaderboard, 0015 venues.opening_hours_json, 0016
  user_badges/wishlist_items für den Cloud-Sync, 0017
  delete_my_account-RPC, 0018 profiles.thirsty_until „Bierlaune").
  Google-Login und
  E-Mail-Anmeldung (ohne Bestätigungspflicht) sind eingerichtet und
  funktionieren. Seit 0008 gilt: EXECUTE auf Funktionen wird von PUBLIC
  entzogen und pro Funktion gezielt gewährt — neue Funktionen brauchen in
  ihrer Migration ein explizites `grant execute … to authenticated`
  (bzw. die jeweils passende Rolle).
- **Security-Advisor-Baseline** (bekannt, bewusst offen): PostGIS im
  public-Schema inkl. `st_estimatedextent`/`spatial_ref_sys`,
  Leaked-Password-Protection deaktiviert, authenticated-Grants auf
  RLS-Helfern (`are_friends`, `is_admin`, `is_crew_member`,
  `count_other_active_sessions`) sind Absicht.

## Toolchain (Cloud-Session, frische Container)

- Flutter **3.24.5** nach Scratchpad laden und nutzen; `flutter analyze` und
  `flutter test` laufen ohne Android-SDK.
- Android-Release-Build braucht: Android SDK (cmdline-tools) + **JDK 17**
  (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`; JDK 21 bricht mit
  AGP 8.1/jlink). `app/android/build.gradle` enthält bewusst eine
  `ext.flutter`-Map + AGP-8.1-Classpath — nicht „aufräumen".
- Gepinnte Pakete (Flutter-3.24-Toolchain): `mobile_scanner ^5.2.3`,
  `geolocator ^13.0.2` — nicht ohne Toolchain-Upgrade anheben.
- `flutter test` NIE nach `tail` pipen (scheint zu hängen) — in Datei
  umleiten und die Datei lesen.

## Releases

GitHub-Release = Workflow `release.yml` per **workflow_dispatch** auf dem
Branch triggern (Input `version`, z. B. `v0.9.5-beta`); Tag-Push scheitert
mit 403 (Branch-Scope-Token). Der Lauf baut APK+AAB und veröffentlicht sie.

## Daten & Konventionen

- Community-DB: `app/assets/data/` — acht Dateien (`beers-at/by/de/ch`,
  `breweries-at/by/de/ch`; DACH seit 0.9.13, Bayern-IDs `de-by-…`,
  Restdeutschland `de-…`, Schweiz `ch-…`), verknüpft über `brewery_id`;
  Bild-URLs nur als Links auf Open Food Facts (CC-BY-SA), Herkunft/Lizenz
  in `DATENHERKUNFT.md`.
- Karten-Wording zentral: `activeUsersLabel()` in
  `app/lib/features/map/map_screen.dart`.
- Nicht-Freunde erscheinen auf der Karte NIE mit Position, nur als Zähler.
- **Sync-Invariante**: Community-JSON-Datensätze (Biere mit
  `isUserSubmitted == false`, Brauereien mit Nicht-UUID-ID) sind in der App
  READ-ONLY — der GitHub-Sync überschreibt sie wholesale. In-App-Bearbeitung
  gibt es nur für nutzererstellte Zeilen (UUIDs) und Gasthäuser (Supabase).
  Korrekturen an Community-Daten laufen über „Korrektur vorschlagen"
  (GitHub-Issue-Prefill, `core/external_links.dart`).
- **Vertrauensstufen** (0013): 1 Neuling · 2 Stammgast (≥25 P.) ·
  3 Bierkenner (≥100 P.) · 4 Moderator · 5 Admin; Overrides über
  user_features (`trust_level_2/3`, `edit_lock`). RLS erzwingt, die UI
  spiegelt (`accountLevelProvider`).
- **Persistenz**: Release-CI signiert mit dem Upload-Keystore aus den
  GitHub-Secrets `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD` (ohne Secrets:
  Debug-Fallback mit Warnung) — stabile Signatur = Updates ohne
  Datenverlust. Cloud-Restore (`data/restore.dart`,
  `cloudRestoreProvider`) holt nach Anmeldung eigene Check-ins, Erfolge
  und Wunschliste zurück (Union, idempotent); Badge-Vergabe und
  Wunschlisten-Toggle spiegeln best-effort zum Server. Seit Drift v9:
  Foto-Check-ins (beer-photos-Bucket, `checkins.photo_url`); Toasts und
  Kommentare laufen für hochgeladene Check-ins über den Server
  (`feedReactionsProvider`). Kontolöschung in-app (0017,
  Play-Store-Pflicht).
- Challenge-Abschlüsse werden seit 0014 SERVERSEITIG validiert
  (`complete_challenge`-RPC; direkte Inserts gesperrt). Gasthaus-Pflege
  funktioniert seit Drift v8 auch offline: `venue_edit_queue` +
  `replayVenueQueue` (FIFO, Last-write-wins; Replay am Anfang von
  `VenueSync.sync()`; Neuanlagen bekommen bis zum Upload eine
  `local-…`-Pseudo-ID im Cache).
- **Web-App**: Seit 0.9.10 baut die App auch fürs Web
  (`https://orpa1988.github.io/BrewMates/`, Datenschutz unter
  `…/privacy/`; kombiniertes Pages-Deployment in `pages.yml`). Drift läuft
  im Browser über `WasmDatabase` — die Plattform-Weiche liegt in
  `data/db/connection/` (Conditional Imports; nativer Pfad byte-identisch).
  `web/sqlite3.wasm` (sqlite3 2.9.4), `web/drift_worker.js`
  (drift 2.23.1) und `web/zxing.js` (@zxing/library 0.19.1, muss zur
  scriptUrl in mobile_scanner passen; Override in `scan_screen.initState`)
  sind versionsgepinnt — bei Paket-Upgrades neu laden!
  CanvasKit wird selbst gehostet (`web/flutter_bootstrap.js`).
  KEIN `dart:io` in `app/lib/` (CI erzwingt `flutter build web`);
  Plattform-Checks über `kIsWeb`/`defaultTargetPlatform` — in Widget-Tests
  meldet `defaultTargetPlatform` Android, Desktop-Tests setzen
  `debugDefaultTargetPlatformOverride`.
- orpa-tech.at ist bewusst KEIN Bestandteil des Projekts.
