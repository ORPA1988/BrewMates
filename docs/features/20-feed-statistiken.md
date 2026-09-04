# 20 Statistiken & Auswertung

> **Status:** 🟢 Stufe 1 fertig — eigener Bereich mit Mengen,
> Aufteilungen, Zeitraum und Filtern. **Stufe 2 geplant** (siehe unten):
> mehr Dimensionen, freier Zeitraum, Export.
> **Seit:** 0.9.15-beta · **Zuletzt geprüft:** 2026-09-04
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

Abgesichert durch `test/statistics_test.dart` (15 Tests): Summen,
Schätzung fehlender Mengen, Zeiträume, Filter einzeln und kombiniert,
Sortierung samt Gleichstand, Zählung verschiedener Biere/Brauereien/Orte,
Durchschnitt nur über Bewertetes, Monatsverlauf, Formatierung.

---

# Ausbaustufe 2 — der Plan (2026-09-04)

Stufe 1 beantwortet „wie viel und wovon". Sie tut das gut, aber sie ist
**starr**: Vier Aufteilungen, drei Zeiträume, zwei Filter — alles fest
verdrahtet. Jede neue Frage kostet heute eine Änderung an vier Stellen
(Eingabetyp, Auswertung, Ergebnisklasse, Bildschirm) plus Tests.

Deshalb steht am Anfang von Stufe 2 kein neues Diagramm, sondern **ein
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

⚠️ **Das ist eine Produktentscheidung, keine technische.** Sie wird
vorgelegt, nicht getroffen (Regel K in `CLAUDE.md`).

## 7. Export (nachrangig, aber vorgedacht)

Ausdrücklich **nicht hoch priorisiert** — aber die Architektur aus Punkt 2
macht ihn fast geschenkt: Wenn die Kette
`Liste → Auswahl → Aufteilung → Zahlen` sauber getrennt ist, ist CSV nur
ein anderer Ausgang an derselben Stelle.

Zwei Exporte, beide sinnvoll:

1. **Rohdaten** — eine Zeile je Check-in, alle Felder aus `CheckinFacts`
   plus Bier- und Brauereiname. Das ist der Datenauszug für den Menschen:
   „meine Daten gehören mir", und die Grundlage für jede Auswertung, die
   die App nicht anbietet (Excel, Tabellenkalkulation).
2. **Auswertung** — eine Zeile je Balken der gewählten Aufteilung. Für
   den, der schnell eine Tabelle in eine Nachricht kopieren will.

Umsetzungshinweise:

- Trennzeichen **Semikolon** und `sep=;` in der ersten Zeile: Excel in
  deutscher Ländereinstellung zerlegt Komma-CSV sonst nicht.
- **UTF-8 mit BOM**, sonst werden Umlaute in Excel zu Kraut.
- Zahlen mit Punkt als Dezimaltrenner in der Datei, Datum als ISO
  (`2026-09-04`) — maschinenlesbar schlägt hübsch.
- **Kein `dart:io`** (Regel G). Auf allen Plattformen über
  `share_plus`/Speichern-Dialog bzw. im Browser als Blob-Download.
- Der Export enthält **nur eigene** Check-ins. Fremde Daten mitzugeben
  wäre eine stille Weitergabe.

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
| 8 | CSV-Export | Nachrangig, fällt aus 2 fast heraus |
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
