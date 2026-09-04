# CLAUDE.md — Arbeitsanleitung für Claude-Sessions

BrewMates: Bier-App (Untappd × Beer with Me), Flutter, deutschsprachig,
Fokus DACH-Raum (Herz: Österreich + Bayern). **Antworte dem Nutzer auf
Deutsch.**

Diese Datei ist der Einstieg und wird jede Sitzung gelesen. Sie sagt, was
zu tun ist. Was war und warum, steht in
[docs/13 — Migrationen & Lehren](docs/13-migrationen-und-lehren.md).

**Sie enthält nur Aussagen, die stimmen.** Steht hier etwas, das die
Datenbank oder das Repo widerlegt, ist diese Datei der Fehler — nicht die
Wirklichkeit. Richtigstellen gehört zum Durchlauf.

---

## 1. Bei jedem Durchlauf

Diese vier Punkte gehören zu jeder Sitzung, unabhängig vom Auftrag:

1. **Diese Datei lesen** und am Ende richtigstellen, was nicht mehr
   stimmt.
2. **Nutzererstellte Biere pflegen** — Anleitung und SQL in
   [docs/10 — Community-Datenpflege](docs/10-community-datenpflege.md).
   Kurz: `beers.verified = false` prüfen, **auf Dubletten prüfen**,
   fehlende Felder aus Herstellerseite + Open Food Facts ergänzen,
   `verified = true` setzen und `checkins.beer_name`/`brewery_name`
   nachziehen.
3. **Offene Meldungen ansehen:**
   `gh issue list --label feedback --state open`. Eine Antwort für den
   Melder ist ein Kommentar, der mit **„Antwort:"** beginnt.
4. **Doku mitziehen** — im selben Commit wie der Code, nie danach.

## 2. Unverhandelbare Regeln

**A — Kein Erfolg, den der Server nicht bestätigt hat.**
Eine Zusage, die niemanden erreicht, lässt jemanden warten. Eine
Erfolgsmeldung ohne Bestätigung ist der teuerste Fehler dieser App und
war schon dreimal da. Rückgabewerte weiterreichen, Fehlschläge benennen.

**B — Rechte prüft man in der Rolle, die sie betrifft.**
`set local role authenticated` + `request.jwt.claims`. `postgres` umgeht
RLS und beweist nichts. Auch die MCP-Probe läuft als `postgres`.

**C — Migrationen: erst grüne CI, dann live.**
Die CI baut die Datenbank bei jedem PR **neu aus `supabase/migrations/`**
— das prüft den Aufbauweg mit. Erst danach `apply_migration`. Eine
Migration, die ein Recht entzieht, gehört nie in dieselbe Datei wie die
Ersatzschnittstelle.

**D — Vor jedem Live-Eingriff `list_migrations` und
`list_edge_functions` ansehen**, nicht nur das Repo. Zwei Sitzungen auf
einer Datenbank brauchen einen Menschen, der sagt, welche weitermacht.

**E — `main` ist geschützt.** Kein `git push origin main`. Merge über
`gh api -X PUT repos/ORPA1988/BrewMates/pulls/<n>/merge -f merge_method=merge`.
Neue Arbeit startet auf einem frischen Branch von `main`.

**F — Jede Funktionsänderung zieht ihr Dokument mit**, im selben Commit:
`docs/features/` (Vorlage `_vorlage.md`, Index `README.md`). Eine **neue**
Funktion beginnt mit ihrem Dokument, nicht mit dem ersten Widget.

**G — Architektur-Leitplanken** ([docs/11](docs/11-modularitaet-und-portierbarkeit.md)):
Schichtrichtung `features → domain/data → core`; keine Cross-Imports
zwischen Features; neue Funktionen bekommen eigene API- und
Provider-Datei statt in die Sammelstellen hineinzuwachsen. **Kein
`dart:io` in `app/lib/`** (die CI erzwingt `flutter build web`);
Plattform-Weichen über `kIsWeb`/`defaultTargetPlatform` oder Conditional
Imports (Muster: `data/db/connection/`). **Zur Laufzeit nichts von fremden
Servern nachladen.**

