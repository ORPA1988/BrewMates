# 46 Dein Bierjahr

> **Status:** 🟡 teilweise — die Seite steht überall, das **Bild
> herunterladen** geht nur im Browser. Auf Android und Desktop nennt die
> App den Weg (Bildschirmfoto), statt einen Knopf anzubieten, der nichts
> tut.
> **Seit:** 0.10.27-beta · **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Ein Jahr Check-ins liegt in der App, und niemand sieht es je am Stück.
Die Statistik kann alles zeigen, verlangt aber, dass man weiß, wonach man
sucht. Der Rückblick ist das Gegenteil: eine Seite, die man aufschlägt
und weitergibt.

Roadmap-Punkt [#167](https://github.com/ORPA1988/BrewMates/issues/167).
Der Zusatz „ohne dass jemand die App installieren muss" ist der Kern —
deshalb ein **Bild** und keine geteilte Seite: Ein PNG geht durch jeden
Chat, überlebt jeden Serverumzug und verlangt von niemandem ein Konto.

**Was hier bewusst fehlt:** kein Ranking, kein Vergleich mit anderen,
kein „mehr als letztes Jahr". Ein Rückblick, der einem sagt, man habe
sich gesteigert, ist keine Erinnerung, sondern eine Aufforderung — bei
einer App, die Alkohol zählt, die falsche.

## Funktion (Nutzersicht)

**Profil → „Dein Bierjahr".**

Oben steht das Jahr; ab dem zweiten Jahr lässt es sich im Menü der
Titelleiste wechseln. Darunter die Karte, die auch das Bild wird:

- „Mein Bierjahr 2026" als Überschrift
- Check-ins · verschiedene Biere · Brauereien · Stile
- „zum ersten Mal" — Biere, die in keinem früheren Jahr dran waren
- das häufigste Bier und der liebste Stil
- verschiedene Orte und Runden mit anderen
- der Monat, in dem am meisten los war
- die längste Folge von Wochen mit mindestens einem Check-in
- darunter die Wochen-Heatmap des Jahres
  ([Funktion 45](45-wochen-heatmap.md))

Ein Knopf **„Als Bild speichern"** rendert genau diese Karte als PNG in
dreifacher Auflösung. Darunter steht, was drauf ist: *„Das Bild zeigt
nur, was hier steht — keinen Namen, keine Orte, keine Uhrzeiten."* Ein
Bild, das man weitergibt, ohne zu wissen, was drauf ist, wäre genau die
Art Überraschung, die eine App sich nicht leisten darf.

**Sonderfälle:** Für ein Jahr ohne Check-ins erscheint kein leeres Bild,
sondern ein Satz — und kein Knopf. Wo kein Download möglich ist
(Android, Desktop), sagt die Meldung nach dem Tipp, dass ein
Bildschirmfoto dasselbe bringt. Offline und abgemeldet funktioniert
alles; die Daten sind lokal.

## Technische Umsetzung

- **Dateien:**
  - `app/lib/domain/jahresrueckblick.dart` — die Rechnung
    (`jahresrueckblick`, `rueckblickJahre`, `Rueckblickzeile`)
  - `app/lib/features/rueckblick/rueckblick_screen.dart` — Seite, Bild,
    Knopf
  - `app/lib/core/export/bild_ausgeben*.dart` — Plattformweiche für PNG
  - `app/test/jahresrueckblick_test.dart`,
    `app/test/rueckblick_screen_test.dart`
- **Datenmodell:** keins. Gerechnet wird aus `myDiaryProvider` über
  `CheckinFacts` (`core/checkin_facts.dart`) — keine Migration, keine
  Spalte, kein Serveraufruf.
- **Sicherheit:** Die Daten verlassen das Gerät nur, wenn der Mensch das
  Bild weitergibt, und dann nur das, was auf dem Bild steht. Kein Name,
  keine Ortsangabe, kein Zeitstempel.
- **Abhängigkeiten:** Flutter, Riverpod, `package:web` (nur im
  Web-Zweig). **Kein neues Paket.**

Das Bild entsteht über `RepaintBoundary.toImage(pixelRatio: 3)`. Die
Grenze umschließt genau die Karte und nicht den Bildschirm: Titelleiste
und Knopf gehören nicht auf ein Bild, das jemand weitergibt. Der
Hintergrund ist ausdrücklich gesetzt — ein PNG ohne Grund wird in jedem
zweiten Chat schwarz auf schwarz dargestellt.

`bild_ausgeben.dart` folgt demselben Muster wie `datei_ausgeben.dart`
(bedingter Import, `dart:io` bleibt draußen): Web schreibt einen Blob und
klickt einen unsichtbaren Link, alles andere gibt `false` zurück, und die
Oberfläche sagt daraufhin das Richtige.

Bei Gleichstand entscheidet die alphabetische Reihenfolge, welches Bier
das „häufigste" ist. Das ist nicht Kosmetik: Ein Rückblick, der beim
zweiten Öffnen ein anderes Lieblingsbier nennt, ist kaputt.

## Modularität

- **Hängt ab von:** `data/providers.dart` (`myDiaryProvider`),
  `data/checkin_facts_mapping.dart`, `widgets/wochen_heatmap.dart`,
  `core/export/bild_ausgeben.dart`.
- **Wird gebraucht von:** niemandem.
- **Ausbauen:** Route `/profile/rueckblick`, den `ListTile` im Profil,
  den Ordner `features/rueckblick/`, `domain/jahresrueckblick.dart` und
  die beiden Tests löschen. `bild_ausgeben*.dart` kann bleiben oder mit
  weg — es hat sonst keine Aufrufer.

## Plattformen

| Plattform | Stand |
|---|---|
| Web | vollständig — Seite und PNG-Download |
| Android | Seite ja, Download nein (Bildschirmfoto) |
| Windows/macOS/Linux | Seite ja, Download nein |
| iOS | wie Android (ungetestet, kein Gerät) |

Dass Android leer ausgeht, ist eine Toolchain-Entscheidung, keine
Nachlässigkeit: Ein Bild dort abzulegen oder zu teilen hieße `dart:io`
plus ein Teilen-Paket, und ein neues Plugin ist in dieser gepinnten Kette
die teuerste Änderung, die es gibt (CLAUDE.md, Abschnitt 6). Ein
Bildschirmfoto liefert dasselbe Ergebnis mit einem Griff, den ohnehin
jeder kennt — und die Seite ist genau dafür gebaut: Sie passt auf einen
Bildschirm.

## Skalierung

Ein Durchlauf über alle eigenen Check-ins plus ein paar Mengen — bei
10.000 Zeilen nichts, was auffällt. Der Engpass säße davor:
`myDiaryProvider` lädt das ganze Tagebuch. Das ist schon heute so; wird
es je gestückelt geladen, braucht der Rückblick eine eigene Abfrage,
sonst zeigt er stillschweigend zu wenig — dasselbe gilt für
[Funktion 45](45-wochen-heatmap.md).

Das PNG wächst mit der Bildschirmbreite (dreifache Auflösung). Auf einem
sehr breiten Fenster wird es entsprechend groß; ein Deckel wäre die
naheliegende Nachbesserung, falls jemand über Dateigrößen stolpert.

## Umsetzungsstatus

Fertig, mit der genannten Einschränkung beim Download. Zwölf Tests:
neun auf die Rechnung (Jahresgrenzen, „zum ersten Mal", Gleichstand,
Einzahl/Mehrzahl, längste Serie), drei auf den Bildschirm (leerer
Zustand, Zahlen, Datenschutzhinweis).

## Umsetzungsplan

Erledigt:

1. `jahresrueckblick` mit Tests. ✅
2. `bild_ausgeben`-Weiche nach Vorbild `datei_ausgeben`. ✅
3. Seite, Bildbereich, Knopf, Verweis im Profil. ✅

## Offene Punkte / Ideen

- **Teilen statt herunterladen** auf Android — braucht ein Plugin und
  damit einen Toolchain-Schritt. Erst zusammen mit einem ohnehin
  fälligen Upgrade.
- **Deckel für die Bildgröße** auf breiten Fenstern.
- **Mehrere Jahre nebeneinander.** Naheliegend, aber ein Rückblick, der
  zwei Jahre vergleicht, ist wieder eine Wertung — bewusst offen
  gelassen.
- **Ein Wort statt einer Zahl.** „Dein Jahr war ein Weizenjahr" liest
  sich besser als „37 Check-ins". Braucht Formulierungen, die nicht nach
  Automat klingen; später.
