# 02 Check-ins

> **Status:** 🟢 fertig — löschbar seit 0.9.14
> ([Funktion 19](19-feed-eintraege-loeschen.md)), bearbeitbar seit 0.10.1
> ([Funktion 27](27-check-ins-bearbeiten.md)).
> **Seit:** 0.1.0 · **Zuletzt geprüft:** 2026-09-02

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
  `widgets/checkin_edit_sheet.dart` (Bearbeiten, siehe Funktion 27),
  `data/providers.dart` (`BrewActions`)
- **Lokal:** Drift-Tabelle `Checkins` — Bewertung, Notiz, `flavorTags`
  (kommagetrennt), `servingStyle`, `venueId`/`venueName`, `photoUrl`,
  `sessionId`, `createdAt`
- **Server:** `checkins` (0001) mit denormalisiertem Bier- und
  Brauereinamen, damit der Feed ohne Verknüpfungen auskommt
- **Fotos:** Bucket `beer-photos`, Pfad je Nutzer

### „Gespeichert" heißt nicht „angekommen" (2026-09-02)

Der Check-in wurde lokal gespeichert, der Upload `unawaited` abgesetzt,
und die App meldete „Check-in gespeichert". Ob Freunde ihn sehen, stand
nur tief im Konto-Bildschirm („x Check-ins warten"). `createCheckin`
wartet den Upload jetzt ab und liefert `synced`; offline sagt die
Snackbar „wird übertragen, sobald du online bist ⏳" — der Wortlaut aus
der Gasthaus-Pflege, die das schon immer richtig machte.

## Modularität

- **Hängt ab von:** Bierdatenbank (04), Konto (01) für den Abgleich
- **Wird gebraucht von:** Feed, Abzeichen, Challenges, Statistiken,
  Tagebuch — die zentrale Abhängigkeit der App
- **Ausbauen:** nicht sinnvoll; das wäre eine andere App.

## Plattformen

Alle. Das Foto braucht `image_picker` (Kamera/Galerie) — auf Desktop
entfällt der Foto-Schritt, der Rest funktioniert.

## Skalierung

Das Schreiben ist unkritisch. Das Lesen war es nicht — `watchFeed()` und
das Tagebuch holten alle Check-ins ohne Obergrenze; seit 0.9.14 laden
beide seitenweise (siehe [Audit](../12-funktionsaudit.md)).

Der denormalisierte Bier-/Brauereiname ist bewusst redundant: Er macht den
Feed schnell, bedeutet aber, dass Umbenennungen nachgezogen werden müssen
(siehe [Datenpflege](../10-community-datenpflege.md)).

## Umsetzungsstatus

Vollständig. Löschen gibt es seit 0.9.14, Bearbeiten seit 0.10.1 — das
Menü der Check-in-Karte öffnet `checkin_edit_sheet.dart`
(Einzelheiten in [Funktion 27](27-check-ins-bearbeiten.md)).

## Umsetzungsplan

1. ~~[Löschen](19-feed-eintraege-loeschen.md)~~ — erledigt
2. ~~Bearbeiten (Bewertung, Notiz, Tags nachträglich ändern)~~ —
   erledigt ([Funktion 27](27-check-ins-bearbeiten.md))
3. Füllmenge erfassen für [Statistiken](20-feed-statistiken.md)
4. ~~Listen auf faules Bauen umstellen, Feed seitenweise laden~~ —
   erledigt

## Offene Punkte / Ideen

- Check-in nachtragen (Datum in der Vergangenheit)
- Mehrere Biere in einem Rutsch für eine Runde
