# 35 Fehler melden, Wünsche, Roadmap (Testphase)

> **Status:** 🟢 fertig · **Seit:** 0.10.8 (GitHub-Anbindung 0.10.9) ·
> **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

In der Testphase ist jeder Hinweis Gold wert — aber nur, wenn er den Weg
vom Wirtshaustisch bis in die Arbeitsliste schafft, ohne dass jemand ein
GitHub-Konto braucht. Und der Tester muss **sehen, was daraus wird**;
sonst meldet er beim zweiten Mal nichts mehr.

## Funktion (Nutzersicht)

Unter „Zusammenkommen" auf der Startseite drei kleine Knöpfe:

| Knopf | Was passiert |
|---|---|
| **Fehler** | Ein Feld: „Was ist passiert – und was hast du erwartet?" Version und Plattform hängt die App selbst an. |
| **Wunsch** | Ein Feld: „Was soll BrewMates können?" |
| **Roadmap** | „Was kommt als Nächstes" — in Arbeit, geplant, fertig, je ein Satz in Alltagssprache. |

Unter dem Formular stehen die **eigenen Meldungen** mit Status
(Eingegangen · Geplant · Erledigt · Nicht geplant), einer optionalen
kurzen Antwort und dem Roadmap-Punkt, aus dem sie geworden sind.
Fremde Meldungen sieht niemand. Die Roadmap sehen alle, auch ohne Konto.

Die drei Knöpfe hängen an einem Schalter (`app_config.feedback_enabled`)
und verschwinden nach der Testphase ohne Release.

## Technische Umsetzung

- **Dateien:** `features/feedback/feedback_screen.dart`,
  `features/feedback/roadmap_screen.dart`,
  `data/online/api/feedback_api.dart`, `data/providers/feedback.dart`,
  Knöpfe in `features/home/home_screen.dart`, Routen `/feedback?art=bug|wish`
  und `/roadmap`.
- **Server (0037):** `feedback` (kind, body 3–2000 Zeichen, app_version,
  platform, status, reply, roadmap_id) und `roadmap_items` (title,
  summary, status, sort_order). RLS: Feedback liest und schreibt nur der
  Absender (Status bleibt `open`; ändern darf nur ein Admin), Admins sehen
  alles; Roadmap liest jeder (`using (true)`), schreiben nur Admins.
  pgTAP prüft Fremdzugriff, Schalter und dass ein Absender seinen Status
  nicht selbst setzen kann.
- **Verwaltung in GitHub (0038, 0.10.9):** Jede Meldung wird automatisch
  ein **anonymes** Issue im öffentlichen Repo (Art, Version, Plattform,
  Text — kein Name, keine E-Mail; die App sagt das vor dem Tippen).
  Trigger `feedback_issue` → Edge Function `feedback-issue` (pg_net,
  Geheimnis wie beim Push) → Issue mit Labels `feedback` + `bug`/`wunsch`,
  Nummer zurück nach `feedback.github_issue`. Zieht der Absender zurück,
  wird das Issue geschlossen. `github_issue` kann ein Absender nicht selbst
  setzen (BEFORE-Trigger nullt).
- **Zurück in die App:** Workflow `feedback-sync.yml` ruft bei jeder
  Issue-Änderung die Edge Function `github-sync` mit der Nummer; die liest
  das Issue **selbst bei GitHub nach** (vertraut dem Aufrufer nichts, braucht
  deshalb kein Geheimnis; Bremse: Vollabgleich höchstens jede Minute,
  Einzelabgleiche 60/min) und schreibt `feedback.status/reply/roadmap_id`
  und `roadmap_items`. `{ "all": true }` synchronisiert alles (Run
  workflow ohne Nummer).
- **Ein neuer Roadmap-Punkt löst zwei Läufe aus.** GitHub schickt beim
  Anlegen `opened` **und** `labeled` kurz hintereinander. Beide sahen
  nach, fanden nichts, und fügten ein — der zweite scheiterte an
  `roadmap_items_github_issue_key`, der Lauf brach mit 502 ab. Am
  2026-09-04 live beobachtet: Ohne den `all`-Lauf hinterher wäre der Punkt
  **nie in der App erschienen**. Behoben mit `upsert … onConflict`;
  zwischen Nachsehen und Schreiben liegt eine Lücke, die keine zweite
  Abfrage schließt.