**H — Versions-Bump immer an beiden Stellen:** `app/pubspec.yaml` **und**
`AppConfig.appVersion` in `core/config.dart`. Ein Test erzwingt den
Gleichstand.

**I — Sync-Invariante.** Community-JSON-Datensätze (Biere mit
`isUserSubmitted == false`, Brauereien mit Nicht-UUID-ID) sind in der App
**read-only** — der GitHub-Sync überschreibt sie wholesale.
In-App-Bearbeitung gibt es nur für nutzererstellte Zeilen (UUIDs) und
Gasthäuser (Supabase). Korrekturen an Community-Daten laufen über
„Korrektur vorschlagen" (`core/external_links.dart`).

**J — Web ist Zweitgerät mit vollem Funktionsumfang** (iPhone-Tester).
Parität ist Anforderung, kein Nice-to-have.

**K — Aussperr- und Datenschutz-Entscheidungen gehören dem Menschen.**
`min_supported_version` anheben, E-Mail-Bestätigung, Sichtbarkeiten —
vorlegen, nicht entscheiden.

## 3. Prüfen statt glauben

Der teuerste Fehler dieses Projekts war ein Absatz, der einen
Sicherheitsvorbehalt behauptete, den es längst nicht mehr gab (siehe
[docs/13, Lehre 1](docs/13-migrationen-und-lehren.md)). Deshalb: fragen,
nicht nachlesen.

| Frage | Wie du sie beantwortest |
|---|---|
| Welche Migrationen sind live? | `list_migrations` |
| Welche Edge Functions, in welcher Version? | `list_edge_functions` |
| Wer darf was auf einer Tabelle? | `information_schema.table_privileges` |
| Wer darf welche **Spalte** lesen? | `information_schema.column_privileges` |
| Greift eine Policy wirklich? | `set local role authenticated` + `request.jwt.claims`, in einer Transaktion mit `rollback` |
| Ist eine Funktion für `authenticated` aufrufbar? | `has_function_privilege('authenticated', '…', 'execute')` |
| Was meldet der Linter? | `get_advisors` (`security` / `performance`) — Baseline in docs/13, Teil 3 |

## 4. Wo was steht

| Frage | Datei |
|---|---|
| Was ist am Server, warum, welche Fehler kennen wir? | [docs/13 — Migrationen & Lehren](docs/13-migrationen-und-lehren.md) |
| Was kann eine einzelne Funktion, wie ist sie gebaut? | [docs/features/](docs/features/README.md) — ein Dokument je Funktion |
| Wann kommt was? | [docs/06 — Roadmap](docs/06-roadmap.md) |
| Wie kommt ein Release heraus, wie schalte ich Anbieter frei? | [docs/07 — Release-Playbook](docs/07-release-playbook.md) |
| Wie pflege ich Bierdaten? | [docs/10 — Community-Datenpflege](docs/10-community-datenpflege.md) |
| Wo verlaufen die Architekturgrenzen? | [docs/11 — Modularität](docs/11-modularitaet-und-portierbarkeit.md) |
| Wie vollständig und skalierbar ist der Bestand? | [docs/12 — Funktionsaudit](docs/12-funktionsaudit.md) |
| Wie erkläre ich es einem Laien? | [docs/08 — Funktionsweise für alle](docs/08-funktionsweise-fuer-alle.md) |
| Was ist an Barrierefreiheit zugesichert? | [docs/14 — Barrierefreiheit](docs/14-barrierefreiheit.md) |
| Welche Fundstellen sind priorisiert offen? | `.claude/backlog.md` (A-1, A-7 …) — ergänzt die Roadmap, ersetzt sie nicht |
| Welche Konventionen gelten beim Schreiben? | `.claude/conventions.md`, `.claude/architecture.md` |

## 5. Der Stand

- **Version:** `0.10.13-beta+31` (Beta 0.x bis zum Play-Store-1.0; der
  Android-`versionCode` zählt immer weiter hoch).
