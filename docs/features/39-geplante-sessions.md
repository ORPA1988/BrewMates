# 39 Geplante Sessions

> **Status:** 🟡 größtenteils — Server (0048/0049), **Anlegen und
> „Demnächst” stehen**. Offen sind die beiden Erinnerungen und der Knopf
> „Runde starten” (Schritte 6–8).
> **Seit:** — · **Zuletzt geprüft:** 2026-09-04
>
> Baut auf [Funktion 07 (Sessions & Beacons)](07-sessions-und-beacons.md)
> auf. Die Zu- und Absagen, die eine Verabredung erst brauchbar machen,
> gibt es bereits seit 0.10.13 (Migration 0047) — hier fehlt nur der
> Termin in der Zukunft.

## Zielsetzung

Der Beacon beantwortet „ich sitze **jetzt** hier, kommt vorbei". Das
deckt den spontanen Abend ab — aber nicht den häufigeren Fall: „Freitag
19 Uhr, Augustiner, wer ist dabei?"

Heute läuft diese Verabredung an BrewMates vorbei, in einer
Messenger-Gruppe. Dort geht sie in fünfzig Nachrichten unter, und wer
zugesagt hat, weiß am Ende niemand mehr. Genau dieses Problem löst die
App bei laufenden Runden schon: Wer kommt, wer nicht, sichtbar für alle,
die die Runde sehen dürfen.

**Woran man merkt, dass es funktioniert:** Eine Verabredung entsteht in
der App statt im Chat, und am Abend weiß der Gastgeber ohne
Nachzufragen, mit wie vielen er rechnet.

**Warum die Funktion günstig ist:** Sichtbarkeitsregeln, Zu- und
Absagen, Benachrichtigungen und die Oberfläche für „wer kommt" existieren
alle. Was fehlt, ist ein Termin und die Frage, was zum Termin passiert.

## Die Entscheidung, an der alles hängt

**Ein Beacon behauptet Anwesenheit. Eine Verabredung behauptet eine
Absicht.** Das ist nicht dasselbe, und der Unterschied ist der Kern
dieser Funktion.

Eine laufende Session zeigt Freunden den **Standort des Gastgebers**. Zum
geplanten Termin ist der Gastgeber vielleicht noch zuhause, im Stau oder
hat es vergessen. Würde die geplante Session um 19:00 automatisch zum
Beacon, behauptete die Karte eine Anwesenheit, die niemand geprüft hat —
und Freunde führen zu einem leeren Tisch.

