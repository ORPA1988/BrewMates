# 07 Sessions & Beacons

> **Status:** 🟡 teilweise — funktioniert vollständig; es fehlen
> Benachrichtigungen, damit Beacons auch ungeöffnete Apps erreichen.
> **Seit:** 0.2.0 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Der Beacon ist die Einladung: „Ich sitze hier, kommt vorbei." Er ersetzt
die Rundmail an fünf Leute, von denen vier zu spät antworten. Ein Tipp,
und die Freunde wissen Bescheid.

## Funktion (Nutzersicht)

- **Ein Tipp** startet die Session — optional mit Gasthaus, Nachricht und
  Sichtbarkeit (öffentlich, Freunde, Crew, versteckt)
- **Stealth:** Beacon ohne Position — „ich bin unterwegs", ohne zu sagen wo
- Freunde sehen die Session auf Karte und Startseite und können beitreten
- Check-ins während der Session werden ihr zugeordnet
- Beenden jederzeit; sonst endet sie nach 3 Stunden von selbst

## Technische Umsetzung

- **Dateien:** `features/session/start_session_screen.dart`,
  `session_detail_screen.dart`, `widgets/session_card.dart`
- **Server:** `sessions` (0001) mit `location` (PostGIS, `null` bei
  Stealth), `visibility`, `crew_id`, `expires_at`;
  `session_participants` für Beitritte
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

Funktional vollständig. Zwei Einschränkungen:

- ~~**Laufzeit fest** bei 3 Stunden~~ — seit 0.9.14 wählbar, verlängerbar
  und serverseitig begrenzt ([Funktion 23](23-beacon-laufzeit.md))
- **Keine Benachrichtigung:** Wer die App nicht öffnet, erfährt vom Beacon
  eines Freundes nichts. Das ist die größte Lücke der Funktion und hängt
  an Push-Nachrichten (Firebase), die noch nicht eingerichtet sind.

## Umsetzungsplan

1. ~~[Laufzeit wählbar](23-beacon-laufzeit.md) inklusive Restanzeige und
   Verlängern~~ — erledigt (0.9.14)
2. Push-Nachrichten beim Start einer Freundes-Session — mit strengen
   Regeln gegen Belästigung: nur beim Start, höchstens alle 15 Minuten je
   Empfänger, abschaltbar
3. Sichtbarkeit nach [Freundeskreisen](24-freundeskreise.md)

## Offene Punkte / Ideen

- Geplante Sessions („morgen 19 Uhr") mit Zusage
- Wiederkehrender Stammtisch
