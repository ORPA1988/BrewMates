# 40 Check-ins in einer Runde

> **Status:** 🟡 teilweise — die **Sichtbarkeit** steht (0050), die
> Zuordnung beim Einchecken und die Crew-Ansicht folgen.
> **Seit:** 0.10.15-beta · **Zuletzt geprüft:** 2026-09-04
>
> Erweitert [Funktion 07 (Sessions)](07-sessions-und-beacons.md),
> [09 (Crews)](09-crews.md) und [10 (Feed)](10-feed.md). Kein eigener
> Bildschirm — eine Regel, die drei bestehende Funktionen verbindet.

## Zielsetzung

Wer zusammen trinkt, soll das auch zusammen sehen. Heute zerfällt eine
Runde in Einzelteile: Jeder Check-in landet nur bei den Freunden seines
Autors, und wer am selben Tisch sitzt, aber (noch) nicht befreundet ist,
bekommt nichts mit — obwohl er daneben saß.

Das ist die Lücke zwischen dem, was die App verspricht („kommt vorbei"),
und dem, was sie danach zeigt. Eine Runde ist der Moment, in dem sich
Menschen kennenlernen; ausgerechnet dort verlangt die App eine
Freundschaft, die es noch gar nicht gibt.

## Was heute wirklich passiert (Befund 2026-09-04)

Drei Dinge, die die bisherige Doku so nicht sagte:

| | Ist-Zustand |
|---|---|
| **Session-Zuordnung** | Nur für den **Gastgeber**. `getMyActiveSession` verlangt `host_id = ich` — wer bei einem Freund mittrinkt, dessen Check-in trägt keine `session_id` |
| **Crew-Zuordnung** | Nur über `sessions.crew_id`, also **eine** Crew, und nur wenn die Runde ausdrücklich als Crew-Runde gestartet wurde |
| **Sichtbarkeit** | Die App schreibt hart verdrahtet `visibility: 'friends'` |

Daraus folgt ein Fund, den niemand bemerkt hatte: Die `checkins_select`-
Policy trägt seit 0001 einen Zweig für `visibility = 'crew'` — **er
greift nie**, weil die App diesen Wert nirgends schreibt. Die
Crew-Bilanz zeigt deshalb nur Check-ins von Crew-Kollegen, mit denen man
**zusätzlich befreundet** ist. Wer neu in der Crew und mit niemandem
befreundet ist, erscheint in der Bilanz seiner eigenen Crew nicht.

[Funktion 07](07-sessions-und-beacons.md) behauptete „Check-ins während
der Session werden ihr zugeordnet". Das stimmte nur für den Gastgeber und
ist dort richtiggestellt.

## Die Entscheidungen

Beide vom Menschen getroffen am 2026-09-04 (Regel K — Sichtbarkeiten
werden vorgelegt, nicht entschieden):

**Wer sieht einen Check-in aus einer Runde?**
→ **Die Teilnehmer der Runde, sonst niemand Neues.** Wer am selben Tisch
saß, sieht ihn — auch ohne Freundschaft. Die Crew-Zuordnung dient der
Bilanz und der Crew-Ansicht, öffnet aber **nichts** für Mitglieder, die
nicht dabei waren.

Die Alternative — die ganze Crew sieht alles — wurde verworfen. Sie hätte
Bier, Bewertung, Notiz und Foto Leuten gezeigt, die der Einchecker nie
ausgewählt hat und die nicht dabei waren.

**Woran erkennt die App eine Teilnahme?**
→ **An der Zusage** („Ich komme vorbei", `session_participants` mit
`kind = 'joined'`, seit 0047). Ein Signal, das der Mensch selbst setzt
und das der Server prüfen kann. Wer nur zuprostet oder absagt, ist kein
Teilnehmer.

### Der Vorbehalt, der mit dieser Funktion entsteht

Diese Regel ist eine **Voreinstellung, die niemand abwählen kann.** Wer
nicht möchte, dass Mitrundige seine Check-ins sehen, hat heute nur eine
Möglichkeit: nicht einzuchecken.

Das ist vertretbar — man sitzt am selben Tisch, das Bier steht sichtbar
davor — aber es ist eine Entscheidung, die der Mensch treffen können
sollte und heute nicht treffen kann. Deshalb steht seit 2026-09-04 ein
**Sichtbarkeits-Konzept auf Rang 3 der [Roadmap](../06-roadmap.md)**: ein
schlüssiger, bedienbarer Rahmen dafür, wer den eigenen Namen, die eigenen
Check-ins und die eigenen Daten sieht.

**Technisch zwingend ist es jetzt nicht** — und das ist eine Aussage, die
begründet gehört:

- Die Datenstruktur steht bereits: `checkins.visibility` kennt seit 0001
  `friends`, `crew` und `private`. Es fehlt nur die Bedienung, nicht das
  Modell
- Der neue Zweig respektiert `private` ausdrücklich. Sobald jemand diesen
  Wert wählen kann, wirkt er sofort — ohne dass an dieser Migration etwas
  zu ändern wäre
- Es entsteht **keine** Datenstruktur, die einem späteren Konzept im Weg
  stünde. Eine Policy ist eine Regel, kein Schema

Was ein späteres Konzept hier zu klären hat: ob „Teilnehmer sehen mit"
eine eigene Stufe wird, ein Schalter am Check-in, oder eine Voreinstellung
im Profil mit Ausnahmen. Das ist eine Produktfrage, keine technische.

## Funktion (Nutzersicht)

- **Im Feed** erscheinen die Check-ins aller, die zur selben Runde
  gehören — Gastgeber wie Zusagende, unabhängig von Freundschaft
- **Jeder Check-in während einer Runde** wird ihr zugeordnet, egal ob man
  Gastgeber ist oder zugesagt hat. In der Runden-Ansicht steht damit,
  was tatsächlich getrunken wurde
- **Crew-Bilanz:** Eine Runde zählt für **jede** Crew, aus der jemand
  dabei war — nicht mehr nur für die eine, unter deren Namen sie
  gestartet wurde

**Sonderfälle**

- **Privat bleibt privat.** Ein Check-in mit `visibility = 'private'`
  wird auch am Tisch nicht sichtbar. Wer sich ausdrücklich zurückzieht,
  wird durch eine Runde nicht wieder hervorgeholt
- **Absage oder Prost allein** ordnet nichts zu und öffnet nichts
- **Nach der Runde** bleibt die Zuordnung bestehen — sie beschreibt, was
  war. Die Sichtbarkeit endet nicht mit der Runde: Wer dabei war, darf
  sich auch morgen noch ansehen, was getrunken wurde

## Technische Umsetzung

- **Server:** `0050_runden_checkins.sql` — `checkins_select` bekommt
  einen vierten Zweig: sichtbar, wenn der Check-in zu einer Runde gehört,
  in der ich Gastgeber bin **oder** zugesagt habe, und der Check-in nicht
  `private` ist
- **Der Feed brauchte keine Zeile Code.** `friendCheckins()` filtert
  nicht nach Freundschaft, sondern holt alles außer den eigenen
  Check-ins — was zurückkommt, entscheidet allein die RLS. Die
  Policy-Erweiterung wirkt damit unmittelbar im Feed
- **Noch offen (App):** `getMyActiveSession` kennt nur eigene Sessions.
  Für die Zuordnung beim Einchecken muss der Schreibweg auch fremde
  Runden kennen, an denen ich teilnehme
- **Noch offen (Crew):** `crewCheckins()` joint heute über
  `sessions.crew_id`. Für „jede Crew, aus der jemand dabei war" muss die
  Abfrage über die Teilnehmer gehen

### Warum keine neue Tabelle für die Crew-Zuordnung

Naheliegend wäre `checkin_crews (checkin_id, crew_id)`. Dagegen spricht,
dass die Zuordnung **ableitbar** ist: Eine Runde gehört zu den Crews
ihrer Teilnehmer, und beides steht schon in der Datenbank. Eine
gespeicherte Kopie müsste bei jedem Crew-Beitritt und -Austritt
nachgezogen werden — und läuft irgendwann auseinander.

Der Preis der Ableitung: Tritt jemand später einer Crew bei, erscheinen
rückwirkend auch alte Runden in deren Bilanz. Das ist verkraftbar und
sogar plausibel („die Runden, die unsere Leute hatten"); die Alternative
wäre eine eingefrorene Zahl, die niemand mehr erklären kann.

## Modularität

- **Hängt ab von:** `sessions`, `session_participants` (0047), `crews`,
  `crew_members`, `checkins`
- **Wird gebraucht von:** nichts — es ist eine Erweiterung, keine Basis
- **Ausbauen:** den vierten Zweig aus `checkins_select` entfernen, die
  Zuordnung beim Einchecken auf `host_id = ich` zurücknehmen,
  `crewCheckins` wieder allein über `sessions.crew_id` joinen

## Plattformen

Gleich auf allen. Die Regel sitzt in der Datenbank; die App liest nur,
was sie bekommt.

## Skalierung

Der neue Policy-Zweig kostet je Zeile ein `exists` über
`session_participants` — indexgestützt über den Primärschlüssel
`(session_id, profile_id, kind)`. Er greift nur bei Check-ins mit
`session_id`, und das ist ein kleiner Teil des Bestands.

Der Crew-Join über Teilnehmer ist teurer als der heutige über
`sessions.crew_id`. Bei Crews in üblicher Größe (unter hundert
Mitgliedern) unkritisch; sollte es je klemmen, ist das der Punkt für
eine materialisierte Zuordnung — dann mit dem Nachziehen, das oben
bewusst vermieden wurde.

## Umsetzungsstatus

**Fertig:** Die Sichtbarkeit (0050), abgesichert durch
`supabase/tests/runden_checkins.test.sql`. Der Feed zeigt damit die
Check-ins der Mitrundigen, ohne dass App-Code geändert wurde.

**Offen:** die Zuordnung beim Einchecken (Teilnehmer statt nur Gastgeber)
und die Crew-Bilanz über Teilnehmer.

## Umsetzungsplan

| Schritt | Was | Prüfkriterium |
|---|---|---|
| ~~1~~ | ~~`checkins_select` um den Runden-Zweig erweitern~~ | ✅ pgTAP: Teilnehmer sieht, Fremder nicht, `private` bleibt privat |
| 2 | Zuordnung beim Einchecken: auch fremde Runden, an denen ich zugesagt habe | Test: Check-in während einer fremden Runde trägt deren `session_id` |
| 3 | `crewCheckins()` über Teilnehmer statt nur `sessions.crew_id` | Test: Eine Runde ohne `crew_id` erscheint in der Bilanz jeder Crew, aus der jemand dabei war |
| 4 | Runden-Ansicht zeigt die Check-ins aller Teilnehmer | Widget-Test |

## Offene Punkte / Ideen

- **Der tote `crew`-Zweig in `checkins_select`.** Er greift nicht, weil
  die App nie `visibility = 'crew'` schreibt. Entweder bekommt der Mensch
  die Wahl der Sichtbarkeit beim Check-in — oder der Zweig sollte
  verschwinden. Beides ist eine Entscheidung, keine Aufräumarbeit
- **Rückwirkende Zuordnung** für Runden, die vor 0050 stattfanden: Ihre
  Check-ins tragen keine `session_id` und lassen sich nachträglich nicht
  zuordnen. Kein Verlust, nur eine Lücke in der Historie
