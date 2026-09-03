# 36 Rückgängig statt Rückfrage

> **Status:** 🟡 teilweise — drei Aktionen umgestellt (Beacon beenden,
> Anfrage ablehnen, Wunschliste); die übrigen Rückfragen stehen noch.
> **Seit:** 0.10.10-beta · **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Ein Fehltipp soll etwas kosten dürfen — aber nicht die Runde, den Freund
oder die gemerkten Biere.

Der übliche Reflex dagegen ist die Rückfrage: „Wirklich beenden?" Sie
bestraft die 99 %, die es so gemeint haben, für den einen, der danebentippt
— und sie wirkt nicht einmal, weil ein Dialog, der bei jeder Aktion
erscheint, nach der dritten Woche blind weggetippt wird. Der Ausweg
hinterher kostet niemanden etwas und hilft genau dem, der ihn braucht.

**Woran man merkt, dass es funktioniert:** Niemand muss eine beendete Runde
neu starten oder einen Freund bitten, die Anfrage noch einmal zu stellen.

## Funktion (Nutzersicht)

Nach der Aktion erscheint unten eine Meldung mit **„Rückgängig"**. Fünf
Sekunden lang. Wer nichts tut, für den bleibt alles, wie es war — die
Aktion gilt.

Drei Stellen, drei Ausgänge:

| Aktion | Nach „Rückgängig" |
|---|---|
| **Beacon beenden** | Der Beacon läuft weiter — dieselbe Runde, dieselbe Restlaufzeit, dieselben Leute |
| **Freundschaftsanfrage ablehnen** | Die Anfrage steht wieder in der Liste, als wäre nichts gewesen |
| **Bier von der Wunschliste** | Das Bier ist zurück auf der Liste |

Sonderfälle, die die App ausspricht statt zu schweigen:

- **Der Beacon wäre inzwischen abgelaufen.** Dann kommt er nicht zurück,
  und die Meldung sagt das: „starte einfach einen neuen". Ein
  wiederbelebter Beacon, der die Laufzeitgrenze aus Migration 0021
  umgeht, wäre ein Schleichweg.
- **Der Server hat das Wiederbeleben nicht übernommen.** Dann läuft der
  Beacon nur auf dem eigenen Gerät, und genau das steht da — Regel A-8.
- **Das Ablehnen scheitert am Server.** Die Anfrage kommt sichtbar zurück.
  Wer glaubt, abgelehnt zu haben, rechnet nicht mehr damit, gesehen zu
  werden; eine stille Fehlmeldung wäre hier besonders folgenreich.
- **Die App stirbt in den fünf Sekunden** (Absturz, Akku leer). Bei der
  Anfrage passiert dann gar nichts: Sie bleibt offen und ist beim nächsten
  Start wieder da. Das ist die harmlose Richtung — eine Anfrage zu viel
  ist ärgerlich, eine fälschlich gelöschte ist weg.

## Technische Umsetzung

**Drei Aktionen, drei Mechaniken.** Das ist kein Wildwuchs, sondern folgt
daraus, was die Aktion jeweils ist:

### 1. Beacon beenden — sofort tun, danach wiederbeleben

- **Dateien:** `widgets/beacon_messages.dart`
  (`beaconBeendenMitRueckgaengig`), `data/providers.dart`
  (`endMySession`, `undoEndMySession`), `data/db/database.dart`
  (`reviveSession`)
- Ein laufender Beacon zeigt Freunden den Aufenthaltsort. Wer „Beenden"
  tippt, will **in dieser Sekunde** unsichtbar sein, nicht in fünf. Also
  wird wirklich beendet — lokal und am Server — und „Rückgängig" startet
  dieselbe Zeile neu (`status = active`, `ended_at = null`, per
  `upsertSession` gespiegelt).
- `expires_at` bleibt unangetastet: Ein wiederbelebter Beacon läuft genau
  so lange weiter, wie er ohne den Fehltipp gelaufen wäre.
- Ist er schon abgelaufen, gibt `undoEndMySession` `null` zurück und rührt
  weder Datenbank noch Server an.
- Der Weg liegt in `widgets/`, weil **vier** Bildschirme den Beacon
  beenden können (Startseite, Beacon-Ansicht, Session-Detail, Banner in
  der Hülle) und Features einander nicht importieren dürfen. Vier Kopien
  würden auseinanderlaufen — genau das war vor dieser Änderung der Fall.

### 2. Anfrage ablehnen — nicht rückgängig, sondern aufgeschoben

- **Dateien:** `data/providers/anfragen.dart` (`AbgelehnteAnfragen`,
  `offeneAnfragenProvider`), `widgets/friend_request_card.dart`,
  `features/friends/friends_screen.dart`
- **Warum anders:** Ablehnen löscht die Zeile in `friendships`.
  Wiederherstellen könnte nur der andere — `friendships_insert` verlangt
  `requester_id = auth.uid()`, und das ist er, nicht ich. Ein
  „Rückgängig", das den Server um etwas bittet, was er ablehnen **muss**,
  wäre ein Versprechen ohne Deckung.
