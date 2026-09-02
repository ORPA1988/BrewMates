# 35 Fehler melden, Wünsche, Roadmap (Testphase)

> **Status:** 🟢 fertig · **Seit:** 0.10.8 ·
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
- **Auswertung:** Das Team liest `feedback` direkt (SQL, siehe unten),
  setzt `status`/`reply`, verknüpft `roadmap_id`. Der Tester sieht das
  beim nächsten Öffnen.

```sql
-- Offene Meldungen, neueste zuerst
select f.created_at, p.username, f.kind, f.app_version, f.platform, f.body
  from feedback f join profiles p on p.id = f.profile_id
 where f.status = 'open' order by f.created_at desc;

-- Antworten und in die Roadmap übernehmen
update feedback set status = 'planned', reply = 'Kommt mit 0.10.9.',
       roadmap_id = (select id from roadmap_items where title = '…')
 where id = '…';
```

## UX-Hinweise

- **Ein Feld, keine Pflichtangaben** außer dem Text. Kategorie, Version,
  Plattform, Zeit kommen von selbst. Wer im Wirtshaus einen Fehler sieht,
  tippt zwei Sätze, kein Ticket.
- Die Rückmeldung nach dem Senden verweist auf die Liste darunter — dort
  liegt die Nachvollziehbarkeit, nicht in einer E-Mail.
- Scheitert das Senden (offline), gibt es **keinen** Dank, sondern den
  Grund. Regel A-8.
- Die Roadmap spricht vom Nutzen, nie von Technik: „Push, wenn ein Freund
  losgeht" statt „FCM-Fan-out für sessions".

## Modularität

- **Hängt ab von:** Konto (01) fürs Melden; Roadmap ohne Konto
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

Vollständig. Roadmap mit zwölf Einträgen in Alltagssprache vorbefüllt,
Stand 2026-09-03.

## Umsetzungsplan

1. ~~Melden, eigene Liste, Roadmap, Schalter~~ — erledigt
2. Admin-Ansicht in der App (Liste aller Meldungen, Status setzen),
   falls SQL auf Dauer zu umständlich wird
3. Push „Deine Meldung wurde beantwortet" über `notifications`

## Offene Punkte / Ideen

- Screenshot anhängen (Bucket, 5 MB, nur Bilder — wie Etikettfotos)
- „Mich betrifft das auch" auf Roadmap-Punkte, als Gewichtung
