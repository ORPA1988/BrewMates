# CLAUDE.md — Arbeitsanleitung für Claude-Sessions

BrewMates: Android-Bier-App (Untappd × Beer with Me), Flutter, deutschsprachig,
Fokus DACH-Raum (Herz: Österreich + Bayern). Antworte dem Nutzer auf Deutsch.

## Aktueller Stand (2026-08-15)

- **Branch**: PRs #2–#4 sind in `main` gemerged; neue Arbeit startet auf
  frischen Branches von `main`.
  Version `0.10.5-beta+23` (Beta 0.x bis
  zum Play-Store-1.0; Android-`versionCode` zählt immer weiter hoch; die
  frühen Alpha-Releases wurden von 1.1/1.2 auf 0.1.0/0.2.0 umbenannt).
  Versions-Bump = IMMER beide Stellen: `app/pubspec.yaml` UND
  `AppConfig.appVersion` in `core/config.dart` (Test erzwingt Gleichstand).
- **Backend**: Supabase-Projekt `swlqkwlpnxwthbneblww` (EU).
  **`0001–0035` sind LIVE, lückenlos** (Stand 2026-09-02) — `0020–0024` am 2026-08-15 eingespielt und
  gegengeprüft (Spalten, Constraints, Enum, Index, vier neue Funktionen,
  Policy; `friendships` unverändert alle auf `freund`, also keine
  Sichtbarkeitsänderung am Rollout-Tag). Kein Schema-Drift.
  `0025` (Tabellenrechte) ist **jederzeit einspielbar** und ändert live
  nichts — es schreibt fest, was dort ohnehin gilt. Ohne diese Migration
  ließ sich das Projekt aus dem Repo **nicht wiederherstellen**: Die
  DML-Rechte für `anon`/`authenticated` stammten aus Supabase-Default-
  Privileges und standen in keiner Migration. Aufgefallen beim ersten
  echten From-scratch-Aufbau für die RLS-Tests.
  `0026` (`thirsty_until` aus den lesbaren Spalten von `profiles`) ist
  **eingespielt** — am 2026-08-15, zusammen mit dem Rest. Gelesen wird
  seither über `my_thirsty_until()`, geschrieben weiterhin direkt
  (`0026` fasst nur `select` an, nie `update`).
  ⚠️ **Hier stand bis 2026-08-16 das Gegenteil** — „bewusst NICHT
  eingespielt und wartet". Der Rechtestand widersprach dem seit dem
  ersten Tag: Tabellenrecht entzogen, `thirsty_until` nicht gewährt, 22
  Einzelspalten gewährt. Aufgefallen erst, als der Rollout anstand.
  **Die Lehre:** Eine Datei, die einen Sicherheitsvorbehalt behauptet,
  ist kein Beleg für ihn. Wer plant, ob eine Migration laufen darf,
  fragt die Datenbank — `information_schema.table_privileges` und
  `column_privileges` —, nicht diesen Absatz. Ein Vorbehalt, den man
  für aktiv hält, obwohl er längst gefallen ist, ist gefährlicher als
  gar keiner: Man baut die nächste Entscheidung darauf.
  **Riegel scharf**: `app_config.min_supported_version` steht auf
  `0.10.4` (2026-09-02; vom Menschen gesetzt, siehe unten). ⚠️ Das Anheben auf
  0.10.3 wurde vom Auto-Modus-Klassifizierer zweimal blockiert — es ist
  eine Aussperr-Entscheidung und gehört dem Menschen; der Einzeiler steht
  in `docs/07-release-playbook.md`. Das sperrt heute
  **niemanden** aus — der Riegel existiert erst ab 0.10.2, alles
  darunter fragt ihn nie. Sein Wert liegt in der Zukunft.
  `beers.barcode` ist **weg** (0032). Für Barcodes gibt es am Server nur
  noch eine Wahrheit: `beer_barcodes`.
  **Zwei Lehren, beide teuer erkauft:**
  (1) Eine Migration, die ein Recht entzieht, gehört nie in dieselbe Datei
  wie die Ersatzschnittstelle — sonst gibt es kein Zeitfenster, in dem
  alter und neuer Client zugleich funktionieren.
  (2) `revoke select (spalte)` ist **wirkungslos**, solange ein Recht auf
  Tabellenebene besteht. Postgres meldet „REVOKE" und lässt die Spalte
  lesbar. Wer eine Spalte verbergen will, entzieht das Tabellenrecht und
  gewährt alle übrigen Spalten einzeln — mit der Folge, dass jede neue
  Spalte auf `profiles` ihr `grant select (…)` mitbringen muss.
  Frühere Migrationen (0011 Gasthäuser, 0012
  Challenges, 0013 Vertrauensstufen + edit_log, 0014 complete_challenge-RPC
  + contribution_leaderboard, 0015 venues.opening_hours_json, 0016
  user_badges/wishlist_items für den Cloud-Sync, 0017
  delete_my_account-RPC, 0018 profiles.thirsty_until „Bierlaune", 0019
  sprechende Nutzernamen aus full_name/E-Mail statt mate_<hex>; die
  Freundessuche matcht seit 0.9.13 auch display_name; 0020
  checkins_created_idx, 0021 sessions_duration_bounds 29 min–24 h, 0022
  checkins.volume_ml, 0023 story auf beers/breweries, 0024 Freundeskreise
  `friend_tier` + tier_for/set_friend_tier/my_thirsty_until/
  thirsty_friends + neue sessions_select-Policy, 0025 Tabellenrechte,
  0027 pg_trgm-Indizes für die Freundessuche, 0028 beer_barcodes:
  mehrere EANs je Bier mit Gebindegröße, 0029 app_config mit
  `min_supported_version` — Riegel „Update erforderlich"; 0030
  Barcode-Suche über `beer_barcodes` statt `beers.barcode`, inkl.
  Backfill — 0028 hatte die Tabelle angelegt, aber die Lesestelle nie
  umgestellt, sodass nachgetragene Codes gespeichert und beim Suchen
  ignoriert wurden; 0031 Benachrichtigungen per Trigger auf `friendships`
  + `notifications` in Realtime — **live seit 2026-08-16**, Trigger,
  Publikation und Delete-Policy gegengeprüft, Advisor ohne Neubefund
  (`friendships_notify` ist SECURITY DEFINER, aber EXECUTE ist allen
  entzogen — sie hängt nur am Trigger); 0032 `beers.barcode`
  `beers.barcode` entfernt — **live seit 2026-09-02**, nachdem der Riegel
  auf 0.10.4 stand und das Gerät des einzigen Nutzers 0.10.4 meldete;
  Backfill 6/6, `flag_beer_by_barcode` nur noch über `beer_barcodes`).
  Google-Login und
  E-Mail-Anmeldung (ohne Bestätigungspflicht) sind eingerichtet und
  funktionieren. Seit 0008 gilt: EXECUTE auf Funktionen wird von PUBLIC
  entzogen und pro Funktion gezielt gewährt — neue Funktionen brauchen in
  ihrer Migration ein explizites `grant execute … to authenticated`
  (bzw. die jeweils passende Rolle).
