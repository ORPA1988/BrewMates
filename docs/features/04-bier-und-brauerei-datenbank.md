# 04 Bier- & Brauerei-Datenbank

> **Status:** 🟢 fertig — 280 Biere und 125 Brauereien aus dem DACH-Raum,
> kuratiert im Repository, per GitHub aktualisiert.
> **Seit:** 0.4.0 (AT), DACH seit 0.9.13 · **Zuletzt geprüft:** 2026-08-15

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

## Technische Umsetzung

- **Daten:** `app/assets/data/` — acht Dateien
  (`beers|breweries` × `at|by|de|ch`), verknüpft über `brewery_id`
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
lokale DB geschrieben; die Assets sind zusammen rund 280 KB. Das trägt
gut bis etwa zum Dreifachen. Darüber hinaus — oder mit
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

- Weitere Regionen (Tschechien, Belgien) — erst, wenn DACH gepflegt bleibt
- Saisonbiere und Sondersude, wenn es eine Pflege-Community gibt