- **Backend:** Supabase-Projekt `swlqkwlpnxwthbneblww` (EU).
  **`0001–0047` sind live, lückenlos.** Details: docs/13.
  `list_migrations` zeigt **48** Einträge, das Repo hat 47 Dateien —
  **das ist kein Drift.** `0024_friend_tiers.sql` wurde live in zwei
  Schritten eingespielt (`friend_tiers` + `friend_tiers_thirsty_friends`);
  inhaltlich steht beides in der einen Repo-Datei. Wer nur zählt, meldet
  einen Fehler, den es nicht gibt (geprüft 2026-09-04).
- **Riegel:** `app_config.min_supported_version` steht auf `0.10.4`.
  Anheben ist eine Aussperr-Entscheidung (Regel K); Einzeiler im
  Release-Playbook.
- **Anmeldung:** Google und E-Mail (ohne Bestätigungspflicht) sind
  eingerichtet. Die App **kann** zusätzlich Apple, Microsoft (`azure`),
  Facebook, Discord und GitHub — welche Knöpfe erscheinen, sagt
  `app_config.auth_providers` (0046), nicht das Release. Einrichtung je
  Anbieter im Release-Playbook; **Apple kostet 99 $/Jahr.**
- **Drift-Stand v15** (v10 Löschwarteschlange, v11 `checkins.volumeMl`,
  v12 `story`, v13 `checkins.dirty`, v14 `barcode_volumes`, v15
  `imageSource`/`imageLicense`). Schreibende Aktionen, die offline
  funktionieren sollen, folgen dem Muster `venue_queue.dart` /
  `checkin_delete_queue.dart` (FIFO, idempotent, Verbindungsfehler bricht
  ab, fachlicher Fehler verwirft).
- **Vertrauensstufen** (0013): 1 Neuling · 2 Stammgast (≥25 P.) ·
  3 Bierkenner (≥100 P.) · 4 Moderator · 5 Admin; Overrides über
  `user_features`. RLS erzwingt, die UI spiegelt
  (`accountLevelProvider`).
- **Web-Push bei geschlossenem Tab ist am Hosting blockiert.** Das
  Firebase-JS-SDK registriert seinen Service Worker fest unter
  `/firebase-messaging-sw.js` im **Wurzelverzeichnis der Domain**;
  BrewMates liegt unter `…github.io/BrewMates/`. Ein Firebase-Web-Schlüssel
  ändert daran nichts — **nicht beschaffen, bevor der Weg entschieden
  ist.** Drei Wege und eine Empfehlung:
  [Funktion 38](docs/features/38-benachrichtigungen-im-browser.md).
- **Repo-Sicherheit:** Secret-Scanning + Push-Schutz aktiv,
  Dependabot ein, keine Geheimnisse im Repo.

## 6. Toolchain

- **Flutter 3.24.5**, gepinnt. `flutter analyze` und `flutter test` laufen
  ohne Android-SDK. Lokal liegt Flutter unter
  `C:\Users\patri\toolchain\flutter\bin`.
- **Gepinnte Pakete** (Flutter-3.24-Kette): `mobile_scanner ^5.2.3`,
  `geolocator ^13.0.2` — **nicht ohne Toolchain-Upgrade anheben.**
  `qr_flutter ^4.1.0` ist reines Dart.
- **Android-Release** braucht Android SDK (cmdline-tools) + **JDK 17**
  (JDK 21 bricht mit AGP 8.1/jlink). `app/android/build.gradle` enthält
  bewusst eine `ext.flutter`-Map + AGP-8.1-Classpath — **nicht
  „aufräumen".**
- **Push/Firebase:** `firebase_core ^4.7`, `firebase_messaging ^16.2`,
  `minSdk` 23. `google-services.json` liegt bewusst im Repo
  (`app/android/app/`), der Dienstkonto-Schlüssel **nie**.
- **Web-Laufzeitdateien sind versionsgepinnt** und müssen bei
  Paket-Upgrades neu geladen werden: `web/sqlite3.wasm` (sqlite3 2.9.4),
  `web/drift_worker.js` (drift 2.23.1), `web/zxing.js`
  (@zxing/library 0.19.1 — muss zur `scriptUrl` in `mobile_scanner`
  passen). CanvasKit wird selbst gehostet
  (`web/flutter_bootstrap.js`).
