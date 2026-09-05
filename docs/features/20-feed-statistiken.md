# 20 Statistiken & Auswertung

> **Status:** 🟢 Stufe 2 zum größten Teil gebaut — acht Aufteilungen per
> Chip, neun Kennzahlen, freier Zeitraum und Vergleich mit dem Zeitraum
> davor. Reinalkohol ist **entschieden und gebaut** (siehe Punkt 6).
> **Offen bleibt** die Crew-Auswertung auf derselben Maschinerie; der
> CSV-Export ist seit 0.10.19 da (Punkt 7).
> **Seit:** 0.9.15-beta (Stufe 1) · 0.10.14-beta (Stufe 2) ·
> **Zuletzt geprüft:** 2026-09-05
>
> **Hier steht die gesamte Auswertung.** [Funktion 13](13-statistiken-und-tagebuch.md)
> ist das Tagebuch — die Liste zum Nachlesen — und die Wochen-Serie. Die
> Zähler im Profil sind nur der Anreißer, der hierher führt.

## Zielsetzung

Wer ein Jahr lang Check-ins sammelt, will irgendwann wissen, was dabei
herausgekommen ist: Wie viel war das eigentlich? Woher kamen die Biere?
Was trinke ich am liebsten, und hat sich das verändert?

Die Daten liegen fast vollständig vor — sie werden nur nicht ausgewertet.
Das ist die günstigste Funktion im ganzen Plan: viel Ertrag, kaum neue
Substanz.

**Grundsatz aus der Produktvision:** Ausgewertet wird **Vielfalt und
Erinnerung**, nicht Leistung. Liter werden gezeigt, weil die Frage
naheliegt — aber nie als Bestenliste gegen andere und nie mit einer
Zielvorgabe. Ein Rückblick, kein Wettbewerb.

## Funktion (Nutzersicht)

Ein Statistik-Bereich, erreichbar aus dem Feed und aus dem Profil:

- **Gesamt:** Check-ins, verschiedene Biere, Brauereien, Orte, Menge in
  Litern, Ø Bewertung, alkoholfreie
