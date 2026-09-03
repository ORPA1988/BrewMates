# 09 Crews

> **Status:** 🟢 fertig — Gruppen mit Einladungscode und QR; ohne eigenen
> Feed.
> **Seit:** 0.9.12, QR-Beitritt seit 0.10.10 · **Zuletzt geprüft:**
> 2026-09-03

## Zielsetzung

Die meisten Bierrunden sind wiederkehrende Gruppen: der Stammtisch, die
Arbeitskollegen, der Verein. Eine Crew erspart es, jedes Mal dieselben
Leute einzeln anzuschreiben — und erlaubt Beacons, die nur diese Gruppe
sehen.

## Funktion (Nutzersicht)

- Crew anlegen; die Crew-Ansicht zeigt oben den **QR-Code der Einladung**,
  darunter dieselbe UUID zum Kopieren und Verschicken
- Beitreten auf zwei Wegen: **„Crew-Code scannen"** in der Titelleiste der
  Crew-Liste, oder wie bisher „Mit Code beitreten" (getippt/eingefügt)
- Mitgliederliste, Verlassen, Auflösen (nur Gründer)
- Beim Starten einer Session: Sichtbarkeit „nur meine Crew" mit Auswahl

**Wer den Code scannt, ist sofort drin** — es gibt keine Zustimmung des
Gastgebers. Das ist keine Neuerung des QR-Wegs, sondern galt schon für den
getippten Code: Der Code *ist* die Einladung. Welcher Crew man beitritt,
steht vorher **nicht** da; im Code steckt nur die UUID, und den Namen dazu
gibt der Server erst heraus, wenn man Mitglied ist (die RLS zeigt fremde
Crews nicht). Ein Vorschau-Schritt wäre entweder gelogen oder ein neues
Leseloch — die Bestätigung kommt deshalb hinterher.

## Technische Umsetzung

- **Dateien:** `features/crews/crews_screen.dart`,
  `crew_detail_screen.dart`, `crew_scan_screen.dart` (QR-Beitritt),
  `core/brewmates_code.dart` (die QR-Sprache),
  `data/online/online_service.dart` (Abschnitt „Crews")
- **QR:** `qr_flutter` zum Erzeugen, `mobile_scanner` zum Lesen — beide
  waren schon für [Funktion 22](22-freunde-per-qr-code.md) an Bord, kein
  neues Paket
- **Server:** `crews`, `crew_members` (beide seit 0001 vorhanden),
  `is_crew_member()` für RLS; `sessions.crew_id` mit der Bedingung, dass
  Sichtbarkeit „crew" eine Crew verlangt
- **Einladungscode** ist die Crew-UUID; die Beitrittsregel erlaubt
  ausdrücklich das Eintragen der eigenen Person

**Ohne neue Migration gebaut:** Das Schema aus 0001 sah Crews bereits
vollständig vor — es fehlte nur die Bedienung. Ein Beleg dafür, dass sich
sorgfältiges Datenmodellieren am Anfang auszahlt. Auch der QR-Beitritt
brauchte nichts am Server: Er schickt dieselbe UUID an dasselbe
`joinCrew`.

**Die QR-Sprache liegt in `core/`, nicht bei den Freunden.** Es gibt jetzt
zwei Code-Arten (`brewmates:friend:<uuid>`, `brewmates:crew:<uuid>`) und
drei Bildschirme, die scannen. Damit entsteht ein Fehlerfall, den es
vorher nicht gab: der **richtige Code am falschen Scanner**. „Das ist kein
BrewMates-Code" wäre dort gelogen — der Scanner weiß ja, was er hat. Beide
Features müssen dafür dieselbe Sprache lesen, und Features dürfen einander
nicht importieren; also gehört sie nach `core/`. Der Freundes-Scanner sagt
seither „Das ist ein Crew-Code, geh auf Crews", und umgekehrt.

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

Der Einladungscode ist die rohe UUID — als QR ist das gleichgültig, zum
Vorlesen weiterhin ungeeignet. Deshalb bleibt der kurze, sprechbare Code
auf dem Plan: Er ist der Weg für alles, was weder Kamera noch Zwischenablage
hat (Telefonat, Zuruf).

Abgesichert durch `test/brewmates_code_test.dart` (8 Tests: beide Arten
hin und zurück, feste Marken, fremde und verstümmelte Codes, Code am
falschen Scanner) und `test/crew_qr_test.dart` (4 Widget-Tests: Beitritt,
Freundes-Code am Crew-Scanner, fremder QR, Fehlschlag beendet den Scanner
nicht).

## Umsetzungsplan

1. ~~Beitritt per QR-Code~~ — erledigt in 0.10.10 (Issue #62)
2. Kurzer, sprechbarer Einladungscode (6 Zeichen) neben der UUID — für
   den Zuruf und das Telefonat, wo weder Kamera noch Zwischenablage hilft
3. Crew-Feed: nur die Check-ins der Crew
4. Crew-Statistiken, aufbauend auf
   [Funktion 20](20-feed-statistiken.md)

## Offene Punkte / Ideen

- Crew-Challenges („gemeinsam 50 Stile")
- Rollen innerhalb der Crew (Verwalter neben dem Gründer)
