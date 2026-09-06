# 12 Challenges

> **Status:** 🟢 fertig — serverseitig validiert, Admin-Editor vorhanden,
> **vier Auszeichnungen je Challenge** (0063).
> **Seit:** 0.9.0 (0012), Validierung 0.9.7 (0014), Crew-Challenges 0.10.22
> (0062), Auszeichnungen 0.10.28 (0063) ·
> **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Abzeichen sind dauerhaft, Challenges sind befristet: „Stil-Safari im
August". Sie geben der App einen Grund, im laufenden Monat geöffnet zu
werden, und lassen sich ohne App-Update starten.

Wie bei den Abzeichen gilt: Ziele belohnen Vielfalt und Entdeckung, nie
Menge.

## Funktion (Nutzersicht)

- Laufende Challenges mit Zeitraum, Ziel und Fortschritt
- Beim Erreichen wird sie serverseitig geprüft und abgeschlossen
- Abgeschlossene bleiben im Profil sichtbar
- Bestenliste der Beitragenden

## Vier Auszeichnungen statt einer Trophäe

Bis 0.10.27 gab ein abgeschlossener Challenge genau ein Zeichen. Damit
lohnt sich Mitmachen nur für den, der ohnehin gewinnt.

| Auszeichnung | Rang | Wer sie bekommt | Wann sie feststeht |
|---|---|---|---|
| **Dabei gewesen** | Bronze | jeder, der abschließt | sofort |
| **Blitzschluck** | Platin | der erste, der fertig war | sofort |
| **Schlusslicht** | Silber | der letzte, der **fertig geworden ist** | nach dem Ende |
| **Beste Crew** | Gold | jedes Mitglied der Crew mit den meisten Abschlüssen | nach dem Ende |

Drei Entscheidungen, die man beim Lesen des Codes leicht wieder
herausnimmt und die `supabase/tests/challenge_auszeichnungen.test.sql`
deshalb festhält:

1. **Schlusslicht darf nie wie Spott klingen.** Es bekommt nur, wer
   tatsächlich abgeschlossen hat — nie, wer aufgegeben hat. Und erst ab
   **zwei** Abschlüssen: Bei genau einem wäre derselbe Mensch Erster und
   Letzter.
2. **Es gibt genau einen Ersten und einen Letzten.** Das erzwingt ein
   Teilindex in der Datenbank, nicht die Anwendung — zwei Abschlüsse in
   derselben Millisekunde erzeugten sonst zwei Erste, und genau das lässt
   sich in einem Test kaum nachstellen.
3. **Kein Client darf auszeichnen.** `challenge_awards` hat bewusst keine
   insert-Policy; vergeben wird ausschließlich über den Trigger und
   `finalisiere_challenges()`. Dieselbe Entscheidung wie bei den
   Abschlüssen seit 0014.

Eine **Crew-Challenge** (0062) bekommt keine „beste Crew": Dort tritt
genau eine Crew an, und eine Auszeichnung ohne Wettbewerb ist keine.

Bei **Gleichstand** bekommen alle gleichauf liegenden Crews die
Auszeichnung. Eine willkürliche Entscheidung wäre schlechter als zwei
Sieger.

## Technische Umsetzung

- **Dateien:** `domain/challenges.dart` (Regelauswertung, ohne
  Datenbank), `data/challenge_engine.dart` (Cache-Zeile lesen, Abzeichen
  vergeben), `features/profile/challenges_screen.dart`,
  `features/admin/challenge_editor_screen.dart`
- **Server:** `challenges`, `challenge_completions` (0012); RPC
  `complete_challenge` und Sicht `contribution_leaderboard` (0014);
  `challenge_awards` samt Trigger und `finalisiere_challenges()` (0063),
  stündlich über `pg_cron` (`finalize-challenges`)
- **Sicherheit:** Direkte Einfügungen in `challenge_completions` sind
  **gesperrt**. Nur die geprüfte Funktion darf abschließen — sonst könnte
  jeder Client behaupten, fertig zu sein.

**Nachtrag 2026-08-15 (Backlog A-7):** `ChallengeDef.fromCache` nahm eine
Drift-Zeile entgegen und `ChallengeEngine` hielt die `AppDatabase` — beides
in `domain/`, wo die Datenbank nichts zu suchen hat. Jetzt nimmt
`ChallengeDef.fromRule` Einzelwerte, der Zeilen-Adapter steht in
`data/challenge_engine.dart`. Die Regeln sind dadurch erstmals direkt
prüfbar (`test/domain_ohne_datenbank_test.dart`): dass `style_specific`
Groß-/Kleinschreibung ignoriert, dass `venue_checkins` auch Freitext-Orte
zählt und leere nicht, dass das Zeitfenster am Ende exklusiv ist — und dass
eine Challenge, die neuer ist als die App, übersprungen statt zum Absturz
gebracht wird.

