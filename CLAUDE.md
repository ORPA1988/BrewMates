# CLAUDE.md — Arbeitsanleitung für Claude-Sessions

BrewMates: Android-Bier-App (Untappd × Beer with Me), Flutter, deutschsprachig,
Fokus Österreich + Bayern. Antworte dem Nutzer auf Deutsch.

## Aktueller Stand (2026-08-13)

- **Branch**: PR #2 (`claude/multi-platform-app-design-7lm758`) ist in
  `main` gemerged; neue Arbeit startet auf frischen Branches von `main`.
  Version `0.9.5-beta+9`, Release v0.9.5-beta veröffentlicht (Beta 0.x bis
  zum Play-Store-1.0; Android-`versionCode` zählt immer weiter hoch).
- **Backend**: Supabase-Projekt `swlqkwlpnxwthbneblww` (EU). Migrationen
  `supabase/migrations/0001–0008` sind LIVE. Google-Login und
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

- Community-DB: `app/assets/data/` — vier Dateien (`beers-at/by`,
  `breweries-at/by`), verknüpft über `brewery_id`; Bild-URLs nur als Links
  auf Open Food Facts (CC-BY-SA), Herkunft/Lizenz in `DATENHERKUNFT.md`.
- Karten-Wording zentral: `activeUsersLabel()` in
  `app/lib/features/map/map_screen.dart`.
- Nicht-Freunde erscheinen auf der Karte NIE mit Position, nur als Zähler.
- orpa-tech.at ist bewusst KEIN Bestandteil des Projekts.
