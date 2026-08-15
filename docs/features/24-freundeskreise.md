# 24 Freundeskreise

> **Status:** 🟢 fertig — drei Kreise, serverseitig durchgesetzt für
> Beacon-Position und Bierlaune.
> **Seit:** 0.10.0-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

BrewMates zeigt, wo jemand ist und was er trinkt. Das sind Informationen,
die man abgestuft teilt: Der Arbeitskollege darf wissen, dass man
unterwegs ist — der beste Freund darf wissen, wo. Bis 0.10 gab es diese
Abstufung nicht, also galt für alle dieselbe Nähe, und das drückt die
Zahl der Freundschaften, die man überhaupt eingeht.

Drei Kreise: **Bekannte · Freunde · Best Buddys.**

**Die Einteilung ist einseitig und privat.** Jeder entscheidet für sich,
wen er wie einordnet; der andere erfährt es nicht. Alles andere wäre eine
Kränkungsmaschine — niemand soll lesen können, dass er zu den „Bekannten"
zählt.

## Funktion (Nutzersicht)

- In der Freundesliste hat jeder Eintrag einen Kreis, änderbar über ein
  Menü. Neue Freundschaften starten als **Freunde** — genau das heutige
  Verhalten.
- „Wer sieht was" in der Freundesliste zeigt die Stufen als Tabelle:

| | 👋 Bekannte | 🍺 Freunde | 🍻 Best Buddys |
|---|---|---|---|
| Meine Check-ins im Feed | ✅ | ✅ | ✅ |
| Mein Profil und meine Abzeichen | ✅ | ✅ | ✅ |
| Meine Beacons auf der Karte | ❌ | ✅ | ✅ |
| Wo ich gerade bin | ❌ | ✅ | ✅ |
| Meine Bierlaune | ❌ | ✅ | ✅ |

- Die Freundesliste lässt sich nach Kreis filtern (ab fünf Freunden —
  vorher wären die Chips nur Lärm).
- „Wer sieht was" zeigt die Tabelle in der App, damit niemand raten muss,
  was ein Kreis bewirkt.

**Abweichung vom ersten Entwurf:** Dort stand, Bekannte sollten sehen,
*dass* jemand unterwegs ist, nur nicht *wo*. Das ließ sich nicht ehrlich
durchsetzen — die Begründung steht unter „Technische Umsetzung". Bekannte
sehen den Beacon jetzt gar nicht und zählen stattdessen in die aggregierte
Zahl „weitere BrewMates aktiv", wie Fremde auch.

## Technische Umsetzung

- **Server (0024):** Aufzählungstyp
  `friend_tier ('bekannter', 'freund', 'buddy')` — die Reihenfolge trägt
  die Vergleiche, `>= 'freund'` funktioniert dadurch ohne Umrechnung.
  Dazu `friendships.requester_tier` und `addressee_tier`, beide
  `not null default 'freund'`: eine Zeile je Paar, zwei Bewertungen.
- **`tier_for(owner, viewer)`** — welchen Kreis hat *owner* dem *viewer*
  zugewiesen. **Der Besitzer der Information entscheidet**, nicht der
  Betrachter. Sie stützt sich auf `are_friends` und erbt damit dessen
  Härtung (Blockierung, nur eigene Paare).
- **`set_friend_tier(other, tier)`** schreibt ausschließlich die eigene
  Spalte — die Gegenrichtung bleibt unberührt und unsichtbar.
