# 09 Crews

> **Status:** 🟢 fertig — Gruppen mit drei Beitrittswegen, eigenem Feed
> und Bilanz.
> **Seit:** 0.9.12; QR-Beitritt 0.10.10, Feed/Bilanz/Kurzcode 0.10.12 ·
> **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Die meisten Bierrunden sind wiederkehrende Gruppen: der Stammtisch, die
Arbeitskollegen, der Verein. Eine Crew erspart es, jedes Mal dieselben
Leute einzeln anzuschreiben — und erlaubt Beacons, die nur diese Gruppe
sehen.

## Funktion (Nutzersicht)

- Crew anlegen; die Crew-Ansicht zeigt den **sechsstelligen Code zum
  Vorlesen**, darunter den **QR-Code** und zuletzt die lange Kennung zum
  Kopieren
- Beitreten auf **drei Wegen**: scannen, den kurzen Code tippen, oder die
  lange Kennung einfügen. Ein Feld nimmt beides entgegen — welche
  Schreibweise jemand hat, ist seine Sache und nicht seine Entscheidung
- **Bilanz der Crew**: Check-ins, verschiedene Biere, wie viele dabei
  waren, der Schnitt und die häufigsten Stile
- **„Aus euren Runden"**: die Check-ins, die in Crew-Runden entstanden
  sind
- Mitgliederliste, Verlassen, Auflösen (nur Gründer)
- Beim Starten einer Session: Sichtbarkeit „nur meine Crew" mit Auswahl

**Drei Codes für denselben Zweck, und jeder hat seinen Fall:** Der QR ist
der Weg am Tisch. Der sechsstellige Code ist der Weg am Telefon, über den
Tisch gerufen oder auf einen Bierdeckel geschrieben — dafür hat er ein
Alphabet ohne Zwillinge (kein 0/O, kein 1/I/L). Die lange Kennung bleibt
für die Nachricht und den Rechner ohne Kamera.

**Wer den Code scannt, ist sofort drin** — es gibt keine Zustimmung des
Gastgebers. Das ist keine Neuerung des QR-Wegs, sondern galt schon für den
getippten Code: Der Code *ist* die Einladung. Welcher Crew man beitritt,
steht vorher **nicht** da; im Code steckt nur die UUID, und den Namen dazu
gibt der Server erst heraus, wenn man Mitglied ist (die RLS zeigt fremde
Crews nicht). Ein Vorschau-Schritt wäre entweder gelogen oder ein neues
Leseloch — die Bestätigung kommt deshalb hinterher.

## Technische Umsetzung

