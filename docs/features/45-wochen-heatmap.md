# 45 Wochen-Heatmap

> **Status:** 🟢 fertig — 52 Felder im Profil, eines je Woche; je mehr
> Check-ins, desto kräftiger.
> **Seit:** 0.10.26-beta · **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Die Wochen-Serie stand bisher als Zahl im Profil: „🔥 7". Das sagt, wie
es **gerade** läuft, und sonst nichts. Wie das Jahr war — der Sommer, in
dem jede Woche etwas war, die drei Wochen im November, in denen gar
nichts war — steht in derselben Datenlage und war nirgends zu sehen.

Genau das ist der Teil, über den man redet. Roadmap-Punkt
[#166](https://github.com/ORPA1988/BrewMates/issues/166).

Woran man merkt, dass es funktioniert: Man schaut hin, ohne es zu
müssen. Woran man merkt, dass es schiefgegangen wäre: Es fühlte sich an
wie eine Aufgabe, die man erfüllen muss.

**Wochen, keine Tage** — dieselbe Entscheidung wie bei der Serie selbst.
Ein Kalender mit 365 Feldern, von denen jedes leere ins Auge sticht, ist
ein täglicher Trinkanreiz. Ein Feld je Woche ist ein Rückblick. Das ist
hier keine Geschmacksfrage: Die App zählt Alkohol, und eine Darstellung,
die zum Lückenfüllen einlädt, wäre ein Produktfehler.

## Funktion (Nutzersicht)

Im Profil, direkt unter den Kacheln, steht **„Dein Jahr"**: vier Zeilen
zu je dreizehn Feldern — ein Quartal je Zeile, 52 Wochen insgesamt,
älteste links oben, laufende Woche rechts unten.

- **Leeres Feld:** in dieser Woche kein Check-in.
- **Vier Farbstufen:** relativ zur eigenen besten Woche, nicht zu einer
  fremden Messlatte. Wer im Schnitt zwei Check-ins hat, soll seine
  Fünf-Wochen sehen.
- **Zeigen (Maus) oder langes Drücken (Telefon)** nennt Woche und Anzahl.
- Darunter ein Satz: „41 von 52 Wochen mit Check-in · kräftigstes Feld =
  beste Woche (6)". Er sagt dasselbe wie das Bild, nur vorlesbar, und er
  nennt die Bezugsgröße, ohne die die Farbstufen nichts bedeuten.

**Sonderfälle:** Ohne einen einzigen Check-in erscheint der Abschnitt gar
nicht — 52 leere Felder sind keine Information, sondern ein Vorwurf. Ein
neues Konto sieht trotzdem die volle Fläche, sobald es einen Check-in
gibt; sie füllt sich, statt mitzuwachsen. Abgemeldet und offline
funktioniert alles, die Daten sind lokal.

## Technische Umsetzung

- **Dateien:**
  - `app/lib/domain/wochen_verlauf.dart` — die Rechnung
    (`wochenVerlauf`, `Wochenwert`)
  - `app/lib/widgets/wochen_heatmap.dart` — die Darstellung
  - `app/lib/features/profile/profile_screen.dart` — Einbau
  - `app/test/wochen_heatmap_test.dart` — beides
- **Datenmodell:** keins. Gerechnet wird aus `myDiaryProvider`, also aus
  den Check-ins, die ohnehin lokal liegen. Keine Migration, keine neue
  Spalte, kein Serveraufruf.
- **Sicherheit:** Es sind die eigenen Daten, sie verlassen das Gerät
  nicht. Fremde Verläufe gibt es nicht und sollen es nicht geben — der
  Vergleich mit anderen läuft anonymisiert über
  [Funktion 42](42-vergleich-mit-anderen.md).
- **Abhängigkeiten:** nur Flutter und Riverpod.

Die Trennung Rechnung/Bild ist der Punkt: Wochengrenzen, Zeitumstellung
und die halb angebrochene laufende Woche sind die Stellen, an denen man
sich verrechnet — und ein Test kann eine Liste prüfen, ein Bild nicht.
Die Wochenlänge wird deshalb über Kalenderarithmetik gerechnet
(`DateTime(jahr, monat, tag - 7 * i)`) und nicht über
`Duration(days: 7 * i)`: An einer Zeitumstellung ist ein Tag 23 oder 25
Stunden lang, und der „Montag" rutscht sonst auf den Sonntagabend.

## Modularität

- **Hängt ab von:** `data/providers.dart` (`myDiaryProvider`).
- **Wird gebraucht von:** niemandem. `domain/streak.dart` bleibt
  unberührt und rechnet weiter seine eigene Zahl.
- **Ausbauen:** Import und den `if (termine.isNotEmpty)`-Block im Profil
  entfernen, die beiden Dateien und den Test löschen. Drei Griffe, keine
  Datenreste.

## Plattformen

Android · Web · Windows · iOS · macOS — überall gleich. Reine
Flutter-Widgets, kein plattformgebundenes Paket, kein `dart:io`. Der
Tooltip löst am Rechner auf Zeigen aus, am Telefon auf langes Drücken;
das macht Flutter selbst.

## Skalierung

Die Fläche ist konstant: 52 Felder, egal wie viele Check-ins dahinter
stehen. Die Rechnung ist ein Durchlauf über die Check-ins des Nutzers
(O(n)) plus 52 Nachschläge — bei 10.000 eigenen Check-ins immer noch
nichts, was auffällt.

Der Engpass säße, wenn überhaupt, davor: `myDiaryProvider` lädt das
gesamte Tagebuch. Das ist schon heute so und keine Folge dieser Funktion
— aber falls das Tagebuch je gestückelt geladen wird, braucht die
Heatmap eine eigene Abfrage („Check-ins der letzten 52 Wochen"), sonst
zeigt sie stillschweigend zu wenig.

## Umsetzungsstatus

Fertig. Sieben Tests decken Wochengrenzen, feste Länge, Zeitpunkte
außerhalb des Zeitraums, den Zusammenfassungssatz, die vorlesbaren
Feldbeschriftungen und den leeren Zustand ab.

## Umsetzungsplan

Erledigt:

1. `wochenVerlauf` mit Tests — Prüfkriterium: 52 Einträge, laufende Woche
   am Ende, Sonntag 23:59 zählt noch in seine Woche. ✅
2. `WochenHeatmap` mit Farbstufen und Semantik. ✅
3. Einbau ins Profil unter den Kacheln. ✅

## Offene Punkte / Ideen

- **Monatsbeschriftung** an den Zeilen. Bewusst weggelassen: Vier Zeilen
  zu dreizehn Wochen sind keine Kalendermonate, und eine Beschriftung,
  die um ein bis zwei Wochen danebenliegt, ist schlechter als keine.
- **Antippen springt in den Feed dieser Woche.** Naheliegend, aber der
  Feed kennt bisher keinen Zeitsprung; das wäre eine eigene Funktion.
- **Zeitraum wählbar** (ein Jahr, zwei Jahre, alles). Erst, wenn jemand
  danach fragt — ein Regler über einem Bild, das man einmal im Monat
  ansieht, ist Zierrat.
