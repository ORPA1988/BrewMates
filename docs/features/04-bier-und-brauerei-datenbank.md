# 04 Bier- & Brauerei-Datenbank

> **Status:** 🟢 fertig — 659 Biere und 137 Brauereien aus dem DACH-Raum,
> kuratiert im Repository, per GitHub aktualisiert.
> **Seit:** 0.4.0 (AT), DACH seit 0.9.13 · **Zuletzt geprüft:** 2026-09-03

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
- **Biere 487 → 447.** 41 Dubletten zusammengeführt (Barcodes, Bilder und
  Beschreibungen wandern dabei auf den Gewinner), vier Einträge
  gestrichen, die keine Biere sind: ein Bieressig, zwei
  Sortiments-Sammelposten und ein Bierabo. Neun belegte Sorten kamen neu
  dazu — vier aus der EAN-Recherche, fünf aus dem Frastanzer Sortiment.
- **IDs entschärft.** `at-brauerei-pils`, `at-brauerei-maerzen`,
  `at-brauhaus-red-ale` — solche IDs gehören keiner Brauerei und
  kollidieren mit dem nächsten Import. Sie heißen jetzt
  `at-vitzthum-uttendorfer-pils`, `at-starkenberger-maerzen`,
  `at-gusswerk-red-ale`.
- **Namen mit Marke.** Ein Eintrag, der nur „Märzen“ heißt, ist in einer
  Suchliste wertlos. Rund 130 Namen tragen jetzt ihre Marke vorn.
- **Stile vereinheitlicht.** 162 freie Schreibweisen („Vollbier“,
  „Klassiker“, „Bierspezialität“, halbe Zutatenlisten) auf 49 Stile
  gezogen; wo der Name den Stil eindeutig nennt, wurde er abgeleitet. 60
  Einträge stehen weiter auf „Bier“ — dort veröffentlicht die Brauerei
  nichts, und Raten wäre schlechter als Schweigen.
- **Bilder.** Jede Bild-URL einzeln abgerufen; acht tote von Murauer
  ersetzt, 30 aus Open Food Facts und 65 von den Herstellerseiten
  ergänzt — von 336 auf 394 Biere mit Bild. Kein Bild ohne
  `image_source`.

Die EAN-Zuordnung war der eigentliche Anlass — siehe
[03 Barcode-Scanner](03-barcode-scanner.md).

**Was das für bestehende Installationen heißt:** Der Abgleich schreibt
nur, er löscht nie (`insertAllOnConflictUpdate`). Zusammengeführte und
umbenannte Einträge bleiben auf dem Gerät also als verwaiste Zeilen
liegen — vorhandene Check-ins zeigen weiter auf ihr Bier, aber die Suche
kann eine alte Dublette noch anzeigen. Ein Neuinstallieren räumt das auf;
ein Aufräumschritt im Abgleich wäre die saubere Lösung und steht offen.

## Bayern, Deutschland und die Schweiz (2026-09-03)

Dieselbe Prüfung, anderer Befund: Die drei Datensätze sind durchgängig
gepflegt — keine Dubletten, jedes Bier mit Beschreibung und Stil. Zu tun
war trotzdem einiges.

- **322 Gebindegrößen statt 136.** Bayern, Deutschland und die Schweiz
  führten bis dahin **keine einzige**. Ohne sie erbt jeder Scan die
  Vorbelegung 0,5 l — wer eine 0,33er scannte, bekam einen halben Liter
  gutgeschrieben.
- **Sechs EANs am falschen Produkt** entfernt (ein Warsteiner Radler am
  Warsteiner Alkoholfrei, ein Diebels Alt Radler am Diebels Alt, ein
  Berliner Natur Radler am Berliner Pilsner, ein Licher Colabier am Licher
  Pilsner, zwei isotonische Sonderlinien).
- **65 neue EANs und 45 neue Bilder** aus der Markensuche — nur dort, wo
  Open Food Facts dieselbe Sorte nennt. In dreizehn Fällen stimmte die
  Marke, aber nicht die Sorte; dort steht weiterhin nichts.
- **13 Alkoholwerte** dazu. Mehr waren nicht zu holen, ohne zu raten:
  Open Food Facts speichert `alcohol_value` teils in Volumenprozent, teils
  in Gramm je 100 ml (Gaffel Wiess steht dort mit 3,866 — das ist 4,9 %
  vol mal 0,789). Übernommen wird nur, was eindeutig ist.
- **79 Stil-Schreibweisen** auf das österreichische Vokabular gezogen,
  damit ein Filter „Weißbier“ in allen vier Regionen dasselbe findet.
  Kölsch, Altbier und Rauchbier bleiben stehen — das sind Stile, keine
  Schreibweisen.

Offen: 44 Biere ohne Alkoholgehalt, 81 ohne Bild, 75 ohne Barcode, vor
allem in der Schweiz. Die dortigen Brauereiseiten veröffentlichen kaum
technische Daten, und die OFF-Abdeckung ist dünn.

## Technische Umsetzung

- **Daten:** `app/assets/data/` — acht Dateien
  (`beers|breweries` × `at|by|de|ch`), verknüpft über `brewery_id`.
  Bestand (gezählt 2026-09-02, nach der Österreich-Überarbeitung):
  659 Biere (AT 447, BY 72, DE 95, CH 45) und 137 Brauereien
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
lokale DB geschrieben; die Assets sind zusammen rund 490 KB (659 Biere,
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
- Alkoholgehalt für die 97 Biere ohne Angabe — vor allem Huber Bräu,
  Zillertal, Bevog und Raschhofer veröffentlichen ihn nicht in
  maschinenlesbarer Form
- Weitere Regionen (Tschechien, Belgien) — erst, wenn DACH gepflegt bleibt
- Saisonbiere und Sondersude, wenn es eine Pflege-Community gibt