- **Dateien:** `features/crews/crews_screen.dart`,
  `crew_detail_screen.dart` (inkl. Bilanz und Runden-Feed),
  `crew_scan_screen.dart` (QR-Beitritt),
  `core/brewmates_code.dart` (die QR-Sprache),
  `data/online/api/crews_api.dart` (Feed + Kurzcode),
  `data/providers/crews.dart`, `domain/crew_stats.dart`,
  `data/online/online_service.dart` (Abschnitt „Crews")
- **Server:** `crews.join_code` + `join_crew_by_code()` (0041)
- **QR:** `qr_flutter` zum Erzeugen, `mobile_scanner` zum Lesen — beide
  waren schon für [Funktion 22](22-freunde-per-qr-code.md) an Bord, kein
  neues Paket
- **Tabellen:** `crews`, `crew_members` (beide seit 0001),
  `is_crew_member()` für RLS; `sessions.crew_id` mit der Bedingung, dass
  Sichtbarkeit „crew" eine Crew verlangt
- **Beitritt:** die Regel aus 0001 erlaubt ausdrücklich das Eintragen der
  eigenen Person; über den Kurzcode läuft es seit 0041 zusätzlich über
  eine Funktion (Begründung unten)

**Fast alles ohne neue Migration gebaut:** Das Schema aus 0001 sah Crews
vollständig vor — es fehlte nur die Bedienung. Ein Beleg dafür, dass sich
sorgfältiges Datenmodellieren am Anfang auszahlt. Der QR-Beitritt brauchte
nichts am Server, und auch der Feed nicht: Er fragt nur nach dem, was
`checkins_select` ohnehin erlaubt. Die einzige Migration ist **0041** —
und die auch nur, weil ein Code zum Vorlesen nirgends stand.

**Die QR-Sprache liegt in `core/`, nicht bei den Freunden.** Es gibt jetzt
zwei Code-Arten (`brewmates:friend:<uuid>`, `brewmates:crew:<uuid>`) und
drei Bildschirme, die scannen. Damit entsteht ein Fehlerfall, den es
vorher nicht gab: der **richtige Code am falschen Scanner**. „Das ist kein
BrewMates-Code" wäre dort gelogen — der Scanner weiß ja, was er hat. Beide
Features müssen dafür dieselbe Sprache lesen, und Features dürfen einander
nicht importieren; also gehört sie nach `core/`. Der Freundes-Scanner sagt
seither „Das ist ein Crew-Code, geh auf Crews", und umgekehrt.

## Modularität

- **Hängt ab von:** Konto (01), Freunde (08), Sessions (07)
- **Wird gebraucht von:** Session-Sichtbarkeit „crew"
- **Ausbauen:** Feature-Ordner, zwei Routen und die Crew-Option beim
  Session-Start entfernen. Tabellen können bleiben.

## Plattformen

Alle.

## Skalierung

Crew-Größen sind klein, die Mitgliederliste wird per eingebetteter Abfrage
gezählt. Der Feed holt höchstens 50 Zeilen und die Bilanz rechnet auf
denselben — eine Crew, die das sprengt, gibt es noch lange nicht; dann
bräuchte der Feed Seitenladen wie der große (Funktion 10).

Der Kurzcode hat 31⁶ ≈ 887 Millionen Möglichkeiten. Die Erzeugung
probiert bei Kollision erneut und gibt nach zwanzig Fehlschlägen auf —
bei dieser Zahl heißt der zwanzigste nicht „Pech", sondern „hier stimmt
etwas nicht".

## Umsetzungsstatus

Vollständig für den Zweck „Gruppe mit eigenem Ort". Was bleibt, ist
Ausbau: Challenges und Rollen.

### Zwei Entscheidungen, die man kennen sollte

**Der Feed brauchte keine neue Regel.** Die Sichtbarkeit stand seit 0001
in `checkins_select`: Ein Check-in mit `visibility = 'crew'`, der zu einer
Runde dieser Crew gehört, ist für jedes Mitglied lesbar. Gefehlt hat nur
die Abfrage. Damit steht im Crew-Feed ausschließlich, was in **Crew-Runden**
entstanden ist — was jemand außerhalb trinkt, geht die Crew nichts an, und
das ist keine Entscheidung der Anzeige, sondern die des Servers.

**Die Bilanz baut NICHT auf [Funktion 20](20-feed-statistiken.md) auf.**
`computeStats` rechnet mit Füllmenge, Gebinde, Brauereiland und Gasthaus.
Nichts davon steht in einer Feed-Zeile vom Server — die ist bewusst
denormalisiert und trägt Biername, Stil, Bewertung und Autor. Diese
Zahlen aus fehlenden Feldern zu schätzen wäre die schlechtere Antwort:
„2,4 Liter" klingt nach Messung. `domain/crew_stats.dart` rechnet
deshalb nur mit dem, was wirklich dasteht — und der Schnitt zählt nur
bewertete Check-ins, weil unbewertete seit 0.10.12 wirklich unbewertet
sind.

**Der Beitritt per Kurzcode läuft über eine Funktion**, weil
`crews_select` nur die eigenen Crews zeigt: Der Client kann „welche Crew
hat Code X?" gar nicht fragen. `join_crew_by_code` beantwortet genau
diese eine Frage und unterscheidet dabei bewusst nicht zwischen „gibt es
nicht" und „ging nicht" — alles Feinere wäre ein Ratewerkzeug für fremde
Gruppennamen.

Abgesichert durch `test/brewmates_code_test.dart` (8 Tests),
`test/crew_qr_test.dart` (4 Widget-Tests), `test/crew_stats_test.dart`
(9 Tests zur Bilanz) und `supabase/tests/crew_join_code.test.sql`
(10 Prüfungen: Codealphabet ohne Zwillinge, Eindeutigkeit, Beitritt,
verziehene Schreibweise — und dass ein unbekannter Code nichts verrät).

## Umsetzungsplan

1. ~~Beitritt per QR-Code~~ — erledigt in 0.10.10 (Issue #62)
2. ~~Kurzer, sprechbarer Einladungscode~~ — erledigt in 0.10.12 (0041)
3. ~~Crew-Feed~~ — erledigt in 0.10.12
4. ~~Crew-Bilanz~~ — erledigt in 0.10.12; **nicht** auf
   [Funktion 20](20-feed-statistiken.md) aufgebaut, siehe unten
5. Offen: Crew-Challenges und Rollen neben dem Gründer — beides erst
   sinnvoll, wenn es mehr als eine aktive Crew gibt

## Offene Punkte / Ideen

- Crew-Challenges („gemeinsam 50 Stile")
- Rollen innerhalb der Crew (Verwalter neben dem Gründer)