- **Roadmap = Issues mit Label `roadmap`:** Titel und erster Absatz
  erscheinen in der App; Status aus `status:in-arbeit` / geschlossen =
  fertig / sonst geplant. **Label weg → Punkt weg** (bewusst; der Text
  bleibt im Issue, erneutes Labeln stellt ihn aus dem Issue wieder her).
  Die zwölf vorbefüllten Punkte aus 0037 wurden über den normalisierten
  Titel adoptiert (Anführungszeichen und Leerraum zählen nicht).
- **Secrets:** `GITHUB_TOKEN` (feingranular, nur Issues lesen/schreiben in
  diesem Repo) als Edge-Function-Secret; ersatzweise wird
  `GITHUB_FEEDBACK_TOKEN` gelesen. Sonst nichts — der Workflow
  braucht kein Supabase-Geheimnis.

### So wird verwaltet (kein SQL mehr)

| Aktion | In GitHub |
|---|---|
| Status setzen | Label `status:geplant`, `status:in-arbeit`, `status:erledigt`, `status:nicht-geplant` — oder Issue schließen („completed“ = Erledigt, „not planned“ = Nicht geplant) |
| Dem Tester antworten | Kommentar, der mit **„Antwort:“** beginnt (nur Owner/Collaborator zählen) |
| In die Roadmap übernehmen | Label `roadmap` auf das Issue; Titel in Alltagssprache umschreiben, erster Absatz = Erklärung |
| Meldung mit bestehendem Roadmap-Punkt verknüpfen | Kommentar **„Roadmap: #123“** |
| Auslesen (Claude) | `gh issue list --label feedback --state open` |

```sh
# Alles neu spiegeln (nach Störung oder Ersteinrichtung)
gh workflow run feedback-sync.yml
```

## UX-Hinweise

- **Ein Feld, keine Pflichtangaben** außer dem Text. Kategorie, Version,
  Plattform, Zeit kommen von selbst. Wer im Wirtshaus einen Fehler sieht,
  tippt zwei Sätze, kein Ticket.
- Die Rückmeldung nach dem Senden verweist auf die Liste darunter — dort
  liegt die Nachvollziehbarkeit, nicht in einer E-Mail. Jede Meldung mit
  Issue hat „Auf GitHub ansehen“; jeder Roadmap-Punkt ist antippbar.
- **Öffentlich, anonym** steht vor dem Tippen da, nicht danach. Wer etwas
  Privates meldet, soll das wissen, bevor er es abschickt.
- Scheitert das Senden (offline), gibt es **keinen** Dank, sondern den
  Grund. Regel A-8.
- Die Roadmap spricht vom Nutzen, nie von Technik: „Push, wenn ein Freund
  losgeht" statt „FCM-Fan-out für sessions".

## Modularität

- **Hängt ab von:** Konto (01) fürs Melden; Roadmap ohne Konto; GitHub
  (Issues-API) für die Verwaltung — fällt GitHub aus, bleibt alles in
  Supabase lesbar, nur der Spiegel steht
- **Wird gebraucht von:** nichts
- **Ausbauen:** Schalter auf `false` — Knöpfe weg, Tabellen bleiben als
  Archiv. Vollständig entfernen: zwei Screens, eine API, zwei Tabellen.

## Plattformen

Alle — ausdrücklich auch Web, weil iPhone-Nutzer in der Testphase nur
den Browser haben. Die Plattform steht in jeder Meldung.

## Skalierung

Testphase, zweistellige Nutzerzahl. Indizes auf `profile_id` und
`status`. Ab einigen tausend Meldungen bräuchte die Auswertung eine
Oberfläche statt SQL — dann ist die Testphase vorbei.

## Umsetzungsstatus

Vollständig, inkl. GitHub-Spiegel in beide Richtungen (0.10.9). Roadmap
lebt als Issues mit Label `roadmap`; Stand 2026-09-03.

## Umsetzungsplan

1. ~~Melden, eigene Liste, Roadmap, Schalter~~ — erledigt
2. Admin-Ansicht in der App (Liste aller Meldungen, Status setzen),
   falls SQL auf Dauer zu umständlich wird
3. Push „Deine Meldung wurde beantwortet" über `notifications`

## Offene Punkte / Ideen

- Screenshot anhängen (Bucket, 5 MB, nur Bilder — wie Etikettfotos)
- „Mich betrifft das auch" auf Roadmap-Punkte, als Gewichtung
