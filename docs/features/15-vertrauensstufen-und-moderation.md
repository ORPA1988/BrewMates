# 15 Vertrauensstufen & Moderation

> **Status:** 🟡 teilweise — fünf Stufen, serverseitig durchgesetzt,
> Änderungsprotokoll und Admin-Bereich; Meldungen werden gespeichert, aber
> in der App nicht bearbeitet.
> **Seit:** 0.9.0 (0013) · **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Gemeinsam gepflegte Daten brauchen Regeln, wer was ändern darf — sonst
ist entweder alles gesperrt (dann pflegt niemand) oder alles offen (dann
ist es nach dem ersten Vandalismus wertlos). Vertrauen wächst mit
Beiträgen.

## Funktion (Nutzersicht)

| Stufe | Name | Erreicht durch | Darf |
|---|---|---|---|
| 1 | Neuling | Registrierung | eigene Inhalte |
| 2 | Stammgast | ≥ 25 Punkte | Gasthäuser bearbeiten |
| 3 | Bierkenner | ≥ 100 Punkte | Community-Daten bearbeiten |
| 4 | Moderator | Ernennung | wie Stufe 3, ohne Punkteschwelle |
| 5 | Admin | Ernennung | alles, inkl. Challenges, Rollen und Funktionen |

- Die eigene Stufe steht im Profil samt Fortschritt
- Melden mit Begründung (Menü „Mehr" in der Freundesliste)
- Jede Änderung an Gemeinschaftsdaten landet im Protokoll (`edit_log`)
- Einzelfreigaben und Sperren über `user_features` (Admin-Bereich)

### Meldungen: schreiben ja, bearbeiten nein

`reportProfile` (`data/online/api/friends_api.dart`) schreibt eine Zeile
in `reports` — mehr nicht. Eine Oberfläche, die offene Meldungen zeigt,
zuweist oder schließt, gibt es weder für Moderatoren noch für Admins:
`features/admin/admin_screen.dart` kennt nur Rollen und Funktionsflags.
Serverseitig dürfen ohnehin nur der Melder selbst und Admins
(`reports_select`, 0009) die Tabelle lesen; ein Moderator sähe die Liste
auch mit einer Oberfläche nicht. **Bearbeitung derzeit nur direkt in der
Datenbank.** Die Stufe „Moderator" wirkt heute allein als
Bearbeitungsrecht ohne Punkteschwelle (`account_level` liefert 4).

### Funktionsflags (`user_features`)

Der Admin-Bereich bietet sechs Schlüssel an; was sie bewirken, ist sehr
unterschiedlich:

- `trust_level_2` — hebt das Konto auf Stufe Stammgast, unabhängig von
  den Punkten (`account_level`, 0013).
- `trust_level_3` — dasselbe für Stufe Bierkenner.
- `edit_lock` — Stufe 0: sperrt jede Datenpflege; schlägt Punkte und
  `trust_level_*`, nicht aber Rollen (Reihenfolge in `account_level`).
- `premium` — zeigt im Konto-Bildschirm eine Karte „Premium aktiv"
  (`features/account/account_screen.dart`); sonst hängt nichts daran.
- `moderation` — es hängt **nichts** daran: keine Policy, keine Abfrage
  in der App; der Schlüssel kommt nur in Kommentaren vor. Moderationsrecht
  vergibt allein die Rolle `moderator` in `user_roles`.
- `beta_features` — es hängt **nichts** daran; weder Server noch App
  fragen den Schlüssel ab.

## Technische Umsetzung

- **Dateien:** `domain/account_level.dart`,
  `features/admin/admin_screen.dart`,
  `features/profile/` (Anzeige)
- **Server:** `user_roles`, `user_features` (0006), `edit_log` (0013),
  `reports` (0009); `is_admin()` für RLS
- **Grundsatz:** Die RLS erzwingt, die Oberfläche spiegelt. Wer die App
  umgeht, kommt trotzdem nicht weiter — die Stufen sind keine
  Anzeigelogik.

**Der Admin-Bootstrap** hängt am Anmelde-Trigger: Das Inhaber-Konto
bekommt seine Rolle automatisch. Wer diesen Trigger neu schreibt, muss
den Block mitführen — sonst hat eine frische Datenbank keinen
Administrator (genau das ist bei Migration 0019 einmal passiert und wurde
korrigiert).

## Modularität

- **Hängt ab von:** Konto (01)
- **Wird gebraucht von:** Gasthäuser, Bierdatenbank, Challenges,
  [Brauerei-Besitz](25-brauerei-besitz.md)
- **Ausbauen:** nicht sinnvoll — ohne Stufen keine gemeinsame Datenpflege.

## Plattformen

Alle.

## Skalierung

`is_admin()` und die Stufenberechnung laufen in Policies, also potenziell
je Zeile. Beide sind auf Indizes gestützt. Die manuelle Meldungsbearbeitung
ist bewusst der Flaschenhals: Ab einer gewissen Größe braucht es mehr
Moderatoren, nicht mehr Automatik.

## Umsetzungsstatus

Stufen, Punkte, Overrides, Änderungsprotokoll und Admin-Bereich sind
vollständig. **Offen:** die Bearbeitung von Meldungen — `reports` füllt
sich, gelesen wird es in der App von niemandem.

## Umsetzungsplan

1. **Meldungen bearbeiten:** Bereich im Admin-Screen mit offener Liste
   (`reports_open_idx` gibt es seit 0009), Status setzen, Sprung zum
   gemeldeten Profil; dazu Policies auf `reports`, die Moderatoren lesen
   und schließen lassen — erst dann trägt die Stufe ihren Namen.
2. [Brauerei-Besitz](25-brauerei-besitz.md) als weitere Rolle neben den
   Stufen
3. Bei wachsender Nutzerzahl: Moderatoren ernennen, bevor der Rückstand
   entsteht

## Offene Punkte / Ideen

- Punkte auch für Korrekturvorschläge, nicht nur für Einträge
- Rücknahme von Stufen bei Missbrauch (heute nur über `edit_lock`)
