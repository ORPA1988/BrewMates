# 09 Crews

> **Status:** 🟢 fertig — vier Beitrittswege, eigener Runden-Feed und
> Bilanz.
> **Seit:** 0.9.12; QR-Beitritt 0.10.10; Feed, Bilanz, Kurzcode und
> Einladungen 0.10.12 · **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Die meisten Bierrunden sind wiederkehrende Gruppen: der Stammtisch, die
Arbeitskollegen, der Verein. Eine Crew erspart es, jedes Mal dieselben
Leute einzeln anzuschreiben — und erlaubt Beacons, die nur diese Gruppe
sehen.

## Funktion (Nutzersicht)

- Crew anlegen; die Crew-Ansicht zeigt den **sechsstelligen Code zum
  Vorlesen**, darunter den **QR-Code** und zuletzt die lange Kennung zum
  Kopieren
- Beitreten auf **vier Wegen**: scannen, den kurzen Code tippen, die
  lange Kennung einfügen — oder **eingeladen werden**. Ein Feld nimmt
  alle Schreibweisen entgegen; welche jemand hat, ist seine Sache und
  nicht seine Entscheidung
- **Freunde einladen** (in der Crew-Ansicht): Angeboten wird nur, wer
  noch nicht dabei ist und noch nicht wartet. Die Einladung erscheint
  beim anderen oben in der Crew-Liste, in der Glocke und als Push
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

### Warum die Einladung eine Antwort braucht — der Code aber nicht

Das sieht wie ein Widerspruch aus und ist der Kern von 0044.

Beim Code entscheidet der **Eingeladene selbst**: Er hält ihn in der Hand
und tippt ihn ein. Wer das tut, hat zugestimmt; ein Bestätigungsschritt
wäre eine Rückfrage auf die eigene Handlung.

Bei einer Einladung entscheidet ein **anderer**. Und in eine Crew zu
kommen ist keine Kleinigkeit: Ein Crew-Beacon zeigt der Crew den
**Aufenthaltsort**, und Check-ins während einer Crew-Runde werden für sie
sichtbar. Das ist eine Änderung daran, wer was von einem sieht — und
darüber entscheidet in dieser App niemand für jemand anderen. Aus
demselben Grund braucht eine Freundschaft eine Annahme und entsteht nicht
durch einen Scan.

Die Karte sagt das auch: „Als Mitglied siehst du die Runden der Crew — und
sie deine, inklusive Standort während eines Crew-Beacons." Nicht im
Kleingedruckten.

**Einladen darf man nur Freunde.** Sonst wäre die Einladung ein Weg,
Fremden ungefragt etwas zu schicken — und die Profil-ID eines Fremden
bekommt man über den QR-Code leicht genug. Es gibt auch keinen „alle
einladen"-Knopf: Eine Crew ist eine Runde, keine Verteilerliste.

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
- **Server:** `crews.join_code` + `join_crew_by_code()` (0041),
  `crew_invites` samt Glocken-Trigger (0044), `crews_select` auch für den
  Eigentümer (0043)
- **QR:** `qr_flutter` zum Erzeugen, `mobile_scanner` zum Lesen — beide
  waren schon für [Funktion 22](22-freunde-per-qr-code.md) an Bord, kein
  neues Paket
- **Tabellen:** `crews`, `crew_members` (beide seit 0001),
  `is_crew_member()` für RLS; `sessions.crew_id` mit der Bedingung, dass
  Sichtbarkeit „crew" eine Crew verlangt
- **Beitritt:** die Regel aus 0001 erlaubt ausdrücklich das Eintragen der
  eigenen Person; über den Kurzcode läuft es seit 0041 zusätzlich über
  eine Funktion (Begründung unten)

**Vieles ging ohne neue Migration:** Das Schema aus 0001 sah Crews
weitgehend vor — es fehlte die Bedienung. Der QR-Beitritt brauchte nichts
am Server, und auch der Feed nicht: Er fragt nur nach dem, was
`checkins_select` ohnehin erlaubt.

Neu am Server sind vier Migrationen, und zwei davon sind Reparaturen:
**0041** (Code zum Vorlesen), **0042** und **0043** (siehe
Umsetzungsstatus — beide behoben, was das Anlegen einer Crew verhinderte)
sowie **0044** (Einladungen).

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

**Zwei Fehler, die dabei gefunden wurden** (beide in 09 dokumentiert,
weil sie zur Funktion gehören): Der Code entstand per Spaltenvorgabe, und
die läuft mit den Rechten des Einfügenden — „Crew gründen" scheiterte
(0042). Und `crews_select` verlangte eine Mitgliedschaft, die es beim
Anlegen noch nicht geben kann, weshalb das Zurücklesen der neuen ID
scheiterte: **Crews ließen sich seit 0.9.12 überhaupt nicht anlegen**
(0043). Beide waren unbemerkt geblieben, weil die Tests ihre Crews als
`postgres` anlegten — der umgeht RLS. Seither prüfen sie in der Rolle
`authenticated`.

Abgesichert durch `test/brewmates_code_test.dart` (8 Tests),
`test/crew_qr_test.dart` (4 Widget-Tests), `test/crew_stats_test.dart`
(9 Tests zur Bilanz) und `supabase/tests/crew_join_code.test.sql`
(15 Prüfungen: Codealphabet ohne Zwillinge, Eindeutigkeit, Beitritt,
verziehene Schreibweise, Anlegen als `authenticated` inkl. `returning` —
und dass ein unbekannter Code nichts verrät) sowie
`supabase/tests/crew_invites.test.sql` (14 Prüfungen: nur Mitglieder
laden ein, nur Freunde, nie in fremdem Namen; sehen dürfen es nur der
Eingeladene und die Crew; annehmen, ablehnen, und dass die Meldung
mitverschwindet) und `test/crew_einladungen_test.dart` (6 Widget-Tests).

## Umsetzungsplan

1. ~~Beitritt per QR-Code~~ — erledigt in 0.10.10 (Issue #62)
2. ~~Kurzer, sprechbarer Einladungscode~~ — erledigt in 0.10.12 (0041)
3. ~~Crew-Feed~~ — erledigt in 0.10.12
4. ~~Crew-Bilanz~~ — erledigt in 0.10.12; **nicht** auf
   [Funktion 20](20-feed-statistiken.md) aufgebaut, siehe unten
5. ~~Freunde einladen~~ — erledigt in 0.10.12 (0044)
6. Offen: Crew-Challenges und Rollen neben dem Gründer — beides erst
   sinnvoll, wenn es mehr als eine aktive Crew gibt

## Offene Punkte / Ideen

- Crew-Challenges („gemeinsam 50 Stile")
- Rollen innerhalb der Crew (Verwalter neben dem Gründer)