- **Arbeitsverzeichnis:** `F:\KI\selfmadeapps\BrewMates`. Bis 2026-09-04
  lag das Repo in einem **OneDrive**-Ordner; dort scheiterten lokale
  `flutter build apk` regelmäßig an Dateisperren des Sync-Dienstes
  (`Unable to delete directory`) — das war nie ein Codefehler. Seit dem
  Umzug auf F: entfällt der Grund; verbindlich bleibt trotzdem der
  Release-Build in der CI.
- **Arbeitsplatz (VS Code):** `.vscode/extensions.json` nennt, was hier
  gebraucht wird; `.vscode/settings.json` zieht die Grenzen. Wichtigste:
  `deno.enablePaths` beschränkt die Deno-Erweiterung auf
  `supabase/functions` — ohne das beansprucht sie den ganzen Baum und
  streitet mit der Dart-Analyse. Deno selbst ist **nicht** global
  installiert. Kein `formatOnSave` für Dart: die CI erzwingt keine
  Formatierung, ein Autoformat zieht nur fremde Zeilen in Diffs.
  `.vscode/launch.json` startet App (Gerät/Web/Profil) und Einzeltests —
  jeweils mit `cwd` auf `app/`, weil der geöffnete Ordner das
  Wurzelverzeichnis ist. `.vscode/tasks.json` bildet die CI-Kette nach;
  **Strg+Umschalt+B ist „Prüfen wie die CI"** und läuft dieselben fünf
  Schritte wie `ci.yml`. Der Abdeckungs-Task ruft zusätzlich
  `tools/lcov_for_vscode.dart` — es hebt die lcov-Pfade von `lib/…` auf
  `app/lib/…` in eine **zweite** Datei, damit Coverage Gutters die
  Quellen findet und `lcov.info` für CI und `coverage_report.dart`
  unverändert bleibt.
- **Fallstricke:** `flutter test` nie nach `tail` pipen (scheint zu
  hängen) — in eine Datei umleiten und diese lesen. In Git Bash braucht
  `flutter build web --base-href /BrewMates/` ein vorangestelltes
  `MSYS_NO_PATHCONV=1`.
- **In Widget-Tests** meldet `defaultTargetPlatform` Android;
  Desktop-Tests setzen `debugDefaultTargetPlatformOverride`. Nach einem
  Tipp, der die Datenbank anfasst, reicht `pumpAndSettle` nicht —
  `tester.runAsync` dazwischen (Beispiel: `beacon_zusagen_test.dart`).

## 7. Releases

GitHub-Release = Workflow `release.yml` per **workflow_dispatch**
triggern (Input `version`, z. B. `v0.10.13-beta`); ein Tag-Push scheitert
mit 403. Der Lauf baut APK + AAB und veröffentlicht sie, signiert mit dem
Upload-Keystore aus den Secrets `KEYSTORE_BASE64`/`KEYSTORE_PASSWORD` —
**stabile Signatur = Updates ohne Datenverlust.**

Die Web-App wird bei jedem Push auf `main` automatisch deployt
(`pages.yml` → <https://orpa1988.github.io/BrewMates/>).

## 8. Daten & Konventionen

- **Community-DB:** `app/assets/data/` — acht Dateien (`beers-at/by/de/ch`,
  `breweries-at/by/de/ch`), verknüpft über `brewery_id`. Bayern-IDs
  `de-by-…`, Restdeutschland `de-…`, Schweiz `ch-…`. Bild-URLs nur als
  **Links** auf Open Food Facts (CC-BY-SA), Herkunft und Lizenz in
  `DATENHERKUNFT.md`.
- **Nicht-Freunde erscheinen auf der Karte nie mit Position**, nur als
  Zähler. Karten-Wording zentral in `activeUsersLabel()`
  (`features/map/map_screen.dart`).
- **Challenge-Abschlüsse werden serverseitig validiert**
  (`complete_challenge`-RPC; direkte Inserts sind gesperrt).
- **orpa-tech.at ist bewusst kein Bestandteil des Projekts.**
