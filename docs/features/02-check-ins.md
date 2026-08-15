# 02 Check-ins

> **Status:** 🟢 fertig — aber nicht löschbar und nicht bearbeitbar, siehe
> [Funktion 19](19-feed-eintraege-loeschen.md).
> **Seit:** 0.1.0 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Der Check-in ist das Herz der App: die Notiz „das habe ich getrunken, dort,
mit denen, und so war es". Alles andere — Feed, Statistiken, Abzeichen,
Tagebuch — baut darauf auf. Deshalb muss er schnell gehen: Wer im
Wirtshaus drei Minuten braucht, macht ihn beim nächsten Mal nicht mehr.

## Funktion (Nutzersicht)

- Bier wählen (Suche, Scan oder „nochmal das letzte")
- Bewertung in 0,25-Schritten — feiner als Sterne, ohne Scheingenauigkeit
- Optional: Geschmacks-Tags, Gebinde (Fass/Flasche/Dose/Growler),
  Gasthaus, Notiz, Foto
- Speichern wirkt sofort, auch offline; der Abgleich läuft danach
- Ein Check-in kann einer laufenden Session zugeordnet werden

## Technische Umsetzung

- **Dateien:** `features/checkin/checkin_screen.dart`,
  `widgets/checkin_card.dart`, `widgets/rating_stars.dart`,
  `data/providers.dart` (`BrewActions`)
- **Lokal:** Drift-Tabelle `Checkins` — Bewertung, Notiz, `flavorTags`
  (kommagetrennt), `servingStyle`, `venueId`/`venueName`, `photoUrl`,
  `sessionId`, `createdAt`
- **Server:** `checkins` (0001) mit denormalisiertem Bier- und
  Brauereinamen, damit der Feed ohne Verknüpfungen auskommt
- **Fotos:** Bucket `beer-photos`, Pfad je Nutzer

## Modularität

- **Hängt ab von:** Bierdatenbank (04), Konto (01) für den Abgleich
- **Wird gebraucht von:** Feed, Abzeichen, Challenges, Statistiken,
  Tagebuch — die zentrale Abhängigkeit der App
- **Ausbauen:** nicht sinnvoll; das wäre eine andere App.

## Plattformen

Alle. Das Foto braucht `image_picker` (Kamera/Galerie) — auf Desktop
entfällt der Foto-Schritt, der Rest funktioniert.

## Skalierung

Das Schreiben ist unkritisch. Das **Lesen** ist es nicht: `watchFeed()`
und das Tagebuch holen alle Check-ins ohne Obergrenze, und die Listen
bauen jeden Eintrag sofort (siehe [Audit](../12-funktionsaudit.md)). Bei
einigen tausend eigenen Check-ins wird das spürbar.

Der denormalisierte Bier-/Brauereiname ist bewusst redundant: Er macht den
Feed schnell, bedeutet aber, dass Umbenennungen nachgezogen werden müssen
(siehe [Datenpflege](../10-community-datenpflege.md)).

## Umsetzungsstatus

Vollständig bis auf zwei Lücken: **Löschen** und **Bearbeiten**. Beides
zusammen ist der häufigste zu erwartende Wunsch.

## Umsetzungsplan

1. [Löschen](19-feed-eintraege-loeschen.md) — als nächstes
2. Bearbeiten (Bewertung, Notiz, Tags nachträglich ändern)
3. Füllmenge erfassen für [Statistiken](20-feed-statistiken.md)
4. Listen auf faules Bauen umstellen, Feed seitenweise laden

## Offene Punkte / Ideen

- Check-in nachtragen (Datum in der Vergangenheit)
- Mehrere Biere in einem Rutsch für eine Runde