Das ist die Stelle, an der die App am deutlichsten zeigt, wie sie mit
Vertrauen umgeht: Die Oberfläche rechnet den Fortschritt vor, aber
entscheiden darf sie nicht.

## Der Jahresplan (0064)

Bis 0.10.27 stand in `challenges` genau **eine** Zeile: „Stil-Safari
August", abgelaufen am 31.08.2026. Die Funktion war fertig und lief ins
Leere.

Zwölf Anlässe decken jetzt ein Jahr ab. Sie brauchen kein App-Update: Eine
Challenge erscheint, wenn ihr Zeitfenster beginnt, und verschwindet, wenn
es endet — auch auf Geräten, die nie wieder aktualisiert werden.

| Zeitraum | Challenge | Ziel |
|---|---|---|
| **06.–18.09.26** | **Spätsommer** | **4 Stile** |
| 19.09.–04.10.26 | Wiesnzeit | 3 Märzen |
| 24.10.–02.11.26 | Herbstferien | 3 neue Brauereien |
| 01.–06.12.26 | Nikolaus | 2 dunkle Biere |
| 01.12.26–06.01.27 | Bratapfel & Bock | 4 Bockbiere |
| 07.01.–03.02.27 | Klarer Jänner | 8 alkoholfreie |
| 04.–09.02.27 | Fasching | 3 verschiedene Lokale |
| ca. 08.02.–09.03.27 | Alkoholfrei durch den Fastenmonat | 10 alkoholfreie |
| 10.02.–27.03.27 | Starkbierzeit | 3 Bockbiere |
| 17.04.–16.05.27 | Frühlingserwachen | 5 Stile |
| 28.06.–11.07.27 | Schulschluss | 5 Brauereien |
| 12.07.–31.08.27 | Lange Abende | 6 Orte |
| 01.–21.09.27 | Schulbeginn | 3 neue Biere |

**Die Spätsommer-Challenge schließt eine Lücke, die erst am Server
auffiel.** Der Plan begann am 19.09.; zwischen Einspielen und diesem Datum
lief dreizehn Tage lang gar keine Challenge. Ein Plan, der erst in zwei
Wochen anfängt, ist kein aktiver Plan — gesehen hat das nicht die Datei,
sondern eine Abfrage mit `now() >= starts_at and now() < ends_at`.

**Kein Mengenziel, kein einziges.** `checkins_count` kommt in keiner der
zwölf vor; ein pgTAP-Test hält das fest. Gefordert werden andere Stile,
andere Brauereien, andere Orte — oder ausdrücklich Alkoholfreiheit.

Drei Dinge, die beim Fortschreiben schiefgehen:

- **Zeitzone.** Alle Zeitpunkte stehen als `Europe/Vienna`. In UTC begänne
  der 1. Dezember um 01:00, und die Sommerzeit verschöbe die Hälfte des
  Plans um eine Stunde.
- **`ends_at` schließt aus** (0014 vergleicht `created_at < ends_at`). Der
  letzte Tag steht deshalb immer als Mitternacht des Folgetags.
- **Fasching, Fastenzeit und Ramadan wandern.** Ostern 2027 fällt auf den
  28. März, Aschermittwoch damit auf den 10. Februar. Ramadan verschiebt
  sich jährlich um etwa elf Tage und gehört aus einer Tabelle geprüft, nicht
  gerechnet. Ramadan überschneidet sich bewusst mit Fasching und
  Starkbierzeit — es sind verschiedene Menschen, und niemand muss beides.

## Modularität

- **Hängt ab von:** Check-ins (02), Vertrauensstufen (15) für den Editor
- **Wird gebraucht von:** nichts
- **Ausbauen:** Bildschirme und Editor entfernen; Tabellen können bleiben.

## Plattformen

Alle.

## Skalierung

Die Prüffunktion läuft je Abschluss einmal und zählt über die eigenen
Check-ins — unkritisch, solange die Zahl der Check-ins je Person
überschaubar bleibt. Die Bestenliste ist eine Sicht und sollte bei vielen
Nutzern materialisiert werden.

## Umsetzungsstatus

Vollständig. Der Editor liegt im Admin-Bereich, Challenges lassen sich
also im laufenden Betrieb anlegen.

## Umsetzungsplan

Nur Betrieb: regelmäßig neue Challenges einstellen. Später Crew-Challenges,
sobald Crews einen eigenen Bereich haben.

## Offene Punkte / Ideen

- Benachrichtigung, wenn eine Challenge endet — braucht Push
- Wiederkehrende Challenges (jeden Monat automatisch)