- **Aufteilungen** als Balken, jeweils absteigend:
  Land · Stil (Top 10) · Gebinde (Fass, Flasche, Dose, Growler,
  „ohne Angabe") · Brauerei (Top 10)
- **Zeitraum:** dieser Monat · dieses Jahr · alles
- **Filter** für Land und Stil, kombinierbar mit dem Zeitraum — „nur
  Österreich, nur Pils, dieses Jahr"
- **Verlauf:** Check-ins je Monat als schlichte Balkenreihe. Monate ohne
  Eintrag fehlen, statt als Null zu erscheinen — kein Eintrag ist kein
  Nullwert.

Ausgewertet werden **eigene** Check-ins. Das ist die ehrliche Grenze:
Von Freunden liegt nur das geladene Fenster vor, eine Auswertung darüber
wäre falsch statt unvollständig.

Orte erscheinen als Zahl, aber nicht als Balken: Der Gasthausname ist am
Check-in denormalisiert, Tippfehler und Schreibvarianten würden dieselbe
Wirtschaft mehrfach auflisten.

## Technische Umsetzung

- **Neu:** `domain/statistics.dart` — reine Auswertung über
  `List<StatsEntry>`, ohne Flutter und ohne Datenbank, damit
  vollständig testbar (`computeStats`, `CheckinStats`)
- **Neu:** `features/stats/stats_screen.dart` + `stats_providers.dart`
  (eigene Provider-Datei statt Anbau an die Sammelstelle, siehe docs/11)
- **Geändert:** `features/checkin/checkin_screen.dart` (Mengenauswahl),
  `core/format.dart` (`formatVolume`, `formatLitres`), Drift v11,
  Migration 0022 für `checkins.volume_ml`, Upload- und
  Wiederherstellungspfad

Die Ergebnisklasse heißt `CheckinStats`, nicht `BeerStats` — den Namen
belegt bereits das Join-Modell für Bier-Bewertungen.

**Nachtrag 2026-08-15 — die Auswertung hing an der Datenbank.** Die erste
Fassung nahm `List<CheckinDetails>` entgegen und importierte dafür
`data/db/database.dart`. Damit war `domain/statistics.dart` die erste
Datei, die die Regel „`domain/` importiert nichts aus `data/`" brach —
eine Regel, welche die Doku bis dahin als lückenlos beschrieb. Behoben
über zwei Schritte:

- `StatsEntry` in `domain/` ist der Eingabetyp: nur die elf Felder, die
  die Auswertung wirklich liest. Die Übersetzung aus `CheckinDetails`
  liegt in `features/stats/stats_providers.dart` — ein Feature darf beide
  Schichten lesen, `data/` und `domain/` sollen einander nicht anziehen.
- `ServingStyle` ist nach `core/serving_style.dart` gewandert. Es war
  immer ein reines Wert-Enum ohne Drift-Bezug; dass es in der
  Datenbankdatei stand, zwang jeden Nutzer in die `data/`-Schicht.
  `data/db/database.dart` reicht es weiter, damit kein Aufrufer bricht.

Der Test `test/architecture_test.dart` prüft die Schichtregeln ab jetzt
bei jedem Lauf. Er fand dabei zwei weitere Verstöße (`domain/badges.dart`,
`domain/challenges.dart`) — die stehen als Backlog **A-7** an und sind in
einer Ratsche festgehalten, die nur schrumpfen darf.

**Die fehlende Zutat war die Menge.** `ServingStyle` (Gebinde) gab es
bereits, aber keine Füllmenge. Neu: `volume_ml` als Ganzzahl, im Check-in
über Auswahlchips gesetzt (0,2 · 0,25 · 0,33 · 0,4 · 0,5 · 1 l),
vorbelegt nach Gebinde. Alte Check-ins ohne Angabe zählen mit einem
Schätzwert je Gebinde und werden als geschätzt gekennzeichnet — eine
Literzahl, die so tut, als wäre sie gemessen, wäre eine Lüge.

**Keine Diagramm-Bibliothek.** Die Balken entstehen aus
`Container`-Breiten. Das hält die App plattformunabhängig und spart ein
Paket, das auf einer der fünf Zielplattformen erfahrungsgemäß klemmt.

## Modularität

- **Hängt ab von:** Check-ins (02), Bierdatenbank (04, für Land und Stil)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Ordner `features/stats/` und `domain/statistics.dart`
  löschen, zwei Einstiegspunkte entfernen. `volume_ml` darf bleiben — es
  ist auch ohne Auswertung eine sinnvolle Angabe.

## Plattformen

Alle. Reine Rechnung und Darstellung.

## Skalierung

Die Auswertung läuft heute über alle eigenen Check-ins im Speicher. Bei
einigen tausend Einträgen ist das noch unauffällig, darüber gehört die
Summenbildung in SQL (Drift kann `groupBy`). Der Schnitt ist vorbereitet,
weil `domain/statistics.dart` nur eine Liste bekommt: Die Quelle lässt sich
später austauschen, ohne die Darstellung anzufassen.

## Umsetzungsstatus

Vollständig. Erreichbar über das Balkensymbol im Feed und die Kachel
„Statistik" im Profil.

Die Menge wird beim Check-in über Auswahlchips gesetzt (0,2 · 0,25 ·
0,33 · 0,4 · 0,5 · 1 l), vorbelegt nach Gebinde, bis der Mensch selbst
wählt. Sie wandert mit dem Check-in in die Cloud und kehrt bei der
Wiederherstellung zurück — sonst wäre sie beim Gerätewechsel weg.

Abgesichert durch `test/statistics_test.dart` (34 Tests): Summen,
Schätzung fehlender Mengen, Zeiträume, Filter einzeln und kombiniert,
Sortierung samt Gleichstand, Zählung verschiedener Biere/Brauereien/Orte,
Durchschnitt nur über Bewertetes, Monatsverlauf, Formatierung — dazu seit
Stufe 2 die neuen Aufteilungen und Kennzahlen, der Vergleichszeitraum und
der freie Zeitraum. `test/stats_screen_test.dart` prüft den Bildschirm
selbst, den es bis 0.10.13 gar nicht geprüft hatte.

---

# Ausbaustufe 2 — gebaut am 2026-09-04

> Dieser Abschnitt war bis 0.10.13 ein Plan. Er bleibt stehen, weil die
> Begründungen weiter gelten — ergänzt um **was davon gebaut ist**
> (Abschnitt 10) und was bewusst offen blieb.

Stufe 1 beantwortete „wie viel und wovon". Sie tat das gut, aber sie war
**starr**: Vier Aufteilungen, drei Zeiträume, zwei Filter — alles fest
verdrahtet. Jede neue Frage kostete eine Änderung an vier Stellen
(Eingabetyp, Auswertung, Ergebnisklasse, Bildschirm) plus Tests.

Deshalb stand am Anfang von Stufe 2 kein neues Diagramm, sondern **ein
Umbau, der jedes weitere Diagramm billig macht**.

## 1. Der Befund

**Was heute fehlt — inhaltlich:**

| Lücke | Warum sie zählt |
|---|---|
| **Kein Alkoholgehalt** | `CheckinFacts` trägt kein `abv`. Damit ist die ehrlichste Zahl über den eigenen Konsum nicht berechenbar — und die ist etwas anderes als „Liter" |
| **Keine Zeitmuster** | Wochentag, Uhrzeit, Jahreszeit liegen in `createdAt` und werden nie ausgewertet. „Freitag ist dein Bierabend" ist Erinnerung, nicht Leistung |
| **Keine Entdeckungsrate** | Wie viele Biere waren **neu**? Das ist die Kernfrage der Produktvision (Vielfalt), und sie wird nicht gestellt |
| **Kein freier Zeitraum** | Monat / Jahr / alles. „Mein Urlaub im Juli" geht nicht |
| **Keine Region** | `breweries.city` liegt vor, ausgewertet wird nur `country`. Für eine DACH-App ist „Oberösterreich vs. Bayern" die interessantere Frage |
| **Kein Vergleich mit vorher** | „Dieser Monat" ohne „letzter Monat" ist eine Zahl ohne Maßstab |

**Was heute fehlt — strukturell:**

`CheckinStats` ist ein Datensatz mit **benannten Feldern** (`byCountry`,
`byStyle`, `byServing`, `byBrewery`). Eine fünfte Aufteilung heißt: Feld
ergänzen, Konstruktor ergänzen, `computeStats` ergänzen, Bildschirm
ergänzen, Test ergänzen. Bei vier Aufteilungen geht das; bei zwölf ist es
eine Wand.

Dazu gibt es die Auswertung **zweimal**: `domain/statistics.dart` für
das eigene Tagebuch und `domain/crew_stats.dart` für die Crew. Das war
2026-09-03 richtig entschieden (die Feed-Zeile vom Server trägt weder
Menge noch Gebinde noch Land, siehe [Funktion 09](09-crews.md)) — aber
sobald die Maschinerie generisch ist, sollten beide dieselbe benutzen und
sich nur in den verfügbaren Dimensionen unterscheiden.

## 2. Der Umbau: Kennzahl, Aufteilung, Darstellung trennen

Drei Begriffe, die heute vermischt sind:

- **Kennzahl** (*Measure*) — was gezählt wird: Check-ins, Liter,
  verschiedene Biere, Ø Bewertung.
- **Aufteilung** (*Dimension*) — wonach gruppiert wird: Stil, Land,
  Wochentag, Gebinde.
- **Auswahl** (*Filter + Zeitraum*) — worüber überhaupt gerechnet wird.

Jede sinnvolle Statistik ist eine Kombination aus diesen dreien. Wenn die
drei als Daten vorliegen statt als Code, ist eine neue Statistik **ein
Listeneintrag**.

```dart
// domain/statistics/dimension.dart  (Skizze, nicht endgültig)
class Aufteilung {
  const Aufteilung(this.schluessel, this.name, this.wert, {this.top});

  final String schluessel;              // 'stil', stabil für Export/Speicher
  final String name;                    // 'Stil', für den Menschen
  final String? Function(CheckinFacts) wert;  // null = „ohne Angabe"
  final int? top;                       // Top-N oder alles
}

const aufteilungen = <Aufteilung>[
  Aufteilung('land',      'Land',      (c) => c.breweryCountry),
  Aufteilung('stil',      'Stil',      (c) => c.beerStyle, top: 10),
  Aufteilung('gebinde',   'Gebinde',   (c) => c.serving?.name),
  Aufteilung('brauerei',  'Brauerei',  (c) => c.breweryName, top: 10),
  Aufteilung('wochentag', 'Wochentag', (c) => wochentag(c.createdAt)),
  Aufteilung('region',    'Region',    (c) => c.breweryCity),
];
```

`computeStats` liefert dann `Map<String, List<StatSlice>>` statt vier
benannter Felder. Eine neue Aufteilung ist eine Zeile in dieser Liste —
kein Eingriff in Bildschirm oder Ergebnisklasse.

Dasselbe für Kennzahlen: `Kennzahl(schluessel, name, summe, formatieren)`.

**Was das kostet:** Ein einmaliger Umbau von `domain/statistics.dart`
(228 Zeilen) und `stats_screen.dart` (327 Zeilen), plus die 15 Tests, die
mitziehen. **Was es bringt:** Alles unter Punkt 3 und 4 wird danach zu
Konfiguration.

**Was dabei nicht verhandelbar ist:**

- `domain/` bleibt frei von `data/` und Flutter (der
  `architecture_test.dart` erzwingt es — genau hier ist die Regel schon
  einmal gebrochen worden).
- Der Eingabetyp bleibt `CheckinFacts` in `core/`. Neue Felder (`abv`,
  `breweryCity`, `sessionId`) kommen **dort** dazu, an einer Stelle.
- Die Schlüssel (`'stil'`, `'land'`) sind **stabil**: Sie landen später
  in CSV-Spalten und in gespeicherten Ansichten. Umbenennen bricht beides.

## 3. Welche Kennzahlen

| Kennzahl | Quelle | Anmerkung |
|---|---|---|
| Check-ins | Anzahl Zeilen | vorhanden |
| Verschiedene Biere / Brauereien / Stile / Länder / Orte | Mengen | vorhanden |
| Menge in Litern | `volumeMl`, sonst geschätzt | vorhanden, Schätzanteil wird ausgewiesen |
| Ø Bewertung | nur bewertete | vorhanden — **und seit 0.10.12 ehrlich**, weil unbewertete Check-ins wirklich unbewertet sind |
| Anteil alkoholfrei | `isAlcoholFree` | vorhanden |
| **Neue Biere** | erster Check-in je `beerId` im Zeitraum | **neu** — die Kennzahl, die zur Produktvision passt |
| **Reinalkohol** | `volumeMl × abv` | **neu**, braucht `abv` in `CheckinFacts` — siehe Punkt 6 |
| **Ø je Woche** | Check-ins ÷ Wochen im Zeitraum | **neu**, macht Zeiträume vergleichbar |

## 4. Welche Aufteilungen

Vorhanden: **Land · Stil · Gebinde · Brauerei.**

Neu, in dieser Reihenfolge des Nutzens:

1. **Wochentag** — „Freitag ist dein Bierabend". Reine Erinnerung, kostet
   nur eine Zeile.
2. **Monat/Jahreszeit** — Weißbier im Sommer, Bock im Winter. Der
   vorhandene Verlauf zeigt *wie viel wann*, nicht *was wann*.
3. **Region/Stadt** (`breweries.city`) — für eine DACH-App interessanter
   als das Land.
4. **Bewertung** (1–5 Sterne) — „was gibst du eigentlich für Noten?"
5. **Ort** (Gasthaus) — **nur über `venueId`**, nie über den Namen. Der
   Name ist am Check-in denormalisiert; Schreibvarianten würden dieselbe
   Wirtschaft mehrfach auflisten. Freitext-Orte fallen in „ohne Angabe".
6. **Allein oder in Runde** (`sessionId != null`) — sagt etwas über die
   App selbst: Ist BrewMates ein Tagebuch oder ein Treffpunkt?

## 5. Wie es angezeigt wird

Der Bildschirm wächst sonst mit jeder Aufteilung um einen Block. Deshalb
ändert sich der Aufbau:

```
┌──────────────────────────────────────────────┐
│  Zeitraum  [Monat][Jahr][Alles][Von–Bis]     │  ← Auswahl bleibt oben
│  Filter    [Land ▾] [Stil ▾]        (aktiv 2)│
├──────────────────────────────────────────────┤
│  ┌────────┐ ┌────────┐ ┌────────┐            │
│  │  42    │ │ 18,5 l │ │  12    │  Kennzahlen│
│  │Check-in│ │  Menge │ │  neue  │  als Karten│
│  └────────┘ └────────┘ └────────┘            │
│  ↳ dieser Monat: 42  ·  letzter: 37  (+5)    │  ← Vergleich
├──────────────────────────────────────────────┤
│  Aufteilung: (Stil) (Land) (Gebinde) (Wo.tag)│  ← eine Chip-Reihe
│  ▇▇▇▇▇▇▇▇▇▇▇▇  Märzen           14           │
│  ▇▇▇▇▇▇▇▇      Pils              9           │
│  ▇▇▇▇          Weißbier          5           │
├──────────────────────────────────────────────┤
│  Verlauf  ▁▂▅▇▃▂▁▄                           │
└──────────────────────────────────────────────┘
```

**Eine Aufteilung zur Zeit, per Chip gewählt** — statt vier
untereinander. Das hält den Bildschirm konstant lang, egal wie viele
Aufteilungen dazukommen, und es macht das Vergleichen leichter: Man sieht
dieselbe Fläche, nur anders geschnitten.

**Weiterhin keine Diagramm-Bibliothek.** Balken aus `Container`-Breiten,
Verlauf als Reihe schmaler Balken. Das hat auf fünf Plattformen
funktioniert; ein Paket, das auf einer davon klemmt, wäre ein schlechter
Tausch für rundere Ecken.

**Barrierefreiheit:** Jeder Balken bekommt ein `Semantics`-Label mit
Beschriftung und Wert — ein Balken ohne Zahl ist für Screenreader nichts.

## 6. Alkohol — die heikle Frage

Mit `abv` und `volumeMl` ließe sich **Reinalkohol** ausrechnen
(Milliliter Ethanol, oder „Standardgläser" à 20 g). Das ist die
aussagekräftigste Zahl über den eigenen Konsum — und zugleich die
einzige in diesem Dokument, die einen Menschen unangenehm treffen kann.

Die Produktvision sagt: **Vielfalt und Erinnerung, nicht Leistung.** Eine
Alkoholzahl verstößt nicht dagegen — sie ist kein Wettbewerb —, aber sie
ist auch keine Erinnerung. Sie ist ein Spiegel.

**Vorschlag, zur Entscheidung des Menschen:**

- Anzeigen, aber **nicht auf der Startkachel**: eine eigene Karte weiter
  unten, sachlich beschriftet („Reinalkohol im Zeitraum"), mit einem
  Satz, was die Zahl bedeutet und woher sie kommt.
- **Nie** als Serie, Ziel, Rekord oder Vergleich mit anderen.
- **Nie** als Warnung oder Bewertung — die App ist kein Gesundheitsdienst
  und soll auch nicht so tun.
- Der Schätzanteil muss dabeistehen: Wo `volumeMl` geschätzt ist, ist die
  Alkoholzahl es auch.

⚠️ **Das ist eine Produktentscheidung, keine technische.** Sie wurde
vorgelegt, nicht getroffen (Regel K in `CLAUDE.md`).

### ✅ Entschieden am 2026-09-04: anzeigen, wie oben vorgeschlagen

Umgesetzt in `domain/statistics/alcohol.dart` und der Karte
`_AlcoholCard` in `stats_screen.dart`:

- **Eigene Karte unter den Aufteilungen**, nicht bei den Kennzahl-Kacheln.
- **Milliliter und Gramm** reiner Alkohol, dazu ein Satz, wie die Zahl
  entsteht („Füllmenge mal Alkoholgehalt").
- **Kein Vergleich mit dem Vorzeitraum**, keine Farbe, kein Pfeil, keine
  Einordnung, keine Warnung.
- **Beide Lücken stehen dabei:** wie viele Füllmengen geschätzt sind und
  bei wie vielen Check-ins gar kein Alkoholgehalt hinterlegt ist. Ab
  einem Drittel Lücke sagt die Karte deutlicher, dass die Zahl eher eine
  Untergrenze als eine Summe ist.
- **Bewusst keine „Standardgläser".** Die Normierung auf 10–20 g stammt
  aus der Suchtprävention; sie macht aus einer Angabe eine Bewertung.
  Milliliter und Gramm sind nachvollziehbar und sagen nichts über den
  Menschen.
- Fehlt der Alkoholgehalt bei **allen** Check-ins des Zeitraums,
  erscheint die Karte gar nicht.

## 7. Export (seit 0.10.19)

Wie unter Punkt 2 vorhergesagt, war es fast geschenkt: Weil die Kette
`Liste → Auswahl → Aufteilung → Zahlen` sauber getrennt ist, ist CSV nur
ein anderer Ausgang an derselben Stelle. Der eigentliche Aufwand lag
woanders — beim Ausliefern der Datei und bei den Zeichen, die eine
Tabelle zerreißen.

**Zwei Exporte**, über das Tabellen-Symbol oben rechts:

1. **Rohdaten** — eine Zeile je Check-in, fünfzehn Spalten: Datum,
   Uhrzeit, Bier, Stil, alkoholfrei, Alkoholgehalt, Brauerei, Land,
   Stadt, Ort, Menge, Gebinde, Bewertung, in Runde, Notiz. Das ist der
   Datenauszug für den Menschen („meine Daten gehören mir") und die
   Grundlage für jede Auswertung, die diese App nicht anbietet.
2. **Diese Auswertung** — eine Zeile je Balken der gewählten Aufteilung,
   mit Anzahl und Anteil.

Beide enthalten **nur eigene** Check-ins, und beide nehmen genau die
Auswahl, die auf dem Bildschirm steht: Zeitraum und Filter kommen aus
derselben Funktion (`auswahl` in `domain/statistics.dart`), die auch die
Balken speist. Zwei Kopien derselben Bedingung liefen früher oder später
auseinander, und der Unterschied fiele niemandem auf — die Datei sieht ja
immer plausibel aus.

### Die Kleinigkeiten, an denen CSV scheitert

- **`sep=;` in der ersten Zeile.** Kein Standard, aber ohne sie zerlegt
  Excel in deutscher Ländereinstellung eine Semikolon-Datei nicht.
- **UTF-8 mit BOM**, sonst wird „Gösser" zu „GÃ¶sser".
- **Felder in Anführungszeichen**, sobald ein Semikolon, ein
  Anführungszeichen oder ein Zeilenumbruch darin steht; innere
  Anführungszeichen verdoppelt (RFC 4180). Notizen enthalten alle drei.
  Vier der zehn Tests prüfen genau das, einer davon zerlegt die Zeile
  danach so, wie eine Tabellenkalkulation es täte, und zählt die Felder.
- **Zahlen mit Punkt, Datum als ISO.** Maschinenlesbar schlägt hübsch:
  Wer die Datei öffnet, sieht ohnehin die Form seiner Ländereinstellung.
- **Was fehlt, bleibt leer** — nicht `0` und nicht `null`. Eine 0 bei
  „Bewertung" wäre eine Aussage, die niemand getroffen hat.

### Wohin die Datei geht

| Plattform | Ergebnis |
|---|---|
| Web | echter Download über einen Blob (`core/export/datei_ausgeben_web.dart`) |
| Android, Desktop | Text in der **Zwischenablage** |

Dasselbe Muster wie bei der Datenbankverbindung: eine Schnittstelle, zwei
Umsetzungen, bedingter Import — `dart:io` ist in `app/lib/` verboten, und
`package:web` gibt es auf der VM nicht.

**Die Zwischenablage ist kein Notbehelf aus Bequemlichkeit.** Eine Datei
auf Android abzulegen hieße `dart:io` plus ein Teilen-Paket, und ein
neues Plugin ist in dieser Toolchain die teuerste Änderung, die es gibt
(`CLAUDE.md`, gepinnte Pakete: `mobile_scanner`/AGP). Eingefügt in eine
Tabellenkalkulation kommt dasselbe heraus. Sollte `share_plus` später aus
anderem Grund dazukommen, ist es hier eine Zeile.

## 8. Reihenfolge

| Schritt | Was | Warum zuerst |
|---|---|---|
| 1 | `abv` und `breweryCity` in `CheckinFacts` | Eine Stelle, macht 3 und 4 möglich |
| 2 | Registry für Aufteilungen und Kennzahlen, Tests mitziehen | Danach ist alles Weitere Konfiguration |
| 3 | Bildschirm auf Chip-Auswahl umbauen | Hält die Länge konstant |
| 4 | Neue Aufteilungen: Wochentag, Region, Bewertung, allein/Runde | Je eine Zeile |
| 5 | Neue Kennzahlen: neue Biere, Ø je Woche, Vergleich zum Vorzeitraum | Der Maßstab, der heute fehlt |
| 6 | Freier Zeitraum von–bis | Braucht 2 (Zeitraum als Wertobjekt statt Enum) |
| 7 | Reinalkohol — **erst nach Entscheidung** | Siehe Punkt 6 |
| ~~8~~ | ~~CSV-Export~~ — **erledigt mit 0.10.19**, und tatsächlich fast geschenkt: Der Aufwand lag beim Ausliefern und bei den Zeichen, die eine Tabelle zerreißen | ✅ zehn Tests |
| 9 | Crew-Auswertung auf dieselbe Maschinerie | Erst wenn 2 steht |

## 9. Was bewusst nicht kommt

- **Kein Vergleich mit anderen Nutzern.** Keine Rangliste, kein „du
  trinkst mehr als 80 %". Das ist der Punkt, an dem aus Erinnerung
  Wettbewerb wird.
- **Keine Ziele und keine Serien auf Menge.** Die Wochen-Serie zählt
  bewusst Wochen *mit Eintrag*, nicht Tage — sie belohnt Festhalten, nicht
  Trinken. Dabei bleibt es.
- **Keine Auswertung fremder Check-ins.** Vom Feed liegt nur das geladene
  Fenster vor; eine Statistik darüber wäre falsch, nicht bloß
  unvollständig.
- **Keine Prognosen.** „Du wirst dieses Jahr X Liter erreichen" ist eine
  Zielvorgabe mit anderem Vorzeichen.

## Offene Punkte / Ideen

- Eigene Füllmenge eintippen, wenn keiner der Chips passt
- „Dein Bierjahr" als teilbarer Jahresrückblick — Stufe 2 ist die
  Grundlage dafür
- Gespeicherte Ansichten („mein Standardblick": Zeitraum + Filter +
  Aufteilung) — sinnvoll erst ab Schritt 6

---

## 10. Was davon gebaut ist (0.10.14-beta)

**Der Umbau aus Punkt 2 steht.** Aufteilungen und Kennzahlen sind Listen
statt Felder:

- `domain/statistics/dimensions.dart` — acht Aufteilungen als `const`-Liste
- `domain/statistics/measures.dart` — neun Kennzahlen, ebenso
- `domain/statistics.dart` — `computeStats` liefert
  `Map<String, List<StatSlice>>` und `Map<String, double>` statt benannter
  Felder; `CheckinStats.slices(key)` und `.value(key)` sind der Zugriff

Eine neue Aufteilung ist damit tatsächlich **eine Zeile**: Der Bildschirm
zeigt sie, ohne dass jemand ihn anfasst.

| Schritt aus Punkt 8 | Stand |
|---|---|
| 1 — `abv`, `breweryCity` in `CheckinFacts` | ✅ dazu `sessionId`; **keine Migration nötig**, alle drei Spalten gab es lokal längst |
| 2 — Registry für Aufteilungen und Kennzahlen | ✅ |
| 3 — Bildschirm auf Chip-Auswahl | ✅ eine Aufteilung zur Zeit |
| 4 — Wochentag, Region, Bewertung, allein/Runde | ✅ alle vier |
| 5 — neue Biere, Ø je Woche, Vergleich zum Vorzeitraum | ✅ |
| 6 — freier Zeitraum von–bis | ✅ `StatsPeriod` als Wertobjekt |
| 7 — Reinalkohol | ✅ entschieden am 2026-09-04 und gebaut (Punkt 6) |
| 8 — CSV-Export | ✅ fertig (0.10.19) |
| 9 — Crew-Auswertung auf dieselbe Maschinerie | ⏸ offen |

### Was beim Bauen anders kam als gedacht

**`StatsRange` ist nicht verschwunden, sondern eingewickelt.** Der Plan
sagte „Zeitraum als Wertobjekt statt Enum". Das Enum trägt aber weiterhin
die drei Knöpfe, die 95 % der Aufrufe ausmachen; `StatsPeriod` umschließt
es und kann zusätzlich von–bis. So bleibt `StatsPeriod.preset(…)` const
und die Segmented-Button-Auswahl einfach.

**Der Vergleichszeitraum rechnet sich selbst.** `computeStats` ruft sich
einmal für das Davor auf (`withPrevious: false`, sonst liefe es endlos in
die Vergangenheit). Ein leerer Zeitraum **behält** seinen Vergleich:
„diesen Monat noch nichts, im Vormonat waren es zwölf" ist eine Aussage,
„nichts" allein nicht.

**„Neu" wird ungefiltert bestimmt.** Ein Bier ist nicht dadurch neu, dass
man gerade den Stilfilter gesetzt hat. Die Menge der früher getrunkenen
Biere entsteht deshalb über **alle** Check-ins vor dem Zeitraum, nicht
über die gefilterten. Ohne eingegrenzten Zeitraum blendet sich die
Kennzahl ganz aus — über die gesamte Zeit war jedes Bier einmal neu, die
Zahl wäre eine Dublette von „verschiedene Biere".

**Deutsche Material-Dialoge.** Der freie Zeitraum braucht
`showDateRangePicker`, und der sprach Englisch: Die App hatte nie
`flutter_localizations` eingebunden. Jetzt schon — ein SDK-Paket, keine
Fremdabhängigkeit. Nebenwirkung ist erwünscht: Alle Material-Dialoge der
App sind damit deutsch.

**Der Bildschirm hatte keinen Test.** Geprüft war nur die Rechnung
darunter. Das trug, solange vier feste Blöcke untereinander standen; seit
die Aufteilung per Chip gewählt wird, ist die Verbindung zwischen Auswahl
und Anzeige selbst eine Behauptung. `test/stats_screen_test.dart` prüft
sie — und gleich mit, ob Trefferflächen, Beschriftungen und Kontrast
stimmen (siehe [docs/14](../14-barrierefreiheit.md)).

**Widget-Tests laufen auf 800×600.** Auf dieser Fläche liegen die Chips
außerhalb des Ausschnitts: Der erste Tipp darauf ging ins Leere, und der
Test meldete einen Fehler, den es in der App nicht gibt. Beide
Statistik-Tests setzen deshalb ein Telefonformat.
