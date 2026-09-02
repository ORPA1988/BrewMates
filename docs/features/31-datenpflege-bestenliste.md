# 31 Datenpflege-Bestenliste

> **Status:** 🟢 fertig · **Seit:** 0.9.x (Migration 0014) ·
> **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Die Community-Datenbank lebt davon, dass Menschen Biere, Barcodes und
Gasthäuser nachtragen. Vertrauenspunkte belohnen das (siehe 15), aber
Punkte, die niemand sieht, motivieren wenig. Die Bestenliste macht
sichtbar, wer die Datenbank trägt — und gibt Neulingen ein Bild davon,
was „Stammgast" und „Bierkenner" praktisch bedeuten.

## Funktion (Nutzersicht)

- Unter **Profil → 🏅 Datenpflege-Bestenliste** die **Top 20** nach
  Vertrauenspunkten: Avatar, Nutzername, Punkte.
- Nur angemeldet; ohne Verbindung eine kurze Fehlermeldung statt einer
  leeren Liste.

## Technische Umsetzung

- **Dateien:** `features/profile/leaderboard_screen.dart`,
  `leaderboardProvider` in `data/providers/wartung.dart`,
  `OnlineService.contributionLeaderboard()`
- **Server:** RPC `contribution_leaderboard(p_limit)` (0014), SECURITY
  DEFINER, nur für `authenticated`. Liefert bewusst nur Nutzername,
  Avatar und Punkte — keine IDs, keine Aktivitätsdaten. Die Punkte selbst
  kommen aus `edit_log` (0013).
- Kein Cache: Die Liste ist klein und ändert sich selten.

## UX-Hinweise

- Zeigt keinen eigenen Rang, wenn man nicht unter den Top 20 ist. Das ist
  eine Lücke: Wer auf Platz 34 steht, sieht sich nicht und weiß nicht,
  wie weit es bis zur Liste ist.
- Der Einstieg liegt tief im Profil; wer nicht weiß, dass es die Liste
  gibt, findet sie nicht.

## Modularität

- **Hängt ab von:** Konto (01), Vertrauensstufen (15)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Bildschirm, Provider und Route entfernen; die RPC kann
  bleiben.

## Plattformen

Alle.

## Skalierung

Eine Aggregation über `edit_log` pro Aufruf. Bei vielen Tausend
Einträgen wird sie spürbar — dann eine materialisierte Sicht mit
täglicher Aktualisierung. Heute unnötig.

## Umsetzungsstatus

Vollständig, aber undokumentiert bis 2026-09-02 (Doku 12 und 20 nannten
nur *Challenge*-Bestenlisten).

## Umsetzungsplan

1. Eigenen Rang und Abstand zur Liste anzeigen („Du: 34., noch 12 Punkte
   bis Platz 20")
2. Einstieg prominenter, z. B. als Zeile auf der Profil-Übersicht mit dem
   eigenen Punktestand

## Offene Punkte / Ideen

- Monats-Bestenliste neben der Gesamtliste, damit Neue eine Chance haben