- **App:** `features/friends/friends_screen.dart` (Kreis-Menü, Filter,
  „Wer sieht was"), `FriendTier` in `data/online/online_service.dart`.
- **`count_other_active_sessions`** zieht mit: Der Zähler enthält genau
  das, was die Policy verbirgt. Dazu gehört seit 0024 auch der
  Crew-Ausschluss — eine Crew-Session sehe ich als Mitglied unabhängig
  vom Kreis, sie darf also nicht zusätzlich in die Zahl. Bis dahin
  erschien ein nicht befreundeter Crew-Kollege doppelt: als Punkt auf
  der Karte **und** in „weitere BrewMates aktiv".

### Warum Bekannte den Beacon gar nicht sehen

Der Entwurf wollte die Zeile zeigen und nur die Koordinaten ausblenden.
Das geht mit RLS nicht: Sie wirkt **zeilenweise**, nicht spaltenweise.
Eine Spalte je Betrachter zu maskieren bräuchte eine eigene Tabelle für
die Positionen oder einen Funktionsaufruf statt der Tabelle — und der
Realtime-Strom, über den die Karte lebt, hängt an der Tabelle.

Die Alternative wäre gewesen, die Koordinaten mitzuliefern und die App
nicht hinschauen zu lassen. Das ist kein Schutz: Die Position stünde
trotzdem in der Antwort. **Eine Regel, die nur die App befolgt, ist
keine.** Also verbirgt die Policy die ganze Zeile — weniger Funktion,
aber echte Durchsetzung.

Der Kartenzähler musste mitziehen: Er zählte „keine Freunde", jetzt zählt
er alles, was ich nicht als Beacon sehen darf. Sonst wären die Sessions
der Bekannten aus Karte **und** Zahl verschwunden.

### Bierlaune: Spaltenrechte statt Zeilenregel

`thirsty_until` steht auf `profiles`, und ein Profil muss für Freunde
sichtbar bleiben — die Zeile zu verbergen scheidet aus. Deshalb hier der
andere Weg: Das `select`-Recht auf die **Spalte** ist entzogen, gelesen
wird über `my_thirsty_until()` (eigene) und `thirsty_friends()` (fremde,
serverseitig auf Kreis „Freund" gefiltert).

Vorher holte die App die ganze Freundesliste und filterte selbst — die
Bierlaune lag damit auf jedem Gerät, das danach fragte.

**Der Default trägt die Migration.** Weil beide Spalten mit `freund`
starten, ändert sich für bestehende Freundschaften nichts — die Funktion
ist von Tag eins an rückwärtskompatibel, und niemand verliert über Nacht
Sichtbarkeit, die er hatte.

**Sicherheitsregel:** Die Abstufung muss serverseitig durchgesetzt sein.
Eine Position, die die App nur ausblendet, ist nicht geschützt — sie steht
weiterhin in der Antwort. Deshalb liegt die Logik in den Policies, nicht
im Client.

## Modularität

- **Hängt ab von:** Freunde (08), Sessions (07), Karte (06)
- **Wird gebraucht von:** alles, was Sichtbarkeit kennt — das macht die
  Funktion zur invasivsten im Plan
- **Ausbauen:** aufwendig. `tier_for` müsste wieder auf „alle Freunde
  gleich" zurückfallen; die Spalten könnten bleiben. Deshalb: **eine
  einzige Funktion** entscheidet, nicht verstreute Bedingungen — dann ist
  der Rückbau eine Zeile.

## Plattformen

Alle. Reine Daten- und Regelfrage.

## Skalierung

`tier_for` läuft in Policies, also potenziell je Zeile. Sie muss `stable`
und indexgestützt sein (`friendships` hat bereits Indizes auf beiden
Richtungen). Bei der Gelegenheit prüfen, ob `are_friends` heute schon
teuer ist — beide Funktionen teilen dasselbe Zugriffsmuster.

## Umsetzungsstatus

Datenmodell, serverseitige Durchsetzung und Bedienung stehen. Die
Migration ändert am Tag der Einführung nichts: Beide Spalten starten auf
`freund`, niemand verliert über Nacht Sichtbarkeit.

Abgesichert durch `test/friend_tier_test.dart` (7 Tests): Reihenfolge
passend zum Aufzählungstyp, Hin- und Rückweg über die Datenbanknamen,
Rückfall auf `freund` statt `bekannter` bei Unbekanntem, Vorgabe neuer
Profile, Bierlaune-Ablauf.

**Noch offen:** „Wer sieht was" ist heute eine Erklärung, keine
Einstellung — die Aufteilung ist fest. Und die Session-Sichtbarkeit „nur
Best Buddys" fehlt; heute gibt es weiterhin öffentlich, Freunde, Crew und
versteckt.

## Umsetzungsplan

1. **Sichtbarkeit je Zeile einstellbar** machen (wer die Karte auch
   Bekannten zeigen will, soll das dürfen)
2. **Session-Sichtbarkeit „nur Best Buddys"** beim Beacon-Start

## Offene Punkte / Ideen

- Vierter Kreis „stumm" (befreundet, aber nicht im Feed) — erst bauen,
  wenn jemand danach fragt; Blockieren deckt den harten Fall bereits ab
- Später: Kreise als Vorschlag aus der Häufigkeit gemeinsamer Sessions