**Deshalb: Eine geplante Session wird nie von selbst zum Beacon.** Zum
Termin bekommt der Gastgeber eine Erinnerung mit einem Knopf („Runde
starten"); erst der macht daraus eine laufende Session mit echtem
Standort. Startet er nicht, läuft die Verabredung ab und verschwindet
still.

Das ist auch die ehrlichere Antwort auf „was, wenn niemand kommt": Es
gibt keine Meldung „X ist nicht erschienen". Die App führt kein Protokoll
über Verlässlichkeit.

## Funktion (Nutzersicht)

**Anlegen** — im selben Bildschirm wie der Beacon
(`start_session_screen.dart`), ein Schalter oben: *jetzt* oder *später*.
Bei *später* kommen dazu:

- **Wann** — Datum und Uhrzeit, Vorschläge für „heute Abend", „morgen",
  „Freitag"
- **Wo** — Gasthaus aus der Datenbank oder Freitext, wie beim Beacon.
  **Kein Live-Standort**: Den gibt es erst, wenn die Runde läuft
- **Nachricht**, **Sichtbarkeit** und **Crew** wie beim Beacon

**Sehen** — wer die Verabredung sehen darf, sieht sie:

- auf der **Startseite** unter „Demnächst", nach Termin sortiert
- **nicht auf der Karte.** Dort steht, wer *jetzt* unterwegs ist; eine
  Verabredung für Freitag gehört nicht zwischen Menschen, die gerade in
  einem Lokal sitzen
- **nicht im Zähler „gerade aktiv"** — aus demselben Grund

**Antworten** — *Ich komme vorbei* / *Ich hab keine Zeit*, jederzeit
änderbar, sichtbar für alle, die die Runde sehen dürfen. Das ist
unverändert die Mechanik aus [Funktion 07](07-sessions-und-beacons.md);
sie funktioniert vor dem Termin genauso wie währenddessen.

**Erinnern** — zwei Benachrichtigungen, beide über den vorhandenen Weg
([Funktion 29](29-push-benachrichtigungen.md)):

1. **Beim Anlegen** an alle, die sie sehen dürfen — dieselbe
   Empfängerregel und dieselbe Spam-Bremse wie beim Beacon
   (höchstens ein Wecken pro Gastgeber und Stunde)
2. **Kurz vorher** an alle, die zugesagt haben, und an den Gastgeber.
   Der Gastgeber bekommt dabei den Knopf „Runde starten"

**Absagen** — der Gastgeber kann die Verabredung streichen. Wer zugesagt
hat, erfährt es; das ist die eine Meldung, die wirklich jemand braucht.

**Sonderfälle**

- **Offline anlegen** geht **nicht**. Eine Verabredung, die niemanden
  erreicht, ist schlimmer als keine — sie lässt jemanden warten
  (Regel A). Ohne Verbindung sagt die App das und behält die Eingaben.
  Bewusst **keine** Warteschlange nach dem Muster `venue_queue.dart`:
  Nachgereicht könnte sie Stunden später bei Leuten landen, für die der
  Termin längst vorbei ist
- **Termin in der Vergangenheit** lässt sich nicht wählen
- **Verpasster Start**: Die Verabredung läuft ab (Termin plus Karenz)
  und verschwindet aus „Demnächst". Keine Meldung an irgendwen

## Technische Umsetzung

- **Neu (Server):** Migration `0048_geplante_sessions.sql`
  - `session_status` bekommt den Wert `planned`
  - `sessions.scheduled_for timestamptz` — der geplante Termin.
    **Bewusst nicht `started_at` wiederverwenden**: Das Feld bedeutet
    „wann es tatsächlich losging". Eine nie gestartete Verabredung würde
    darin lügen, und die Statistik rechnet mit `started_at`
  - `end_expired_sessions()` **erweitern**: Sie räumt heute nur
    `status = 'active'` mit `expires_at <= now()` ab. Geplante Sessions
    blieben ewig stehen. Sie brauchen ihre eigene Bedingung
    (`planned` und `scheduled_for + Karenz <= now()`), und zwar in
    derselben Funktion, damit es einen Aufräumweg gibt und nicht zwei
  - **`sessions_select` muss geändert werden.** Das war beim ersten
    Entwurf dieses Dokuments noch eine Vermutung („die Policy filtert nur
    nach Sichtbarkeit") — sie war **falsch**. Am 2026-09-04 live
    nachgesehen (`pg_policy`), lautet die Bedingung für alle außer dem
    Gastgeber:

    ```sql
    status = 'active' and expires_at > now() and ( … Sichtbarkeit … )
    ```

    Eine Verabredung mit `status = 'planned'` wäre damit für **niemanden
    außer dem Gastgeber** sichtbar — die Funktion täte gar nichts. Die
    Policy braucht einen zweiten Zweig für `planned` mit `scheduled_for`
    als Zeitgrenze statt `expires_at`

  - **Der Kartenzähler ist unkritisch — geprüft, nicht vermutet.**
    `count_other_active_sessions` verlangt neben `status = 'active'`
    ausdrücklich `latitude is not null and longitude is not null`. Da
    eine geplante Session per Constraint **keinen** Standort trägt, kann
    sie dort nicht auftauchen, egal was mit dem Status passiert. Die
    Doppelbedingung, die 0024 aus einem anderen Grund eingeführt hat,
    deckt diesen Fall mit ab
  - `check (status <> 'planned' or scheduled_for is not null)` — ein
    geplanter Termin ohne Termin ist ein Widerspruch
  - `check (status <> 'planned' or location is null)` — eine Verabredung
    hat keinen Live-Standort. Der Constraint macht aus der Entscheidung
    oben eine Regel, die der Client nicht umgehen kann

- **Neu (App):**
  - `features/session/plan_session_screen.dart` bzw. ein Zweig in
    `start_session_screen.dart` — welches von beidem, entscheidet sich
    beim Bauen an der Frage, wie viel die beiden Formulare wirklich
    teilen
  - `widgets/planned_session_card.dart` für „Demnächst"
  - Erweiterung von `data/providers/sessions.dart` um die geplanten

- **Geändert:**
  - `data/providers/online.dart` — `remoteSessionsProvider` muss
    geplante **heraushalten**. Dieser Provider speist Karte und Zähler;
    dass der Zeitfilter dort sitzt, war schon einmal ein Fehler wert
    (siehe Funktion 07, Kopfnotiz zu 0.10.12)
  - `features/map/map_screen.dart` — nichts zu tun, **wenn** der
    Provider richtig filtert. Zu prüfen, nicht zu glauben
  - Push-Trigger analog 0039/0047

- **Abhängigkeiten:** keine neuen Pakete. Datum und Uhrzeit über
  `showDatePicker`/`showTimePicker` — deutsch beschriftet, seit 0.10.14
  ist `flutter_localizations` eingebunden

### Was am Termin technisch passiert

Nichts Automatisches am Server außer der Erinnerung. Der Statuswechsel
`planned → active` ist eine **Handlung des Gastgebers** und läuft über
denselben Weg wie „Beacon starten" — inklusive Standortabfrage. Damit
gibt es keinen zweiten Startpfad, der auseinanderlaufen kann.

## Modularität

- **Hängt ab von:** `sessions` und `session_participants` (0001, 0047),
  Sichtbarkeits-Policies (0024), Push (0039), Gasthaus-Auswahl
- **Wird gebraucht von:** nichts. Verschwindet die Funktion, bleibt der
  Beacon vollständig
- **Ausbauen:** Anlege-Zweig entfernen, „Demnächst" von der Startseite
  nehmen, Erinnerungs-Trigger löschen, `planned`-Zeilen auf `ended`
  setzen. Der Enum-Wert bliebe stehen — Postgres kann Enum-Werte nicht
  entfernen; das ist kein Rest, sondern eine Eigenheit

## Plattformen

Android, Web, Windows: **gleich**. Nichts an der Funktion ist
plattformgebunden — kein Kamerazugriff, kein Standort beim Anlegen.

Die **Erinnerung** ist die Ausnahme: Push erreicht Android zuverlässig,
im Browser nur bei offenem Tab
([Funktion 38](38-benachrichtigungen-im-browser.md)). Wer nur die Web-App
benutzt, sieht die Verabredung in „Demnächst", aber die Erinnerung
möglicherweise nicht. Das ist bestehende Lage, keine neue Lücke — es
gehört nur gesagt.

## Skalierung

Unkritisch. Eine geplante Session ist eine Zeile in `sessions`, die
Abfrage läuft über denselben Index und dieselbe Policy. Bei 100 oder
100.000 Nutzern ändert sich nichts an der Form der Abfrage — die Anzahl
**sichtbarer** Verabredungen wächst mit dem Freundeskreis, nicht mit der
Nutzerzahl.

Ein Punkt verdient Aufmerksamkeit: Die Erinnerung „kurz vorher" braucht
einen Cron-Lauf, der Termine findet. Bei minütlicher Ausführung ist das
eine Indexabfrage auf `scheduled_for` — der Index gehört in dieselbe
Migration, sonst ist es ein Full Scan pro Minute.

## Umsetzungsstatus

**Server: fertig.** Migrationen `0048` (Enum-Wert `planned`, Spalte
`scheduled_for`) und `0049` (Checks, erweiterte `sessions_select`,
partieller Index, erweitertes `end_expired_sessions()`), abgesichert
durch `supabase/tests/geplante_sessions.test.sql` — elf pgTAP-Tests
gegen die Policy, die Constraints und das Aufräumen.

**App: Anlegen und Anzeigen stehen.** Im Beacon-Formular schaltet ein
gewählter Termin den Weg um (`_TerminZeile` in
`start_session_screen.dart`); auf der Startseite steht „Demnächst" unter
„Gerade unterwegs" — was jetzt läuft, ist dringender als was am Freitag
ansteht.

**Verabredungen leben nur am Server, mit Absicht.** Ein Beacon ergibt
auch offline Sinn: Er ist ein Zustand, den das Gerät kennt. Eine
Verabredung, von der niemand erfährt, ist dagegen keine. Sie steht
deshalb **nicht** in der lokalen Drift-Datenbank — was nebenbei eine
Schema-Erweiterung erspart hat — und ein Fehlschlag beim Anlegen wird
sofort gesagt, statt in einer Warteschlange zu landen.

**Offen:** die beiden Erinnerungen und der Knopf „Runde starten" aus der
Erinnerung heraus. Beides braucht wieder Server-Arbeit: einen Trigger
und einen Cron-Lauf.

**Die Karte ist trotzdem schon sicher — geprüft, nicht angenommen.**
`friendSessionsStream()` in `data/online/api/sessions_api.dart` verwirft
jede Zeile mit `row['status'] != 'active'`, bevor sie überhaupt zu einer
`RemoteSession` wird. Schritt 3 des Plans war damit bereits erfüllt,
bevor er anfing.

**Eine offene Stelle ist benannt, nicht übersehen:** `byId()` filtert
bewusst **nicht** nach Status — sie soll auch beendete eigene Sessions
liefern, damit eine alte Benachrichtigung noch etwas zeigt. Sobald die
App Verabredungen anlegt, würde eine davon dort als laufender Beacon
erscheinen. `RemoteSession` braucht dafür `status` und `scheduledFor`.
Das steht als Kommentar an der Methode und gehört zu Schritt 5.

## Umsetzungsplan

| Schritt | Was | Prüfkriterium |
|---|---|---|
| ~~1~~ | ~~Belegen, wie `sessions_select` mit geplanten Sessions umgeht~~ — **erledigt am 2026-09-04, siehe oben.** Ergebnis: Die Policy schließt alles aus, was nicht `active` ist; sie **muss** angefasst werden. Der Kartenzähler dagegen nicht | — |
| ~~2~~ | ~~Migration~~ — **erledigt:** `0048` (Enum-Wert, Spalte) und `0049` (Checks, Policy, Index, Aufräumen). **Zwei Dateien**, weil Postgres einen frisch angelegten Enum-Wert in derselben Transaktion nicht benutzen lässt | ✅ `supabase/tests/geplante_sessions.test.sql`, elf Tests |
| ~~3~~ | ~~`remoteSessionsProvider` hält geplante heraus~~ — **war schon so:** `friendSessionsStream()` verwirft alles, was nicht `active` ist. Der Kartenzähler ist doppelt geschützt, weil er zusätzlich einen Ort verlangt | ✅ im pgTAP-Test mitgeprüft |
| ~~4~~ | ~~Anlegen-Formular mit *jetzt/später*~~ — **erledigt.** Ein gewählter Termin schaltet den Weg um; ohne Termin bleibt alles wie bisher | ✅ drei Tests: ohne Verbindung, Serverfehler, Erfolg |
| ~~5~~ | ~~„Demnächst" auf der Startseite~~ — **erledigt**, unter „Gerade unterwegs". Antworten laufen über die vorhandene Runden-Ansicht | ✅ zwei Widget-Tests |
| 6 | Erinnerung beim Anlegen (Empfängerregel = `sessions_select`) | Wie 0039: niemand bekommt eine Meldung über etwas, das er nicht sehen darf |
| 7 | Erinnerung kurz vorher, Cron auf `scheduled_for` | Test gegen den Index; kein Full Scan |
| 8 | „Runde starten" aus der Erinnerung heraus | Der Standort wird dabei frisch geholt, nicht aus der Planung übernommen |

**Reihenfolge ist Absicht — und Schritt 1 hat sich sofort bezahlt
gemacht.** Er kostete eine Abfrage und hat den Entwurf an einer Stelle
umgeworfen, an der er falsch war: Die Sichtbarkeitsregel für Beacons
schließt alles aus, was nicht gerade läuft. Hätte niemand nachgesehen,
wäre die Funktion gebaut worden und für alle außer dem Gastgeber
unsichtbar geblieben — mit einer Fehlersuche in der App, wo der Fehler
in der Datenbank saß. Das ist wörtlich der Fehler aus
[docs/13, Lehre 1](../13-migrationen-und-lehren.md): eine Annahme über
Rechte, die niemand geprüft hat.

**Was daraus für Schritt 2 folgt:** `sessions_select` ist die Regel, die
entscheidet, wer den Standort eines Menschen sieht. Sie zu erweitern ist
kein Nebenbei. Entschärfend wirkt, dass eine geplante Session per
Constraint **keinen** Standort trägt: Selbst ein Fehler im neuen Zweig
gäbe keinen Ort preis, sondern höchstens eine Verabredung. Trotzdem
gehört ein pgTAP-Test dazu, der beide Zweige einzeln belegt.

## Offene Punkte / Ideen

- ~~**Wie lang ist die Karenz?**~~ **Entschieden mit 0049: drei
  Stunden**, dieselbe Spanne, nach der ein laufender Beacon von selbst
  endet. Kürzer wäre unfreundlich (wer eine halbe Stunde zu spät
  startet, will die Runde noch haben), länger ließe tote Verabredungen
  im Weg stehen. Die Zahl steht bewusst an **zwei** Stellen —
  Sichtbarkeit und Aufräumen —, und sie müssen gleich bleiben:
  Begründung im Kopf von `0049`
- **Wiederkehrende Termine** („jeden ersten Donnerstag") — reizvoll für
  Stammtische, aber eine eigene Funktion mit eigenen Fragen
  (Ausnahmen, Absage einzelner Termine). Nicht in dieser Stufe
- **Kalendereintrag exportieren** (.ics) — naheliegend, aber
  plattformabhängig und nachrangig
- **Vorschlag statt Ansage** („wann passt euch?" mit Abstimmung) — das
  ist Doodle, nicht BrewMates. Bewusst nicht geplant

## Bewusst nicht

- **Keine automatische Umwandlung in einen Beacon.** Siehe oben: Das
  behauptete Anwesenheit, die niemand geprüft hat
- **Keine Erinnerung an Leute, die nicht geantwortet haben.** Schweigen
  ist eine Antwort, und Nachhaken gehört Menschen, nicht der App
- **Kein Protokoll über Verlässlichkeit.** Wer dreimal zugesagt und
  nicht kam, wird nirgends gezählt. Aus einem Bierabend eine Bewertung
  von Menschen zu machen, ist der Punkt, an dem die App unangenehm wird
