# 24 Freundeskreise

> **Status:** 🔴 geplant — Freundschaften sind heute eine flache Menge:
> entweder alles sehen oder kein Freund sein.
> **Geplant für:** 0.10.0-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

BrewMates zeigt, wo jemand ist und was er trinkt. Das sind Informationen,
die man abgestuft teilt: Der Arbeitskollege darf wissen, dass man
unterwegs ist — der beste Freund darf wissen, wo. Heute gibt es diese
Abstufung nicht, also gilt für alle dieselbe Nähe, und das drückt die
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
- Ein Einstellungsbereich „Wer sieht was" zeigt die Stufen als Tabelle:

| | Bekannte | Freunde | Best Buddys |
|---|---|---|---|
| Meine Check-ins im Feed | ✅ | ✅ | ✅ |
| Dass ich unterwegs bin | ✅ | ✅ | ✅ |
| **Wo** ich bin (Karte) | ❌ | ✅ | ✅ |
| Meine Bierlaune | ❌ | ✅ | ✅ |
| Gasthaus meiner Session | ❌ | ✅ | ✅ |

Die Aufteilung ist die Vorgabe, nicht das Gesetz: Wer die Karte auch
Bekannten zeigen will, darf das je Zeile umstellen.

- Die Freundesliste lässt sich nach Kreis filtern.
- Beim Starten einer Session lässt sich die Sichtbarkeit weiterhin
  einzeln wählen — neu kommt „nur Best Buddys" dazu.

## Technische Umsetzung

- **Server:** Migration — `friendships.requester_tier` und
  `friendships.addressee_tier`, beide `not null default 'freund'`, dazu
  ein Aufzählungstyp `friend_tier ('bekannter', 'freund', 'buddy')`.
  Eine Zeile je Paar, zwei Bewertungen: Wer in welcher Spalte steht,
  ergibt sich aus der Richtung.
- **Neue Funktion:** `tier_for(owner uuid, viewer uuid)` — welchen Kreis
  hat *owner* dem *viewer* zugewiesen. Sie ist die Grundlage aller
  Sichtbarkeitsregeln: **Der Besitzer der Information entscheidet**, nicht
  der Betrachter.
- **RLS anzupassen:** `sessions` (Position), `profiles.thirsty_until`
  (Bierlaune), Karten-Abfragen. Alle heutigen `are_friends(…)`-Aufrufe
  werden geprüft und dort, wo es um Ort oder Laune geht, durch
  `tier_for(…) >= 'freund'` ersetzt.
- **App:** `features/friends/` (Kreis-Menü, Filter), neuer
  Einstellungsbereich, `data/online/friends_api.dart` (nach dem neuen
  Modulschnitt eine eigene Datei).

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

## Umsetzungsplan

1. **Datenmodell.** Aufzählungstyp, zwei Spalten mit Vorgabe `freund`,
   `tier_for()` mit gezielter Rechtevergabe (Konvention aus 0008).
   *Prüfkriterium:* bestehende Freundschaften verhalten sich unverändert.
2. **Sichtbarkeit serverseitig.** Policies für Position und Bierlaune auf
   `tier_for` umstellen.
   *Prüfkriterium:* SQL-Test unter simulierten Rollen — ein „Bekannter"
   bekommt die Position nicht, auch nicht über die reine API.
3. **Bedienung.** Kreis-Menü in der Freundesliste, Filter.
   *Prüfkriterium:* Widget-Test — Umstufen wirkt sofort.
4. **„Wer sieht was".** Einstellungen je Zeile, gespeichert am Profil.
5. **Session-Sichtbarkeit** „nur Best Buddys" ergänzen.

## Offene Punkte / Ideen

- Vierter Kreis „stumm" (befreundet, aber nicht im Feed) — erst bauen,
  wenn jemand danach fragt; Blockieren deckt den harten Fall bereits ab
- Später: Kreise als Vorschlag aus der Häufigkeit gemeinsamer Sessions