- **Security-Check 2026-09-02** (0035 `security_hardening_2`): `anon` hat
  auf keiner eigenen Tabelle mehr INSERT/UPDATE/DELETE (auch nicht auf
  künftigen — Default-Privileges angepasst); Bucket `beer-photos` auf
  5 MB und Bildtypen begrenzt, eigene Fotos löschbar; `app_config`
  mit je einer Policy pro Befehl. Repo: Secret-Scanning + Push-Schutz
  aktiv, Dependabot-Alerts/-Updates eingeschaltet (0 offen), **`main`
  ohne Branch-Schutz** (Entscheidung des Menschen). Keine Geheimnisse
  im Repo (geprüft: Schlüssel, service_role, .jks, .env, Dienstkonto).
  **Nicht behebbar** (live verifiziert, REVOKE als `postgres` ohne
  Wirkung): alles, was PostGIS/`supabase_admin` gehört —
  `spatial_ref_sys` ohne RLS, `st_estimatedextent` SECURITY DEFINER für
  anon, 9 anon-Schreibrechte auf `spatial_ref_sys`/`geometry_columns`/
  `geography_columns`. Öffentliche Referenzdaten, keine Nutzerdaten.
  Dashboard-seitig offen: Leaked-Password-Protection (Auth → Providers
  → Email), E-Mail-Bestätigung bewusst aus.
