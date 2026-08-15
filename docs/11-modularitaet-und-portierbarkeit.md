# Modularität & Portierbarkeit

Zwei Ziele, die dieselbe Ursache haben: BrewMates soll Funktionen einzeln
hinzufügen, entfernen und warten können — und als Ganzes auf neue
Plattformen wandern, ohne umgeschrieben zu werden. Beides scheitert am
selben Fehler, wenn man ihn macht: Wissen, das an einer Stelle gehört, an
vielen Stellen zu verteilen.

Dieses Dokument hält fest, wie der Schnitt aussehen soll, wo er heute
stimmt und wo nicht.

## Der Schichtenschnitt

```
features/<name>/     Bildschirme und Bedienung — kennt nur sein eigenes Thema
domain/              Regeln ohne Flutter und ohne Datenbank (rein testbar)
data/                Speicherung: lokale DB, Server, Synchronisation
core/                Rahmen: Navigation, Aussehen, Konfiguration
```

Die Richtung ist strikt: `features` → `domain`/`data` → `core`. Nach oben
zeigt nichts, quer zwischen Funktionen zeigt nichts.

**Das hält heute.** Kein einziger Bildschirm importiert einen anderen
Bildschirm (geprüft über alle 14 Funktionsordner). Wer eine Funktion
entfernt, löscht ihren Ordner, ihre Route und ihre Provider — kein anderes
Feature bricht. Genau so soll es bleiben.

## Die drei Sammelstellen

Der Preis für die saubere Feature-Ebene: Alles Gemeinsame ist in drei
Dateien gewandert, die inzwischen zu groß sind.

| Datei | Umfang | Problem |
|---|---|---|
| `data/online/online_service.dart` | 1.705 Zeilen, eine Klasse, 14 Themen | Wer Crews anfasst, öffnet dieselbe Datei wie jemand, der Challenges anfasst |
| `data/providers.dart` | 1.052 Zeilen, 71 Provider, von 34 Dateien importiert | Jede Funktion hängt am selben Import; „was gehört wozu" ist nicht mehr ablesbar |
| `data/db/database.dart` | 1.103 Zeilen, 13 Tabellen + alle Abfragen | Schema und Abfragen aller Themen in einer Klasse |

Das ist heute unangenehm, aber nicht kaputt. Es wird kaputt, sobald zwei
Menschen gleichzeitig arbeiten oder eine Funktion entfernt werden soll:
Dann ist nicht mehr auffindbar, welche 40 Zeilen zu ihr gehörten.

Die gute Nachricht: `online_service.dart` ist bereits in 14 kommentierte
Abschnitte geteilt, die genau den Funktionen entsprechen. Der Schnitt muss
nicht erfunden werden, er muss nur vollzogen werden.

### Zielbild

```
data/online/
  online_client.dart      Verbindung, Auth, gemeinsame Hilfsmittel
  friends_api.dart        je Thema eine Datei mit ihren Abfragen
  crews_api.dart
  venues_api.dart
  …
features/<name>/
  providers.dart          die Provider dieser Funktion, hier und nirgends sonst
```

Verbindlich ab sofort für **neue** Funktionen: eigene API-Datei, eigene
Provider-Datei im Funktionsordner. Bestehendes wird mitgezogen, wenn es
ohnehin angefasst wird — kein Große-Umbau-Commit, der nichts verbessert
und alles riskiert.

## Die Ausbau-Probe

Eine Funktion ist modular, wenn sich in ihrem Dokument in wenigen Schritten
aufschreiben lässt, wie man sie wieder entfernt. Deshalb hat jedes
Funktionsdokument den Abschnitt „Modularität → Ausbauen". Lässt er sich
nicht knapp formulieren, ist der Schnitt falsch — das ist ein Befund, kein
Formalismus.

## Portierbarkeit

Ziel: Android, Web, Windows, iOS, macOS aus einer Quelle. Flutter liefert
die Oberfläche, die Arbeit liegt bei allem, was das Betriebssystem berührt.

**Stand heute — besser als erwartet:**

- `dart:io` kommt in `lib/` genau **einmal** vor, im
  Plattform-Umschalter `data/db/connection/native.dart`. Das ist das
  richtige Muster: Ein Conditional Import wählt zwischen nativer und
  Web-Umsetzung, der Rest der App merkt nichts davon.
- Plattform-Abfragen (`kIsWeb`, `defaultTargetPlatform`) stehen in
  **vier** Dateien. Überschaubar und benannt.
- Android, Web, Windows und iOS haben Projektordner; Android und Web sind
  im Einsatz, Windows baut.

**Was fehlt:**

- macOS und Linux haben keine Projektordner (`flutter create --platforms`
  genügt, sobald jemand sie braucht).
- iOS ist nie gebaut worden — der Ordner existiert, die Signierung nicht.
- Drei Pakete binden uns an Plattformen: `mobile_scanner` (Kamera),
  `geolocator` (Standort), `image_picker` (Fotos). Auf Desktop fehlt
  jeweils die Hardware-Anbindung; die App fängt das heute ab, indem sie
  die Funktion versteckt statt abzustürzen.

### Regeln

1. **Kein `dart:io` in `lib/`.** Wer eine Datei, einen Pfad oder ein
   Betriebssystem braucht, baut einen Conditional Import nach dem Muster
   von `data/db/connection/`. Die CI erzwingt das über `flutter build web`.
2. **Plattformabfragen zentral,** nicht in Bildschirmen verstreut. Und
   `kIsWeb` zuerst prüfen: Im Browser meldet `defaultTargetPlatform`
   trotzdem Android.
3. **Fehlt eine Fähigkeit, verschwindet die Schaltfläche** — kein
   Fehlerdialog für etwas, das die Plattform nie konnte. Der Scanner zeigt
   auf Desktop die manuelle Eingabe statt einer toten Kamera.
4. **Nichts aus dem Netz nachladen, was auch lokal liegen kann.** Diese
   Lektion hat drei Anläufe gekostet: CanvasKit, die Schriften und die
   Scanner-Bibliothek wurden alle zur Laufzeit von fremden CDNs geholt —
   und ein VPN oder Werbeblocker beim Nutzer machte daraus eine App ohne
   Text bzw. einen Scanner, der schweigend nichts erkennt. Alles davon
   liegt heute im eigenen Bundle, versionsgepinnt.
5. **Jede Funktion benennt ihre Plattformen** in ihrem Dokument, mit dem
   Grund für jede Einschränkung.

## Benutzererlebnis als Architekturfrage

Das Ziel ist nicht „läuft überall", sondern „fühlt sich überall richtig
an". Was dafür in der Architektur verankert gehört:

- **Local-first bleibt.** Die App gehört dem Menschen, nicht dem Netz:
  Check-in, Tagebuch und Datenbank funktionieren ohne Verbindung, der
  Abgleich passiert im Hintergrund. Was offline nicht geht, muss begründet
  sein.
- **Kein Warten ohne Grund.** Schreibende Aktionen wirken sofort lokal und
  synchronisieren danach (siehe `venue_edit_queue`). Dieses Muster ist die
  Vorlage für alles Weitere.
- **Leere Zustände sind Teil der Funktion,** nicht ein Sonderfall: Jeder
  Bildschirm sagt, was zu tun ist, wenn noch nichts da ist.
- **Fehler schweigen nicht.** Ein leeres Ergebnis, weil die Anmeldung
  fehlte, ist ein Fehler und muss als solcher erscheinen — nicht als
  „keine Treffer" (dieser Fall ist in der Freundessuche real passiert).
