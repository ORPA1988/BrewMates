# 47 Profil-Übersicht

> **Status:** 🟢 fertig — der Profil-Reiter führt oben zu den vier Dingen,
> die man wirklich sucht, und jede Zahl darunter erzählt beim Antippen,
> woraus sie besteht.
> **Seit:** 0.10.31-beta · **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Der Profil-Reiter war eine Ablage. Er zeigte oben neun Zahlen ohne jede
Funktion — antippen tat nichts — und schob die vier Dinge, für die man
ihn überhaupt öffnet, nach unten in eine Reihe aus sechs gleich
aussehenden Listeneinträgen: **Freunde** (mitsamt offener Anfragen!),
**Tagebuch**, **Statistik** und **Challenges**.

Das ist zweimal derselbe Fehler. Oben steht, was gut aussieht; unten
steht, was gebraucht wird. Und eine Zahl, die man antippen kann, ohne
dass etwas passiert, lehrt einen Menschen, es nicht mehr zu versuchen.

Zwei Fragen sollen ohne Scrollen beantwortet sein:

1. **Wo muss ich hin?** — Challenges, Freunde, Tagebuch, Statistik
2. **Was steckt hinter dieser Zahl?** — „12 Stile" ist eine Behauptung,
   „Märzen 14×, Pils 9×, Weißbier 7×" ist eine Auskunft

Woran man merkt, dass es funktioniert: Man öffnet den Reiter wegen einer
offenen Freundschaftsanfrage und sieht sie sofort — statt an neun
Zahlen, einer Heatmap und einer Vertrauensstufe vorbeizuscrollen.

## Funktion (Nutzersicht)

1. **Kopf** — Avatar, Name, Bio, Bearbeiten. Unverändert
2. **Schnellzugriff:** vier große Kacheln, zwei mal zwei. Jede trägt
   eine Zweitzeile, die den heutigen Stand sagt, nicht nur den Namen:

   | Kachel | Zweitzeile |
   |---|---|
   | 🏆 Challenges | die laufende Challenge, sonst „nichts läuft gerade" |
   | 👥 Freunde | Anzahl — und **offene Anfragen zuerst**, farbig hervorgehoben |
   | 📖 Tagebuch | wann der letzte Check-in war („heute", „vor 3 Tagen") |
   | 📊 Statistik | Check-ins insgesamt |

3. **Deine Zahlen** — dieselben neun Kacheln wie bisher, aber jede
   **antippbar**. Ein Blatt von unten zeigt, woraus die Zahl besteht:
   die häufigsten Werte als Balken, mit Anzahl, und ein Knopf ins
   passende Vollbild
4. Darunter wie gehabt: Wochen-Heatmap, Abzeichen-Vorschau,
   Vertrauensstufe, Bestenliste
5. **Mehr** — was selten gebraucht wird, steht am Ende beieinander:
   Konto, Wunschliste, Dein Bierjahr
6. **Über** — Version, Datenschutzsatz, Kartenhinweis