- Also andersherum: Die Anfrage verschwindet sofort aus allen Listen, der
  Serveraufruf kommt erst nach der Frist. „Rückgängig" kostet dann keinen
  Aufruf — es verhindert einen.
- **`offeneAnfragenProvider` ist der eigentliche Gewinn.** Fünf Stellen
  zeigten die Anfragen: zwei Listen, der Zähler am Glockensymbol, die
  Kennzahl im Profil, die Karte auf der Startseite. Jede hätte den Filter
  einzeln gebraucht, und eine hätte ihn vergessen — der Zähler zeigt 1,
  die Liste darunter ist leer. Der Filter steht deshalb genau einmal da.

### 3. Wunschliste — ein Umschalter ist sein eigenes Rückgängig

- **Datei:** `features/profile/wishlist_screen.dart`
- `toggleWishlist` noch einmal, fertig. Kein Zustand, den die Oberfläche
  zwischenlagern müsste.

### Datenmodell

Nichts Neues. `reviveSession` schreibt in die bestehende
`sessions`-Tabelle, `AbgelehnteAnfragen` hält seinen Zustand nur im
Speicher — er soll einen Neustart ausdrücklich **nicht** überleben.

### Sicherheit

Keine neuen Rechte. Das Wiederbeleben läuft über dasselbe
`upsertSession`, das auch der Start benutzt (`host_id = auth.uid()`), und
die Laufzeitgrenze aus 0021 gilt unverändert.

## Modularität

- **Hängt ab von:** Sessions (07), Freunde (08), Wunschliste (14)
- **Wird gebraucht von:** nichts — es ist eine Verhaltensschicht, keine
  eigene Oberfläche
- **Ausbauen:** `beaconBeendenMitRueckgaengig` durch den direkten
  `endMySession`-Aufruf ersetzen, `providers/anfragen.dart` löschen und
  die fünf Stellen wieder auf `friendRequestsProvider` zeigen lassen, die
  Snackbar-Aktion in der Wunschliste entfernen.

## Plattformen

Android · Web · Windows · iOS · macOS — überall gleich. Snackbars sind
reines Flutter, kein plattformgebundenes Paket, keine Weiche.

## Skalierung

Unkritisch. `AbgelehnteAnfragen` hält eine Menge von IDs, die praktisch
nie mehr als eine Handvoll umfasst; `offeneAnfragenProvider` filtert eine
Liste, die schon aus fachlichen Gründen kurz ist. Der aufgeschobene
Aufruf ist genau ein Aufruf, nur später.

## Umsetzungsstatus

**Umgestellt:** Beacon beenden (4 Aufrufstellen), Anfrage ablehnen (2
Aufrufstellen), Wunschlisten-Eintrag entfernen.

**Bewusst nicht umgestellt** — hier bleibt die Rückfrage richtig:

- **Konto löschen** (`account_screen.dart`): unumkehrbar, serverseitig,
  Play-Store-Pflicht. Eine 5-Sekunden-Frist wäre hier zu wenig.
- **Check-in löschen** (`checkin_card.dart`): hat **beides** — Rückfrage
  *und* „Rückgängig". Die Rückfrage nennt das Bier, damit im Feed nicht
  der falsche Eintrag erwischt wird; das ist eine Zielhilfe, keine
  Sicherheitsabfrage.
- **Crew auflösen**, **Freundschaft beenden**, **blockieren**: betreffen
  andere Menschen und sind selten. Hier ist die Rückfrage der ehrlichere
  Moment.

Abgesichert durch `test/rueckgaengig_test.dart` (9 Tests: Beacon
wiederbeleben, Laufzeit unverändert, abgelaufener Beacon, Serverfehler;
aufgeschobenes Ablehnen, Zurücknehmen ohne Serveraufruf, Serverfehler,
zwei parallele Ablehnungen, Zähler = Liste) und zwei Widget-Tests in
`test/friend_request_home_test.dart`.

## Umsetzungsplan

Erledigt für die drei Aktionen aus dem Roadmap-Punkt. Offen:

1. **„Später" und „Rückgängig" zusammenführen** — auf der Startseite gibt
   es beides, und der Unterschied ist erklärungsbedürftig.
2. **Frist prüfen.** Fünf Sekunden sind gesetzt, nicht gemessen. Sobald
   es echte Nutzung gibt: Wie oft wird „Rückgängig" überhaupt gedrückt,
   und wie schnell?

## Offene Punkte / Ideen

- Ein zweiter Fehltipp-Kandidat wäre das **Verlassen einer Crew** —
  heute mit Rückfrage, technisch aber genauso aufschiebbar wie das
  Ablehnen.
- Denkbar: eine gemeinsame Bauart für „aufgeschobene Aktion", falls eine
  dritte dazukommt. Bei zwei Fällen wäre das verfrüht — die beiden
  unterscheiden sich mehr, als sie sich ähneln.
