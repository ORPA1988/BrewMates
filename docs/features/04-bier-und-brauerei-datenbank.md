# 04 Bier- & Brauerei-Datenbank

> **Status:** 🟢 fertig — 654 Biere und 137 Brauereien aus dem DACH-Raum,
> kuratiert im Repository, per GitHub aktualisiert.
> **Seit:** 0.4.0 (AT), DACH seit 0.9.13 · **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Eine App, die beim ersten Start leer ist, wird nicht benutzt. Die
kuratierte Datenbank sorgt dafür, dass das erste gescannte Bier gefunden
wird — mit Beschreibung, Bewertung, Etikett und Brauerei dahinter.

Der Fokus liegt auf dem DACH-Raum, Herz Österreich und Bayern: lieber eine
Region gut als die Welt schlecht.

## Funktion (Nutzersicht)

- Suche über Biere **und** Brauereien, Filter nach Stil
- Bierseite: Beschreibung (Hersteller und Community), Bewertung,
  Alkoholgehalt, Etikettfoto, Brauerei — und zurück zu allen Bieren dieser
  Brauerei
- Brauereiseite: Ort, Gründung, Eigentümer, Kennzahlen, Karte
- Fehlt etwas: „Korrektur vorschlagen" öffnet ein vorbefülltes
  GitHub-Issue; neue Biere legt man direkt in der App an

## Anlegen ohne Pflichtfelder (2026-08-15)

Bis dahin verlangte das Formular fünf Angaben: Name, Stil, Brauerei, Land,
Stadt. Wer ein unbekanntes Bier scannte, musste erst ein Formular ausfüllen,
bevor er einchecken konnte — obwohl er nur trinken und festhalten wollte.

**Nichts ist mehr Pflicht.** Fehlt alles, entsteht ein Eintrag aus EAN und
„Unbekanntes Bier". Das ist ehrlicher als eine erratene Angabe und
jederzeit nachtragbar: Community-Bearbeitung gibt es seit Migration 0013
ab Vertrauensstufe 2, serverseitig über RLS erzwungen und im `edit_log`
protokolliert.

Die Beschriftungen heißen jetzt **Marke** und **Sorte/Typ** statt Name und
Stil. Die Datenfelder bleiben `name` und `style` — eine Umbenennung im
Bestand wäre ein Datenumbau ohne Nutzen für den Menschen davor.

**Die Lupe neben „Marke"** durchsucht den vorhandenen Bestand. Sie ist für
den häufigsten Fall da: Das Bier ist längst erfasst und hat nur diese eine
EAN noch nicht. Auswählen hängt den Code dort an — ein Duplikat wäre der
teuerste Fehler, den man hier machen kann.

Seit 0.10.3 muss man die Lupe dafür nicht mehr finden: Passende Biere
erscheinen beim Tippen von selbst unter der Zeile — siehe
[Live-Vorschläge](28-live-vorschlaege.md).

**Die Gebindegröße** gehört zum Barcode, nicht zum Bier (siehe Funktion
03). Vorbelegt ist ein halber Liter.

## Überarbeitung Österreich (2026-09-02)

Der Ausbau vom 2026-08-15 hatte einen zweiten Datensatz **neben** den
bestehenden Bestand gelegt, statt ihn hineinzuarbeiten. Ergebnis: 25
Brauereien standen doppelt in der Datei — einmal redaktionell gepflegt
(`at-stiegl`, mit Webseite, Eigentümer und Geschichte), einmal aus der
Zweitquelle (`at-stiegl-2`, ohne all das, mit abweichendem Gründungsjahr
und leicht verschobenen Koordinaten). Wer nach „Stiegl“ suchte, fand zwei
Brauereien und musste raten.

Bereinigt wurde in einem Zug:

- **Brauereien 71 → 46.** Jede Dublette auf den gepflegten Datensatz
  zusammengeführt. Neu getrennt sind dafür **Kaiser** (gebraut in
  Wieselburg) und **Edelweiss** (Hofbräu Kaltenhausen) — sie hingen an
  einer gemeinsamen Sammel-ID, obwohl es zwei Marken zweier Standorte
  sind.
- **Biere 487 → 442.** 41 Dubletten zusammengeführt (Barcodes, Bilder und
  Beschreibungen wandern dabei auf den Gewinner), vier Einträge
  gestrichen, die keine Biere sind: ein Bieressig, zwei
  Sortiments-Sammelposten und ein Bierabo. Vier belegte Sorten kamen neu
  dazu.
- **IDs entschärft.** `at-brauerei-pils`, `at-brauerei-maerzen`,
  `at-brauhaus-red-ale` — solche IDs gehören keiner Brauerei und
  kollidieren mit dem nächsten Import. Sie heißen jetzt
  `at-vitzthum-uttendorfer-pils`, `at-starkenberger-maerzen`,
  `at-gusswerk-red-ale`.
