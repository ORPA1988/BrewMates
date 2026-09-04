# 40 Check-ins in einer Runde

> **Status:** 🟢 fertig — Sichtbarkeit (0050), Crew-Zuordnung
> (0051/0052), Zuordnung beim Einchecken und die Runden-Ansicht stehen.
> **Seit:** Server 2026-09-04 (0050); **ohne App-Änderung**, deshalb
> kein Versionsbump · **Zuletzt geprüft:** 2026-09-04
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

**Und selbst für ihn stimmte es nur lokal.** Beim Bauen von Schritt 2
kam der eigentliche Grund heraus: `uploadRow` in
`data/online/api/checkins_api.dart` setzte `'session_id': null` — hart
verdrahtet, ohne Kommentar. Die Zuordnung erreichte den Server also
**nie**, auch die zur eigenen Runde nicht.

Damit lief alles ins Leere, was darauf aufbaut: Die Crew-Bilanz jointe
über `sessions.crew_id` und fand nichts, und der Runden-Zweig aus 0050
hätte nie gegriffen, weil `session_id is not null` nie zutraf. Eine
Server-Regel, die auf ein Feld baut, das der Client nicht füllt, ist
eine Regel über nichts — und das fällt in keinem Test auf, der nur eine
Seite betrachtet.

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
- **Zuordnung beim Einchecken:** `createCheckin` nimmt die eigene
  Runde, sonst über `myJoinedRoundId()` die fremde, an der ich
  zugesagt habe. Nur online zu beantworten — Zusagen leben
  ausschließlich am Server
- **Crew-Bilanz:** `crewCheckins()` joint über `checkin_crews` statt
  über `sessions.crew_id`. Der alte Weg fand nur Runden, die
  ausdrücklich als Crew-Runde gestartet wurden — eine Crew je Abend,
  und nur wenn jemand daran gedacht hatte

### Warum die Regel eine `security definer`-Funktion braucht

Der erste Entwurf stellte die Frage direkt in der Policy: ein `exists`
über `sessions` und `session_participants`. **Die CI hat ihn zerlegt —
sieben Gegenproben grün, ausgerechnet das Öffnen rot.**

Der Grund ist eine Eigenschaft von RLS, die man beim Schreiben leicht
übersieht: `sessions` trägt selbst eine Policy. Die Unterabfrage lief als
der fragende Mensch — und der sieht die Runde eines Nicht-Freundes gar
nicht, weil `sessions_select` Freundschaft oder Crew verlangt. Also fand
das `exists` nichts. Die Regel sperrte einwandfrei und öffnete nie.

Bemerkenswert ist die Fehlerrichtung: Ein Sichtbarkeitsfehler, der zu
**wenig** zeigt, fällt beim Benutzen sofort auf. Einer, der zu **viel**
zeigt, fällt vielleicht nie auf. Dass ausgerechnet die sieben
Gegenproben grün waren, war Zufall der Konstruktion — deshalb prüft
dieser Test beide Richtungen und nicht nur die neue.

