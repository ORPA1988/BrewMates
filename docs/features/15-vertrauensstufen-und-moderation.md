# 15 Vertrauensstufen & Moderation

> **Status:** 🟢 fertig — fünf Stufen, serverseitig durchgesetzt,
> Änderungsprotokoll und Admin-Bereich.
> **Seit:** 0.9.0 (0013) · **Zuletzt geprüft:** 2026-08-15

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
| 4 | Moderator | Ernennung | melden bearbeiten, sperren |
| 5 | Admin | Ernennung | alles, inkl. Challenges und Rollen |

- Die eigene Stufe steht im Profil samt Fortschritt
- Melden mit Begründung; Moderatoren sehen die offene Liste
- Jede Änderung an Gemeinschaftsdaten landet im Protokoll (`edit_log`)
- Einzelfreigaben und Sperren über `user_features`

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

Vollständig.

## Umsetzungsplan

1. [Brauerei-Besitz](25-brauerei-besitz.md) als weitere Rolle neben den
   Stufen
2. Bei wachsender Nutzerzahl: Moderatoren ernennen, bevor der Rückstand
   entsteht

## Offene Punkte / Ideen

- Punkte auch für Korrekturvorschläge, nicht nur für Einträge
- Rücknahme von Stufen bei Missbrauch (heute nur über `edit_lock`)
