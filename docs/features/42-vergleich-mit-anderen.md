# 42 Vergleich mit anderen BrewMates

> **Status:** 🟡 in Arbeit — Server (0054) und Anzeige stehen; sichtbar
> wird der Vergleich erst ab 20 beitragenden Personen.
> **Seit:** 0.10.16 · **Zuletzt geprüft:** 2026-09-05
>
> Aus Meldung [#146](https://github.com/ORPA1988/BrewMates/issues/146):
> „In der Statistik sollen auch Vergleichswerte zu anderen Nutzern bzw.
> zu Bevölkerungsschichten enthalten sein."

## Die Entscheidung dahinter

**Dieser Punkt stand in der Roadmap unter „Bewusst NICHT übernehmen".**
Die Begründung war die Ticking-Kultur der Vorbilder: Wer Menschen an
Mengen misst, macht aus einem Bierabend einen Wettbewerb — bei Alkohol
heikel. Am 2026-09-05 hat der Mensch entschieden, den Vergleich in
dieser Form dennoch zuzulassen; die Leitplanke ist in
[docs/06](../06-roadmap.md) entsprechend richtiggestellt statt still
umgangen.

**Was aus der alten Begründung bleibt**, ist die Form:

- **Kein Rang, kein Perzentil, kein „besser als 80 %".** Nur zwei Zahlen
  nebeneinander.
- **Keine Namen.** Nie eine Zeile, nie eine Identität — nur Aggregate.
- **Keine Wertung.** Mehr Bier ist nicht mehr wert. Denselben Ton hat
  schon der Vergleich mit dem Vorzeitraum (`_Comparison`): keine Farbe,
  kein Pfeil, kein „besser".

## Was nicht geht — und warum das keine Bequemlichkeit ist

Der Wunsch nannte auch **Gleichaltrige**, die **Umgebung** und die
**Region**. Keines davon ist heute möglich, und zwar nicht aus Aufwand:

| gewünscht | was fehlt |
|---|---|
| Gleichaltrige | Die App kennt **kein Geburtsdatum**. `profiles` hat keine Alterssspalte, und eines zu erheben ist eine Datenschutz-Entscheidung |
| Umgebung / Region | Die App kennt **keinen Wohnort**. Ableiten ließe er sich nur aus Check-in-Orten — also aus einer Standort-Auswertung über Personen, dieselbe Frage |

Beides gehört nach Regel K dem Menschen vorgelegt, bevor es gebaut wird.
Solange es niemand entschieden hat, vergleicht die App mit **allen
anderen** und behauptet nichts Feineres.

## Funktion (Nutzersicht)

Unter den Kennzahlen der Statistik eine Zeile:

> **Im Vergleich** — Die anderen BrewMates haben in diesem Zeitraum im
> Schnitt 7,3 Check-ins und 5 verschiedene Biere — du 12 und 8.

Sind es zu wenige, steht das genauso dort:

> Für einen Vergleich sind es noch zu wenige: 3 andere haben in diesem
> Zeitraum etwas eingetragen.

Ohne Konto oder ohne Verbindung fehlt die Zeile ganz — sie ist ein
Zusatz, keine Bedingung.

## Technische Umsetzung

- **Neu (Server):** Migration `0054_community_vergleich.sql` — die
  Funktion `community_stats(von, bis)` liefert `teilnehmer`,
  `schnitt_checkins` und `schnitt_biere`.
  - **`security definer`**, weil `checkins` RLS trägt: Als Aufrufer
    gerechnet wäre es der Durchschnitt des eigenen Freundeskreises und
    fiele je nach Freundesliste anders aus. Die Funktion gibt
    ausschließlich Aggregate heraus, nie eine Zeile.
  - **Ohne die eigenen Check-ins.** Der eigene Beitrag gehört auf die
    andere Seite des Vergleichs, sonst misst man sich zum Teil an sich
    selbst.
  - **Schwelle 20.** Ein Durchschnitt über wenige ist kein Aggregat,
    sondern eine Auskunft über sie: Bei zwei anderen lässt sich aus dem
    Mittelwert und der eigenen Zahl zurückrechnen, was der andere
    getrunken hat. Darunter liefert die Funktion nur die Anzahl.
  - Die Zahl steht **in der Migration, nicht in `app_config`** — sie zu
    senken soll durch eine Prüfung gehen, nicht durch einen Schalter.
- **Neu (App):** `data/online/api/stats_api.dart` (eigene API-Datei nach
  Regel G), `communityStatsProvider` in `features/stats/stats_providers.dart`,
  `_CommunityVergleich` in `stats_screen.dart`.
- **Die Schwelle prüft der Server, nicht die App.** Eine Grenze, die die
  Oberfläche zieht, ist keine: Ein zweiter Client könnte sie umgehen.

## Modularität

- **Hängt ab von:** Konto (01), Check-ins (02), Statistiken (20)
- **Wird gebraucht von:** nichts
- **Ausbauen:** `_CommunityVergleich` entfernen, Provider und `StatsApi`
  löschen, Funktion `drop`. Die Statistik bleibt vollständig.

## Plattformen

Alle gleich. Der Aufruf ist eine RPC ohne Plattformbezug.

## Skalierung

Die Aggregation läuft über `checkins` im Zeitraum, gruppiert nach Person.
Bei wenigen tausend Nutzern unkritisch; wächst es, gehört ein Index auf
`(created_at)` dazu — den hat 0020 bereits gelegt. Bei sehr vielen
Nutzern wäre eine stündlich aufgefrischte materialisierte Sicht der
nächste Schritt, nicht eine schnellere Abfrage.

## Umsetzungsstatus

Server und Anzeige stehen, abgesichert durch
`supabase/tests/community_vergleich.test.sql` (sieben pgTAP-Tests: Rechte,
Schwelle, Zeitraum) und `test/community_vergleich_test.dart` (vier
Widget-Tests).

**Am 2026-09-05 hatten 3 von 6 Konten überhaupt Check-ins.** Die Funktion
zeigt also zunächst nur den Satz „noch zu wenige". Das ist kein Fehler,
sondern der Sinn der Schwelle.

## Offene Punkte / Ideen

- **Vergleich nach Alter oder Region** — braucht neue personenbezogene
  Daten, siehe oben. Liegt beim Menschen.
- **Median statt Mittelwert.** Robuster gegen einzelne Vielschreiber;
  lohnt sich erst, wenn es genug Daten für einen Unterschied gibt.

## Bewusst nicht

- **Keine Rangliste, kein Perzentil.** Das ist die Grenze, an der aus
  Erinnerung ein Wettbewerb wird.
- **Kein Vergleich mit einzelnen Freunden.** Der wäre nicht anonym —
  und aus „du trinkst mehr als Anna" folgt nichts Gutes.