`is_my_round(session)` löst es nach dem Muster von `are_friends`,
`is_crew_member` und `tier_for`. **Ohne Profil-Parameter**, mit Absicht:
Die Funktion gibt nur über den Aufrufer Auskunft. Ein zweiter Parameter
hätte sie zu einem Auskunftsdienst über Dritte gemacht („war X bei Runde
S dabei?") — und genau das ist der Maßstab, an dem docs/13 die übrigen
Helfer misst.

### Warum die Crew-Zuordnung gespeichert wird — und am Server entsteht

**Der erste Entwurf dieses Dokuments wollte sie ableiten**: Eine Runde
gehört zu den Crews ihrer Teilnehmer, beides steht in der Datenbank,
also braucht es keine Kopie. Das Argument gegen die gespeicherte
Variante lautete, sie müsse bei jedem Beitritt und Austritt nachgezogen
werden.

**Das Argument war falsch.** Es stimmt nur, wenn die gespeicherte
Zuordnung die Ableitung *nachbilden* soll. Sie soll aber etwas anderes:
den **damaligen** Stand festhalten — „in dieser Runde saßen Leute aus
Crew A und B". Dann ist gar keine Pflege nötig, weil sich Vergangenes
nicht ändert.

Was die Ableitung in der Praxis bedeutet hätte:

| Fall | Folge der Ableitung |
|---|---|
| Anna und Ben trinken im Juni, gründen im September eine Crew | Die Juni-Runde erscheint in der Bilanz einer Crew, die es damals nicht gab |
| David tritt nach dem Sommer aus seiner Crew aus | **Die Bilanz fällt rückwirkend von 60 auf 20** — für Abende, die stattgefunden haben |
| Eva ist in zwei Crews und trinkt mit Studienfreunden | Die Runde landet in beiden Bilanzen |

Der zweite Fall gibt den Ausschlag. Eine Bilanz ist ein **Rückblick auf
Geschehenes**; sie darf sich nicht ändern, weil sich heute eine
Mitgliederliste ändert. Das ist dieselbe Haltung wie in
[Funktion 20](20-feed-statistiken.md), wo ein Monat ohne Eintrag kein
Nullwert ist und geschätzte Mengen als geschätzt ausgewiesen werden.

Der dritte Fall bleibt auch mit der gespeicherten Zuordnung bestehen:
Evas Runde zählt für beide Crews, weil sie in beiden ist. Lösen ließe
sich das nur mit einer Rückfrage („Für welche Crew zählt dieser
Abend?") — mehr Bedienung für einen selteneren Fall. Erst einmal beide;
wenn es stört, lässt sich die Rückfrage nachrüsten.

**Und sie muss am Server entstehen, nicht im Client.** Das ist keine
Geschmacksfrage: `crew_members_select` zeigt eine Mitgliederliste nur
den Mitgliedern dieser Crew. Ein Client kann also gar nicht wissen, in
welchen Crews die anderen am Tisch sind — und soll es auch nicht wissen.
Ein Trigger mit `security definer` sieht, was nötig ist, und gibt nichts
davon preis.

### Was die Bilanz trotzdem nicht kann

Sie ist **für jeden Betrachter verschieden**, und das war schon vor 0050
so: Die RLS zeigt nur, was der Betrachter sehen darf. Frank sagt „wir
hatten zwölf Check-ins", Greta sieht fünf — weil sie bei sieben davon
weder dabei noch mit dem Autor befreundet war. **Beide haben recht.**

Das ist der Preis der Entscheidung „Teilnehmer ja, Crew-Rest nein", und
er ist richtig bezahlt. Die Anzeige sollte ihn allerdings benennen,
statt eine Gesamtzahl zu behaupten, die für niemanden stimmt.

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
| ~~2~~ | ~~Zuordnung beim Einchecken~~ — **erledigt.** Dabei der eigentliche Fund: `uploadRow` schickte `session_id: null`, hart verdrahtet | ✅ vier Tests in `upload_assistant_test.dart` |
| ~~3~~ | ~~`crewCheckins()` auf `checkin_crews` umstellen~~ — **erledigt** | ✅ pgTAP, inkl. Austritt |
| ~~4~~ | ~~Runden-Ansicht zeigt die Check-ins aller Teilnehmer~~ — **erledigt.** Der Provider las nur lokal und gab für fremde Runden unbesehen eine leere Liste zurück | ✅ sieben Tests in `runden_ansicht_test.dart` |

## Offene Punkte / Ideen

- **Der tote `crew`-Zweig in `checkins_select`.** Er greift nicht, weil
  die App nie `visibility = 'crew'` schreibt. Entweder bekommt der Mensch
  die Wahl der Sichtbarkeit beim Check-in — oder der Zweig sollte
  verschwinden. Beides ist eine Entscheidung, keine Aufräumarbeit
- **Rückwirkende Zuordnung** für Runden, die vor 0050 stattfanden: Ihre
  Check-ins tragen keine `session_id` und lassen sich nachträglich nicht
  zuordnen. Kein Verlust, nur eine Lücke in der Historie