- **Security-Advisor-Baseline** (bekannt, bewusst offen; zuletzt geprüft
  2026-08-15 nach dem Rollout von 0020–0024, keine echten Neubefunde —
  die vier neuen RPCs schränken ihre Argumente selbst ein: `tier_for`
  erbt die Härtung von `are_friends`, `set_friend_tier` schreibt nur
  Zeilen mit eigener Beteiligung, `my_thirsty_until` nur das eigene
  Konto, `thirsty_friends` filtert serverseitig auf Kreis „Freund"):
  PostGIS im public-Schema inkl.
  `st_estimatedextent`/`spatial_ref_sys`, Leaked-Password-Protection
  deaktiviert. Dazu meldet der Linter (0028/0029) **jede** SECURITY-
  DEFINER-Funktion, die `authenticated` aufrufen darf — das sind
  sämtliche RPCs der App (`account_level`, `are_friends`,
  `beer_rating_stats`, `complete_challenge`, `contribution_leaderboard`,
  `count_other_active_sessions`, `delete_my_account`,
  `flag_beer_by_barcode`, `has_blocked`, `is_admin`, `is_blocked`,
  `is_crew_member`, `my_account_level_info`) und ist Absicht: Sie sind
  der Zugriffsweg, nicht das Leck. Geprüft wurde, dass sie ihre Argumente
  selbst einschränken — `are_friends`/`has_blocked` beantworten nur Paare,
  an denen der Aufrufer beteiligt ist, `account_level` nur das eigene
  Konto oder das eines Admins. **Neu hinzukommende Funktionen sind an
  diesem Maßstab zu prüfen, nicht pauschal der Baseline zuzuschlagen.**

## Toolchain (Cloud-Session, frische Container)

- Flutter **3.24.5** nach Scratchpad laden und nutzen; `flutter analyze` und
  `flutter test` laufen ohne Android-SDK.
- Android-Release-Build braucht: Android SDK (cmdline-tools) + **JDK 17**
  (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`; JDK 21 bricht mit
  AGP 8.1/jlink). `app/android/build.gradle` enthält bewusst eine
  `ext.flutter`-Map + AGP-8.1-Classpath — nicht „aufräumen".
- **Push/Firebase** (0.10.4): `firebase_core ^4.7`, `firebase_messaging
  ^16.2`, `minSdk` 23, `google-services.json` liegt bewusst im Repo
  (`app/android/app/`), der Dienstkonto-Schlüssel NIE. Lokale
  `flutter build apk` scheitern auf OneDrive oft an Dateisperren
  (`Unable to delete directory`) — kein Codefehler; verbindlich ist
  der Release-Build in der CI.
- Gepinnte Pakete (Flutter-3.24-Toolchain): `mobile_scanner ^5.2.3`,
  `geolocator ^13.0.2` — nicht ohne Toolchain-Upgrade anheben.
  `qr_flutter ^4.1.0` (reines Dart) kam mit den Freundes-QR-Codes dazu.
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
- **Pflicht bei JEDER Funktionsänderung**: Jede Funktion hat ein Dokument
  unter `docs/features/` (Vorlage: `_vorlage.md`, Index: `README.md`) mit
  Zielsetzung, Nutzersicht, technischer Umsetzung, Modularität,
  Plattformen, Skalierung, Status und Plan. Das Dokument wird **im selben
  Commit** mitgezogen — Status, „Zuletzt geprüft"-Datum und die
  betroffenen Abschnitte. Eine NEUE Funktion beginnt mit ihrem Dokument,
  nicht mit dem ersten Widget. Roadmap (`docs/06-roadmap.md`) verlinkt
  dorthin und sagt nur noch WANN, nicht WAS.
- **Architektur-Leitplanken**: `docs/11-modularitaet-und-portierbarkeit.md`
  — Schichtrichtung `features → domain/data → core`, keine
  Cross-Imports zwischen Features (gilt heute lückenlos), neue Funktionen
  bekommen eigene API- und Provider-Datei statt in die Sammelstellen
  (`online_service.dart` 1705 Z., `providers.dart` 71 Provider,
  `database.dart` 13 Tabellen) hineinzuwachsen. Kein `dart:io` in `lib/`,
  nichts zur Laufzeit von fremden CDNs nachladen.
- **Aktueller Befund** zu Vollständigkeit und Skalierbarkeit aller
  Funktionen: `docs/12-funktionsaudit.md`. Die dringlichsten Punkte sind
  mit 0.10 erledigt (Seitenladen, faule Listen, Feed-Index, Löschen);
  offen bleiben Trigram-Index für die Freundessuche und ein
  Delta-Restore.
- **Drift-Stand v15** (v15 Bildherkunft `imageSource`/`imageLicense`)
- **Drift-Stand v14** (v14 `barcode_volumes`: Gebindegroesse je EAN):
   v10 Warteschlange gelöschter Check-ins, v11
  `checkins.volumeMl`, v12 `story` bei Bier und Brauerei, v13
  `checkins.dirty` (Korrekturen, Funktion 27). Schreibende
  Aktionen, die offline funktionieren sollen, folgen dem Muster
  `venue_queue.dart` / `checkin_delete_queue.dart` (FIFO, idempotent,
  Verbindungsfehler bricht ab, fachlicher Fehler verwirft).
- **Pflicht bei JEDEM Entwicklungslauf**: nutzererstellte Biere prüfen
  (`beers.verified = false` in Supabase) und fehlende Infos ergänzen —
  Anleitung + SQL in `docs/10-community-datenpflege.md`. Beste Quelle ist
  das Etikettfoto des Nutzers (`beers.label_url`), danach Open Food Facts
  über den Barcode. Geprüfte Einträge auf `verified = true` setzen und
  denormalisierte `checkins.beer_name`/`brewery_name` nachziehen.
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