- **Namen mit Marke.** Ein Eintrag, der nur „Märzen“ heißt, ist in einer
  Suchliste wertlos. Rund 130 Namen tragen jetzt ihre Marke vorn.
- **Stile vereinheitlicht.** 162 freie Schreibweisen („Vollbier“,
  „Klassiker“, „Bierspezialität“, halbe Zutatenlisten) auf 49 Stile
  gezogen; wo der Name den Stil eindeutig nennt, wurde er abgeleitet. 83
  Einträge stehen weiter auf „Bier“ — dort veröffentlicht die Brauerei
  nichts, und Raten wäre schlechter als Schweigen.
- **Bilder.** Alle 352 Bild-URLs einzeln abgerufen; acht tote von Murauer
  ersetzt, 30 fehlende aus Open Food Facts ergänzt. Kein Bild ohne
  `image_source`.

Die EAN-Zuordnung war der eigentliche Anlass — siehe
[03 Barcode-Scanner](03-barcode-scanner.md).

**Was das für bestehende Installationen heißt:** Der Abgleich schreibt
nur, er löscht nie (`insertAllOnConflictUpdate`). Zusammengeführte und
umbenannte Einträge bleiben auf dem Gerät also als verwaiste Zeilen
liegen — vorhandene Check-ins zeigen weiter auf ihr Bier, aber die Suche
kann eine alte Dublette noch anzeigen. Ein Neuinstallieren räumt das auf;
ein Aufräumschritt im Abgleich wäre die saubere Lösung und steht offen.

## Technische Umsetzung

- **Daten:** `app/assets/data/` — acht Dateien
  (`beers|breweries` × `at|by|de|ch`), verknüpft über `brewery_id`.
  Bestand (gezählt 2026-09-02, nach der Österreich-Überarbeitung):
  654 Biere (AT 442, BY 72, DE 95, CH 45) und 137 Brauereien
  (AT 46, BY 33, DE 40, CH 18)
- **Abgleich:** `data/community_sync.dart` — gebündelt beim ersten Start,
  danach von `raw.githubusercontent.com`; fehlende Dateien werden
  übersprungen, nicht als Fehler behandelt
- **Nutzerbeiträge:** liegen in Supabase (`beers`, `breweries`, ab 0010),
  nicht in den JSON-Dateien
- **Herkunft:** Etikettbilder und EANs von Open Food Facts (CC-BY-SA /
  ODbL), Koordinaten teils von Nominatim — dokumentiert in
  `DATENHERKUNFT.md`

**Die Trennlinie:** Kuratierte Datensätze sind in der App **schreibgeschützt**
— der GitHub-Abgleich überschreibt sie vollständig. Bearbeitbar sind nur
Einträge aus Supabase. Wer das vermischt, verliert Nutzerkorrekturen beim
nächsten Abgleich.

## Modularität

- **Hängt ab von:** nichts
- **Wird gebraucht von:** Check-ins, Scanner, Karte, Statistiken
- **Ausbauen:** nicht sinnvoll — ohne Bierdatenbank keine App.

## Plattformen

Alle. Reine Daten.

## Skalierung

Acht JSON-Dateien werden beim Start **vollständig** gelesen und in die
lokale DB geschrieben; die Assets sind zusammen rund 480 KB (654 Biere,
137 Brauereien). Das trägt gut bis etwa zum Dreifachen. Darüber hinaus — oder mit
[Hintergrundgeschichten](21-hintergrundgeschichten.md) — gehört der
Bestand serverseitig durchsucht statt vollständig mitgeliefert.

Die Barcode-Suche über eine kommagetrennte Liste ist der zweite Punkt, der
irgendwann eine eigene Tabelle braucht.

## Umsetzungsstatus

Vollständig für den DACH-Raum. Die Abdeckung ist bewusst kuratiert, nicht
vollständig: Flaggschiffe und regionale Charakterköpfe statt jedes
Saisonbiers.

## Umsetzungsplan

1. [Hintergrundgeschichten](21-hintergrundgeschichten.md) je Bier und
   Brauerei
2. Fortlaufende Pflege der Nutzereinträge bei **jedem** Entwicklungslauf
   (siehe [docs/10](../10-community-datenpflege.md))
3. Später: serverseitige Suche statt vollständiger lokaler Kopie

## Offene Punkte / Ideen

- Aufräumschritt im Abgleich: zusammengeführte IDs auf bestehenden
  Installationen entfernen statt liegen lassen
- Alkoholgehalt für die 115 Biere ohne Angabe — die Brauereien
  veröffentlichen ihn größtenteils nicht auf der Webseite
- Weitere Regionen (Tschechien, Belgien) — erst, wenn DACH gepflegt bleibt
- Saisonbiere und Sondersude, wenn es eine Pflege-Community gibt
