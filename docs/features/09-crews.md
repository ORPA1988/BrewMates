# 09 Crews

> **Status:** 🟢 fertig — Gruppen mit Einladungscode; ohne eigenen Feed.
> **Seit:** 0.9.12 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Die meisten Bierrunden sind wiederkehrende Gruppen: der Stammtisch, die
Arbeitskollegen, der Verein. Eine Crew erspart es, jedes Mal dieselben
Leute einzeln anzuschreiben — und erlaubt Beacons, die nur diese Gruppe
sehen.

## Funktion (Nutzersicht)

- Crew anlegen, Einladungscode teilen, mit Code beitreten
- Mitgliederliste, Verlassen, Auflösen (nur Gründer)
- Beim Starten einer Session: Sichtbarkeit „nur meine Crew" mit Auswahl

## Technische Umsetzung

- **Dateien:** `features/crews/crews_screen.dart`,
  `crew_detail_screen.dart`, `data/online/online_service.dart`
  (Abschnitt „Crews")
- **Server:** `crews`, `crew_members` (beide seit 0001 vorhanden),
  `is_crew_member()` für RLS; `sessions.crew_id` mit der Bedingung, dass
  Sichtbarkeit „crew" eine Crew verlangt
- **Einladungscode** ist die Crew-UUID; die Beitrittsregel erlaubt
  ausdrücklich das Eintragen der eigenen Person

**Ohne neue Migration gebaut:** Das Schema aus 0001 sah Crews bereits
vollständig vor — es fehlte nur die Bedienung. Ein Beleg dafür, dass sich
sorgfältiges Datenmodellieren am Anfang auszahlt.

## Modularität

- **Hängt ab von:** Konto (01), Freunde (08), Sessions (07)
- **Wird gebraucht von:** Session-Sichtbarkeit „crew"
- **Ausbauen:** Feature-Ordner, zwei Routen und die Crew-Option beim
  Session-Start entfernen. Tabellen können bleiben.

## Plattformen

Alle.

## Skalierung

Crew-Größen sind klein, die Mitgliederliste wird per eingebetteter Abfrage
gezählt. Unkritisch.

## Umsetzungsstatus

Vollständig für den Zweck „Gruppe für Beacons". Was fehlt, ist alles, was
eine Crew zu einem eigenen Ort machen würde: ein Crew-Feed, gemeinsame
Statistiken, Crew-Abzeichen.

Der Einladungscode ist die rohe UUID — funktioniert, ist aber zum
Vorlesen ungeeignet.

## Umsetzungsplan

1. Kurzer, sprechbarer Einladungscode (6 Zeichen) statt UUID
2. Crew-Feed: nur die Check-ins der Crew
3. Crew-Statistiken, aufbauend auf
   [Funktion 20](20-feed-statistiken.md)
4. Beitritt per QR-Code — dieselbe Technik wie
   [Funktion 22](22-freunde-per-qr-code.md)

## Offene Punkte / Ideen

- Crew-Challenges („gemeinsam 50 Stile")
- Rollen innerhalb der Crew (Verwalter neben dem Gründer)
