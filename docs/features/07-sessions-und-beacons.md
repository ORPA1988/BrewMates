# 07 Sessions & Beacons

> **Status:** 🟢 fertig — inklusive Push an die, die den Beacon sehen
> dürfen (0039, seit 0.10.10).
> **Seit:** 0.2.0; Zu- und Absagen 0.10.13 · **Zuletzt geprüft:** 2026-09-04
>
> **Fremde Beacons laufen seit 0.10.12 zuverlässig ab.** Der Zeitfilter
> lag im Realtime-Stream — und Realtime schickt nur, wenn sich eine
> **Zeile** ändert. Eine ablaufende Laufzeit ändert keine Zeile; der
> Server beendet sie erst per Cron. Ein längst beendeter Beacon stand
> deshalb weiter auf der Karte, **mit Ort**, bis zufällig irgendwer
> anders etwas tat. Der Filter sitzt jetzt in `remoteSessionsProvider`
> und hängt am 30-Sekunden-Takt.
>
> **Ein neuer Beacon weckt seit 0.10.10 die Freunde** (Issue #60). Wer
> etwas bekommt, ist wortwörtlich die Bedingung aus `sessions_select`:
> Freunde ab dem Kreis „Freund" bzw. die Crew, niemand sonst. Eine
> Benachrichtigung über eine Runde, die man beim Hintippen nicht sehen
> darf, wäre schlimmer als gar keine. Spam-Bremse: höchstens ein Wecken
> pro Gastgeber und Stunde. Endet die Runde, verschwindet die
> Benachrichtigung dazu.
>
> **Beenden ist seit 0.10.10 zurücknehmbar** — fünf Sekunden lang, und
> zwar auf allen vier Bildschirmen, die den Beacon beenden können
> (`beaconBeendenMitRueckgaengig` in `widgets/beacon_messages.dart`).
> Der Beacon wird dabei wirklich sofort beendet und danach wiederbelebt,
> nicht aufgeschoben: Wer „Beenden" tippt, will in dieser Sekunde
> unsichtbar sein. Die Restlaufzeit bleibt unangetastet, ein bereits
> abgelaufener Beacon kommt nicht zurück — siehe
> [Funktion 36](36-rueckgaengig-statt-rueckfrage.md).

## Zielsetzung

Der Beacon ist die Einladung: „Ich sitze hier, kommt vorbei." Er ersetzt
die Rundmail an fünf Leute, von denen vier zu spät antworten. Ein Tipp,
und die Freunde wissen Bescheid.

Er beantwortet damit ausdrücklich das **jetzt**. Der geplante Termin
(„Freitag 19 Uhr“) ist eine eigene Funktion mit eigenem Entwurf —
[Funktion 39](39-geplante-sessions.md) — und sie wird bewusst **nicht**
automatisch zum Beacon: Ein Beacon behauptet Anwesenheit, eine
Verabredung nur eine Absicht.

## Funktion (Nutzersicht)

- **Ein Tipp** startet die Session — optional mit Gasthaus, Nachricht und
  Sichtbarkeit (öffentlich, Freunde, Crew, versteckt)
- **Stealth:** Beacon ohne Position — „ich bin unterwegs", ohne zu sagen wo
- Freunde sehen die Session auf Karte und Startseite
- **„Kommst du vorbei?"** — beim Öffnen eines fremden Beacons steht die
  Frage oben: *Ich komme vorbei* oder *Ich hab keine Zeit*. Die Antwort
  ist jederzeit änderbar
- **Wer kommt und wer nicht, sehen alle**, die den Beacon sehen dürfen —
  nicht nur der Gastgeber
- Zuprosten geht unabhängig davon: „kann heute nicht, trink eins auf mich"
- Check-ins während der Session werden ihr zugeordnet
- Beenden jederzeit; sonst endet sie nach 3 Stunden von selbst

## Technische Umsetzung

- **Dateien:** `features/session/start_session_screen.dart`,
  `session_detail_screen.dart`, `widgets/session_card.dart`
- **Server:** `sessions` (0001) mit `location` (PostGIS, `null` bei
  Stealth), `visibility`, `crew_id`, `expires_at`;
  `session_participants` für Antworten (`joined | toast | declined`,
  0047)
- **Automatisches Ende:** `end_expired_sessions()` läuft per Cron und
  schließt abgelaufene Sessions
- **Sicherheit:** RLS entscheidet über Sichtbarkeit; wer nicht darf, sieht
  die Zeile gar nicht

### Beenden ohne Verbindung (2026-08-15, Backlog A-8)

Das Beenden lief bisher als `unawaited` mit leerem `catch` — schlug es
fehl, war der Beacon **lokal** aus, auf dem Server aber weiter aktiv. Er
zeigte Freunden also weiter den Aufenthaltsort, bis der Cron ihn beim
Ablaufdatum schloss. Das konnte Stunden dauern, und die App sagte nichts.

Zwei Änderungen:

- `endMySession` gibt zurück, ob der Server es mitbekommen hat. Alle vier
  Bildschirme, die einen Beacon beenden können, melden einen Fehlschlag
  (`widgets/beacon_messages.dart` — ein Satz, nicht vier Kopien).
- `sessionReconcileProvider` schließt beim nächsten Abgleich alles, was
  der Server noch als laufend führt, obwohl lokal nichts läuft.

**Warum hier eine Warteschlange richtig ist und beim Verlängern nicht:**
Nachträgliches Beenden verringert Sichtbarkeit immer und erhöht sie nie.
Eine nachgereichte *Verlängerung* würde dagegen eine beendete Session
wiederbeleben — siehe `docs/features/23`. Dieselbe Frage, entgegengesetzte
Antwort, weil die Richtung des Schadens entgegengesetzt ist.

**Zwei Fallen beim Bau dieser Routine**, beide von Tests gefunden:

1. Die Ausnahme für den eigenen laufenden Beacon prüfte zunächst
   `isRemoteId(id)`. Das Präfix `remote-` tragen aber nur **fremde**
   Sessions — die Ausnahme griff nie und die Routine hätte den eigenen
   Beacon abgeräumt.
2. Danach las sie die eigene Session über `myActiveSessionProvider`. Der
   liefert `null`, solange `meProvider` noch lädt — beim App-Start also
   genau dann, wenn die Routine zum ersten Mal läuft. „Noch nicht
   geladen" war von „es läuft nichts" nicht zu unterscheiden, mit
   demselben Ergebnis. Sie fragt die Datenbank jetzt direkt.

Beides ist in `test/session_server_calls_test.dart` festgehalten, das
über `FakeOnlineService` erstmals den Zweig **mit** angemeldetem Konto
prüft. Dass es den vorher nicht gab, ist der Grund, warum diese Klasse
von Fehlern zweimal unbemerkt blieb.

### Ein Beacon, zwei Geräte (2026-09-02)

Ein am Telefon gestarteter Beacon war im Browser nicht zu sehen — und
umgekehrt. Das war kein Synchronisationsfehler, sondern eine
**Löschung**: Der Abgleich beim App-Start beendete serverseitig jede
eigene Session, die das Gerät lokal nicht kannte. Jedes Gerät hat aber
seine eigene lokale Datenbank; das zweite räumte damit den Beacon des
ersten ab.

Jetzt gilt die Umkehrung: Was am Server läuft und lokal fehlt, wird
**übernommen** (`myActiveSessions()` liefert die vollen Zeilen, die
lokale ID ist die Server-ID). Beendet wird am Server nur, was lokal
nachweislich beendet oder abgelaufen ist. Unbekanntes bleibt
unangetastet — es könnte das andere Gerät sein. Drei Tests in
`session_reconcile_test.dart` halten das fest; der erste ist der, der
vorher gefehlt hat: „unbekannt am Server → übernehmen, **nicht**
beenden".

### Kein Erfolg, der nicht stattfand (2026-09-02)

Der Beacon-Start setzte den Server-Aufruf `unawaited` ab und meldete
immer „deine Freunde wissen Bescheid". Offline saß der Mensch mit gutem
Gewissen im Wirtshaus und war für niemanden sichtbar. Dasselbe bei
„Prost" und „Bin dabei" auf fremde Sessions.

Jetzt liefert `startSession` `(earned, synced)`. Der Ein-Tap-Beacon
zeigt bei `synced == false` einen eigenen Zustand — „Beacon läuft, noch
nicht sichtbar" — mit **Erneut versuchen** (`resyncMySession`) und der
Wahl, lokal weiterzuführen. Das Formular sagt es in der Snackbar.
`joinSession`/`toastSession` geben zurück, ob der Gastgeber es
mitbekommen hat; die Oberfläche sagt sonst „Konnte nicht gesendet
werden". Die Texte liegen zentral in `widgets/beacon_messages.dart`,
damit vier Bildschirme dasselbe sagen.

Außerdem behauptete der Ein-Tap-Beacon „3 Stunden" im Text, während er
längst die zuletzt gewählte Laufzeit nahm — auch 30 Minuten. Der Text
nennt jetzt die echte Dauer.

### Prost und „Bin dabei“ kommen jetzt an (2026-09-03)

Beide landeten in `session_participants` — und der Gastgeber erfuhr
nichts davon: keine Benachrichtigung, und seine Session-Ansicht zeigte
nur **lokale** Teilnehmer. Der Tester sagte zu Recht „hat keine Funktion“.

Jetzt: Trigger `session_participants_notify` (0037) schreibt
`session_toast` / `session_joined` an den Gastgeber → Glocke, Banner,
Push greifen von selbst; zieht jemand zurück, verschwindet die Zeile.
Die Session-Ansicht lädt bei eigenen Sessions die Reaktionen vom Server
(`participantsOf`, `remoteParticipantsProvider`) und zeigt „Mit dabei“
und „🍻 Zugeprostet: …“.

### „Session nicht gefunden" — der Weg dorthin war zu eng (2026-09-04)

Gemeldet: Ein Klick auf den Beacon eines Freundes endete bei „Session
nicht gefunden", ebenso der Weg über einen fremden Feed.

Die Detailansicht kannte genau **zwei** Quellen: die lokale Datenbank
(eigene Sessions) und die Liste der gerade laufenden Freundes-Beacons.
Wer anders ankam, fiel durch — und „anders" waren die häufigen Wege:

- **Aus der Glocke oder einem Push.** Die Benachrichtigung trägt die
  blanke Server-UUID, kein `remote-` davor. Der Aufruf landete damit im
  Zweig für *eigene* Sessions und fragte die lokale Datenbank nach einer
  fremden Session — die dort naturgemäß nie steht.
- **Aus dem Feed eines Freundes.**
- **Schlicht zu früh.** Der Realtime-Strom baut beim Bildschirmwechsel
  neu auf; in diesen Sekunden ist die Liste leer.

Jetzt gibt es eine dritte Quelle: `SessionsApi.byId()` fragt den Server
nach genau dieser einen Session. Reihenfolge lokal → Liste → Server; die
letzte beantwortet alle drei Fälle auf einmal.

**Der leere Fall heißt jetzt etwas anderes.** Die RLS zeigt fremde
Sessions nur, solange sie laufen — „vorbei" und „nicht für dich" sehen
von außen gleich aus, und das ist Absicht (0024): Sonst wäre aus einer
Fehlermeldung ablesbar, wer wo unterwegs ist. Statt „Session nicht
gefunden" (klingt nach kaputt) steht deshalb: *Dieser Beacon ist nicht
mehr zu sehen. Beacons enden nach höchstens drei Stunden.*

### Warum eine Absage ein eigener Knopf ist (0047)

Ein Beacon ist eine Verabredung. Wer darauf klickt, will nicht lesen,
sondern antworten — und bis 0.10.13 gab es dafür nur eine Richtung:
zusagen. Wer nicht konnte, klickte weg.

Damit fehlte dem Gastgeber die halbe Information. „Drei haben zugesagt"
heißt nichts, solange offen ist, ob die anderen fünf noch überlegen oder
längst abgesagt haben. Schweigen ist mehrdeutig, und Mehrdeutigkeit ist
bei einer Verabredung teuer: Man wartet auf jemanden, der nie kommt.

Deshalb ist „ich hab keine Zeit" eine Antwort und kein Nicht-Klick — und
sie steht in der Teilnehmerliste unter „Kann heute nicht", für alle
sichtbar, die den Beacon sehen dürfen. Das regelt keine neue Policy:
`session_participants_select` (0001) hängt an der Sichtbarkeit der
Session selbst. Wer den Beacon nicht sieht, sieht auch die Antworten
nicht.

**Zuprosten bleibt daneben.** Es beantwortet eine andere Frage: Man kann
aus der Ferne zuprosten *und* absagen — das ist sogar der häufigste Fall.
Was sich ausschließt, ist Zusage gegen Absage; das räumt der Client beim
Antworten weg, weil der Schlüssel `(session, profil, art)` sonst beide
Zeilen nebeneinander stehen ließe.

**Die Frage steht als Karte, nicht als Dialog.** Ein Dialog beim Öffnen
verlangt eine Antwort, bevor man weiß, worauf man antwortet: wo, seit
wann, wer ist schon da, wie lange noch. Die Frage gehört an den Anfang
des Bildschirms — nicht davor.

## Modularität

- **Hängt ab von:** Konto (01), Freunde (08), Gasthäuser (05, optional),
  Crews (09, optional)
- **Wird gebraucht von:** Karte (06), Abzeichen (Session-Zähler)
- **Ausbauen:** Feature-Ordner, Karten-Ebene und Startseiten-Karte
  entfernen; `sessionId` am Check-in leer lassen.

## Plattformen

Alle. Ohne Standort funktioniert der Beacon als Stealth-Variante — das ist
kein Notbehelf, sondern eine vollwertige Betriebsart.

## Skalierung

`sessions_active_idx` deckt die häufigste Abfrage ab. Der Zähler für
fremde Aktive ist eine Aggregatfunktion und unkritisch. Kürzere Laufzeiten
([Funktion 23](23-beacon-laufzeit.md)) verringern die Zahl gleichzeitig
aktiver Sessions zusätzlich.

## Umsetzungsstatus

Funktional vollständig.

- ~~**Laufzeit fest** bei 3 Stunden~~ — seit 0.9.14 wählbar, verlängerbar
  und serverseitig begrenzt ([Funktion 23](23-beacon-laufzeit.md))
- ~~**Keine Benachrichtigung**~~ — seit 0.10.10 weckt 0039 genau die, die
  den Beacon auch sehen dürfen
- ~~**Nur zusagen möglich**~~ — seit 0.10.13 auch absagen (0047)

Abgesichert durch `test/beacon_zusagen_test.dart` (9 Widget-Tests: die
blanke UUID aus der Glocke findet die Session, der leere Fall sagt warum,
zu- und absagen, A-8 bei fehlender Verbindung, fremde Antworten stehen
nebeneinander) und `supabase/tests/beacon_zusagen.test.sql`
(9 Prüfungen in der Rolle `authenticated`: eine Absage kommt als Absage
an, nur der Gastgeber wird geweckt, Umentscheiden hinterlässt genau eine
Antwort, Prost verdrängt sie nicht, und niemand antwortet in fremdem
Namen).

## Umsetzungsplan

1. ~~[Laufzeit wählbar](23-beacon-laufzeit.md) inklusive Restanzeige und
   Verlängern~~ — erledigt (0.9.14)
2. ~~Push-Nachrichten beim Start einer Freundes-Session~~ — erledigt
   (0039, 0.10.10)
3. ~~Zu- und Absagen, für alle sichtbar~~ — erledigt (0047, 0.10.13)
4. Sichtbarkeit nach [Freundeskreisen](24-freundeskreise.md)

## Offene Punkte / Ideen

- Geplante Sessions („morgen 19 Uhr") mit Zusage — die Zusage selbst gibt
  es jetzt; es fehlt nur der Termin in der Zukunft
- Wiederkehrender Stammtisch