**Leerer Zustand:** Ohne Check-ins hat keine Kachel eine Aufschlüsselung.
Das Blatt sagt dann den Satz, der weiterhilft („Noch keine Check-ins —
dein erster wartet"), statt eine leere Liste zu zeigen. Abgemeldet fehlen
Freundeszahl und Vertrauensstufe; die Kacheln bleiben, weil das Tagebuch
auch ohne Konto funktioniert.

## Technische Umsetzung

- **Dateien:** `features/profile/profile_screen.dart` (Aufbau),
  `features/profile/profile_providers.dart` (Provider dieser Funktion),
  `features/profile/widgets/schnellzugriff.dart` (die vier Kacheln),
  `features/profile/widgets/zahlen_kachel.dart` (Kachel + Blatt)
- **Datenmodell:** keins. Kein neues Feld, keine Migration — die
  Funktion ordnet und erklärt, was schon da ist
- **Die Aufschlüsselung kommt aus `domain/statistics.dart`**, nicht aus
  einer zweiten Rechnung. `computeStats` liefert `byDimension`, und
  `dimensions` sagt, welche Aufteilungen es gibt. Zwei neue Einträge
  dort (`beer`, `venue`) decken die Kacheln „Biere" und „Venues" ab —
  **und erscheinen zugleich als Chips in der Statistik**, weil die Liste
  genau dafür gebaut ist ([Funktion 20](20-feed-statistiken.md))
- **Abhängigkeiten:** keine neuen Pakete

### Warum jede Kachel ein Blatt bekommt und nicht bloß einen Sprung

Der naheliegende Weg wäre, jede Kachel in den passenden Bildschirm
springen zu lassen. Er scheitert an der Hälfte der Kacheln: „Venues",
„Sessions" und „Wochen-Serie" haben kein Ziel, in das ein Sprung sinnvoll
führte. Ein Raster, in dem sechs von neun Kacheln reagieren und drei
nicht, ist schlechter als das tote Raster von vorher — es sieht aus wie
ein Fehler.

Das Blatt kann dagegen **immer** etwas sagen: eine Aufschlüsselung, wo es
eine gibt, und sonst wenigstens den Satz, was die Zahl bedeutet. Wo ein
Vollbild existiert, steht unten der Knopf dorthin.

## Modularität

- **Hängt ab von:** Statistiken ([20](20-feed-statistiken.md)) für die
  Aufschlüsselung, Abzeichen ([11](11-abzeichen.md)), Challenges
  ([12](12-challenges.md)), Freunde ([08](08-freunde.md)),
  Wochen-Heatmap ([45](45-wochen-heatmap.md))
- **Wird gebraucht von:** nichts — die Funktion ist ein Einstieg, kein
  Fundament. Alle Ziele sind über ihre eigenen Routen erreichbar
- **Ausbauen:** `widgets/schnellzugriff.dart` und
  `widgets/zahlen_kachel.dart` löschen, im Bildschirm die alte Liste aus
  `ListTile`s wiederherstellen, `profile_providers.dart` entfernen. Die
  zwei Dimensionen `beer` und `venue` dürfen bleiben — sie stehen für
  sich

## Plattformen

Überall gleich. Das Raster nimmt bei ≥ 800 px vier Spalten statt zwei,
der Schnellzugriff bleibt bei zwei — vier nebeneinander wären auf einem
breiten Fenster Knöpfe ohne Gewicht. Das Blatt ist ein
`showModalBottomSheet` und scrollt in sich, damit eine lange Liste auf
einem kleinen Gerät nicht über den Rand läuft.

## Skalierung

Die Aufschlüsselung rechnet über alle eigenen Check-ins — dieselbe
Grenze wie die Statistik selbst, und dieselbe Antwort: Bei einigen
tausend gehört die Summenbildung nach SQL, und der Schnitt ist dafür
vorbereitet (`computeStats` bekommt nur eine Liste). Gerechnet wird
**erst beim Öffnen des Blatts**, nicht beim Aufbau des Reiters — neun
Aufschlüsselungen im Voraus wären neun Durchläufe für einen, den jemand
ansieht.

## Umsetzungsstatus

Vollständig.

Abgesichert durch `test/profil_uebersicht_test.dart`: dass der
Schnellzugriff über den Zahlen steht, dass offene Anfragen dort
auftauchen, dass jede Zahlen-Kachel ein Blatt öffnet, dass das Blatt
ohne Check-ins den erklärenden Satz zeigt statt einer leeren Liste, und
dass die Wege nach unten (Konto, Wunschliste, Bierjahr) erhalten
bleiben. Die zwei neuen Dimensionen sind in `test/statistics_test.dart`
mitgeprüft.

## Umsetzungsplan

1. ~~Dokument~~ — erledigt
2. ~~Dimensionen `beer` und `venue`~~ — erledigt
3. ~~Schnellzugriff, Zahlen-Kachel, Blatt~~ — erledigt
4. ~~Reiter neu ordnen~~ — erledigt
5. ~~Tests~~ — erledigt

## Offene Punkte / Ideen

- Die Reihenfolge des Schnellzugriffs ist fest. Sie nach Nutzung zu
  sortieren wäre naheliegend — und würde die Kacheln unter dem Daumen
  wandern lassen, was schlechter ist als eine feste Ordnung
- „Sessions" ist die einzige Kachel ohne echte Aufschlüsselung; das Blatt
  erklärt dort nur die Zahl. Eine Liste der letzten Runden wäre möglich,
  gehört aber eher in den Feed
