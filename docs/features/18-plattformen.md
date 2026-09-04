# 18 Plattformen

> **Status:** 🟡 teilweise — Android und Web laufen im Einsatz, Windows
> baut, iOS ist ungetestet, macOS und Linux fehlen.
> **Seit:** Web seit 0.9.10 · **Zuletzt geprüft:** 2026-09-04

## Zielsetzung

Eine Quelle, viele Plattformen. Wer die App auf dem Handy nutzt, soll sie
am Rechner öffnen können, ohne dass jemand eine zweite App pflegen muss.
Die Grundlagen und Regeln stehen in
[Modularität & Portierbarkeit](../11-modularitaet-und-portierbarkeit.md).

## Stand je Plattform

| Plattform | Stand | Einschränkungen |
|---|---|---|
| **Android** | ✅ im Einsatz | keine — die Leitplattform |
| **Web** | ✅ im Einsatz | Kamera braucht Freigabe; Browserdaten löschen löscht die lokale DB; Meldungen nur bei offenem Tab (38) |
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
- **Prüfung:** `flutter build web --release` **und** seit 2026-09-04
  `flutter test --platform chrome` (siehe unten)

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

**Benachrichtigungen: seit 0.10.11 da, mit einer klaren Grenze.** Sie
erreichen dich, solange BrewMates in einem Tab offen ist — als
Systemmeldung, wenn der Tab hinten liegt, und sonst nachgereicht, sobald
du zurückkommst. Ist der Tab **zu**, kommt nichts.

Das ist eine Festlegung, keine Lücke: Der Weg über Firebase ist an dieser
Adresse verschlossen (das SDK verlangt seinen Service Worker im
Wurzelverzeichnis der Domain, BrewMates liegt unter
`…github.io/BrewMates/`), und die Festlegung „nur bei geöffneter Web-App"
macht Service Worker, VAPID-Schlüssel und eine Migration allesamt
überflüssig. Die Einzelheiten samt Kosten des anderen Wegs stehen in
[Funktion 38](38-benachrichtigungen-im-browser.md).

### Was die CI vom Browser tatsächlich weiß (Stand 2026-09-04)

Bis hierher war Regel J eine Absichtserklärung: Die CI baute die Web-App
(`flutter build web --release`), ließ aber nichts im Browser laufen. Ein
Build beweist, dass der Code **übersetzt** — nicht, dass er dort auch
**tut**. Der Unterschied ist nicht theoretisch: Im JavaScript ist `int`
ein `double`, `DateTime` hat keine Mikrosekunden, und jede
`kIsWeb`-Weiche nimmt den jeweils anderen Zweig.

Seit 2026-09-04 läuft `flutter test --platform chrome` in `ci.yml`. Was
er abdeckt und was nicht, in Zahlen — gemessen am Bestand von 70
Testdateien:

| | Dateien | Warum |
|---|---|---|
| **laufen im Browser** | 22 (153 Tests, grün) | reine Logik, Widgets ohne Datenbank |
| ausgenommen: `AppDatabase.memory()` | 42 | `data/db/connection/web.dart` wirft dort `UnsupportedError` |
| ausgenommen: Repo-Wächter | 6 | lesen Dateien mit `dart:io` |

Der Schritt kostet **4:23** (gemessen 2026-09-04); der Flutter-Job der CI
wächst damit von rund 3½ auf 8 Minuten. Derselbe Befehl ohne die
Ausnahmen brauchte 7:43 und meldete 242 Fehlschläge — 229 davon gingen
auf die beiden Gründe oben zurück, keiner auf die App.

Die 48 ausgenommenen Dateien tragen `@TestOn('vm')` **mit dem Grund im
Kopf der Datei**. Bewusst so und nicht als Dateiliste im Workflow: Eine
neue Testdatei läuft damit im Browser mit, ohne dass jemand daran denken
muss. Wer sie ausnimmt, muss es hinschreiben.

**Zwei Fälle sind keine Ausnahme, sondern geteilt.** In
`emoji_font_test.dart` prüft `testOn: 'vm'` das Gerät und
`testOn: 'browser'` das Web — die Schriftkette hängt an `kIsWeb` und
lässt sich nicht überschreiben, also braucht jede Seite ihren eigenen
Lauf. In `kamera_hinweis_test.dart` steht der Fall mit dem
Einstellungs-Knopf hinter `if (!kIsWeb)`: Den Knopf gibt es im Browser
nicht, weil er dort ins Leere führte.

**Was fehlt, um die 42 nachzuholen:** eine Drift-Datenbank, die im
Browser-Test lebt. `WasmDatabase` braucht `sqlite3.wasm`, und das liegt
heute in `web/` — vom Testlauf aus nicht erreichbar. Der Weg wäre, es
zusätzlich als Asset zu führen und `openInMemory()` im Web-Zweig darüber
zu bauen. Das ist echte Arbeit und nichts, was man nebenbei tut; bis
dahin ist die Datenschicht im Browser nur durch den Build und die App
selbst gedeckt.

**Fallstrick beim Nachvollziehen:** Lokal (Windows 11, Chrome 152) hängt
`flutter test --platform chrome` — **jede** Suite, auch ein
`expect(1, 1)`, läuft zwölf Minuten in eine Ladezeitüberschreitung und
meldet nichts. Im Browser-Protokoll stirbt `host.dart.js` sofort mit
„Null check operator used on a null value": Das von Flutter 3.24.5
gepinnte `test 1.25.7` sucht dort ein Element `#play`, das
`flutter_tools/static/index.html` nicht mitbringt. Das Element
versuchsweise zu ergänzen behob den Hänger allerdings **nicht** — es
steckt also mehr dahinter, und die Ursache ist nicht zu Ende erklärt.

**Auf dem CI-Läufer (ubuntu-latest) tritt das nicht auf**, dort läuft
derselbe Befehl mit derselben Flutter-Version durch. Wer den Browser-Lauf
sehen will, prüft ihn deshalb über einen Branch-Push, nicht auf dem
eigenen Rechner. Die Kette `flutter analyze && flutter test --coverage &&
…` bleibt lokal vollständig — nur dieser eine Schritt gehört der CI.

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
