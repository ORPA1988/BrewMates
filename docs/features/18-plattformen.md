# 18 Plattformen

> **Status:** 🟡 teilweise — Android und Web laufen im Einsatz, Windows
> baut, iOS ist ungetestet, macOS und Linux fehlen.
> **Seit:** Web seit 0.9.10 · **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Eine Quelle, viele Plattformen. Wer die App auf dem Handy nutzt, soll sie
am Rechner öffnen können, ohne dass jemand eine zweite App pflegen muss.
Die Grundlagen und Regeln stehen in
[Modularität & Portierbarkeit](../11-modularitaet-und-portierbarkeit.md).

## Stand je Plattform

| Plattform | Stand | Einschränkungen |
|---|---|---|
| **Android** | ✅ im Einsatz | keine — die Leitplattform |
| **Web** | ✅ im Einsatz | Kamera braucht Freigabe; Browserdaten löschen löscht die lokale DB; **keine Benachrichtigungen** (siehe 38) |
| **Windows** | 🟡 baut | kein Scanner, keine Ortung, kein Foto |
| **iOS** | 🟡 Projekt vorhanden | nie gebaut, keine Signierung, Apple-Anmeldung fehlt |
| **macOS / Linux** | 🔴 fehlt | Projektordner nicht angelegt |

Live: `https://orpa1988.github.io/BrewMates/`

## Technische Umsetzung

- **Datenbank:** Drift — nativ über SQLite, im Browser über
  `WasmDatabase` (OPFS). Die Weiche liegt in `data/db/connection/`
  (Conditional Imports); der native Pfad ist byte-identisch zu vorher.
- **Web-Bundle, alles selbst gehostet:** `web/sqlite3.wasm` (2.9.4),
  `web/drift_worker.js` (selbst kompiliert aus `tool/drift_worker.dart`),
  `web/zxing.js` (0.19.1), CanvasKit, Roboto, Noto-Emoji
- **Auslieferung:** GitHub Actions — `pages.yml` (Web), `release.yml`
  (APK/AAB, signiert)
- **Regel:** kein `dart:io` in `lib/`; die CI erzwingt es über
  `flutter build web`

**Die teuerste Lektion steckt in diesen Zeilen.** Drei Bestandteile wurden
ursprünglich zur Laufzeit von fremden CDNs geladen — Schriften, Engine,
Scanner-Bibliothek. Bei Nutzern mit VPN oder Werbeblocker führte das zu
einer App ohne Text und einem Scanner, der schweigend nichts erkannte.
Jeder dieser Fälle kostete eine eigene Fehlersuche. Heute liegt alles im
Bundle, versionsgepinnt.

### Web ist Zweitgerät, nicht Testumgebung (Entscheidung 2026-09-03)

Wer kein Android hat — in der Testphase alle iPhone-Nutzer — nutzt
BrewMates im Browser. Deshalb gilt: **Alles, was die App kann, muss auch
im Browser gehen**, und beides muss denselben Stand zeigen (siehe
Session-Abgleich in 07).

**Bekannte Lücke: Benachrichtigungen.** Und zwar aus einem Grund, der
nicht in der App steckt: Das Firebase-JS-SDK registriert seinen Service
Worker fest unter `/firebase-messaging-sw.js` — im Wurzelverzeichnis der
Domain. BrewMates liegt unter `…github.io/BrewMates/`, einer
Projektseite; dort ist die Wurzel nicht erreichbar. Der Dart-Aufsatz
reicht keine eigene Registrierung durch (`serviceWorkerRegistration` ist
in `firebase_messaging_web 4.1.5` auskommentiert).

Das ist ein **Hosting**-Problem, kein Konfigurationsproblem — ein
Firebase-Web-Schlüssel würde daran nichts ändern. Untersuchung, drei
Wege und eine Empfehlung stehen in
[Funktion 38](38-benachrichtigungen-im-browser.md); die Entscheidung
liegt beim Menschen.

## Modularität

- **Hängt ab von:** nichts
- **Wird gebraucht von:** allem
- **Ausbauen:** einzelne Plattformen lassen sich durch Löschen ihres
  Ordners entfernen.

## Skalierung

Das Web-Bundle ist durch CanvasKit und den Emoji-Font groß (~15 MB beim
ersten Aufruf). Der Service Worker fängt das ab dem zweiten Besuch ab.
Wenn das stört, wäre der farbige Emoji-Font (10,7 MB) der erste
Streichkandidat.

## Umsetzungsstatus

Android und Web tragen den Betrieb. Windows baut, ist aber ohne Kamera und
Ortung eine reine Lese- und Tagebuch-App — das ist ein legitimer
Anwendungsfall, nur nicht der beworbene.

## Umsetzungsplan

1. **iOS ernsthaft angehen:** bauen, signieren, Apple-Anmeldung ergänzen
   (Store-Pflicht, wenn Google-Login angeboten wird)
2. **macOS und Linux** anlegen, sobald jemand danach fragt
   (`flutter create --platforms=macos,linux`)
3. Für Desktop klären, ob eine Kamera-Anbindung lohnt oder die manuelle
   Eingabe genügt

## Offene Punkte / Ideen

- Windows-Paket über MSIX ist vorbereitet (`msix_config` in `pubspec.yaml`)
- Progressive Web App als Installationsweg ohne Store
