# 02 Check-ins

> **Status:** 🟢 fertig — löschbar seit 0.9.14
> ([Funktion 19](19-feed-eintraege-loeschen.md)), bearbeitbar seit 0.10.1
> ([Funktion 27](27-check-ins-bearbeiten.md)).
> **Seit:** 0.1.0 · **Zuletzt geprüft:** 2026-09-05
>
> **Eine Bewertung entsteht seit 0.10.12 nur durch einen Tipp.** Vorher
> stand der Schieberegler auf 3,5, und dieser Wert wurde bei **jedem**
> Check-in mitgeschrieben — auch bei denen, die niemand beurteilen
> wollte. Das verzerrte systematisch in eine Richtung: den eigenen
> Durchschnitt, die Statistik und über `beer_rating_stats` die
> Community-Bewertung, die anderen angezeigt wird. Ein Bier mit fünf
> beiläufigen Check-ins sah aus wie ein solide mittelmäßiges Bier,
> obwohl es niemand beurteilt hatte. „Nicht bewertet" ist jetzt der
> Anfangszustand und ein gültiges Ergebnis (`widgets/rating_input.dart`,
> `checkins.rating` war ohnehin schon nullable).

## Zielsetzung

Der Check-in ist das Herz der App: die Notiz „das habe ich getrunken, dort,
mit denen, und so war es". Alles andere — Feed, Statistiken, Abzeichen,
Tagebuch — baut darauf auf. Deshalb muss er schnell gehen: Wer im
Wirtshaus drei Minuten braucht, macht ihn beim nächsten Mal nicht mehr.

## Funktion (Nutzersicht)

- Bier wählen (Suche, Scan oder „nochmal das letzte") — der Weg
  ohne Barcode steht unten
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
- **Fotos:** Bucket `beer-photos`, Pfad je Nutzer; vor dem Hochladen auf
  **höchstens 500 KB** gerechnet (`core/foto_verkleinern.dart`)

### Der Weg ohne Barcode (2026-09-05, Wunsch [#139](https://github.com/ORPA1988/BrewMates/issues/139))

Im Wirtshaus gibt es **nichts zu scannen**: Das Bier kommt vom Fass, im
Glas. Der Scanner — die erste Hero-Aktion der App — läuft dort ins
Leere, und das ist genau die Lage, in der am häufigsten eingecheckt
wird. Ein Tester hat das gemeldet; der Weg existierte, taugte aber
nicht.

Drei Dinge standen im Weg, alle drei behoben:

1. **Der Einstieg war unsichtbar.** „Ohne Scannen einchecken" stand als
   kleiner Textknopf zwischen zwei großen Karten. Jetzt ist es ein
   vollbreiter Knopf „Ohne Barcode einchecken" direkt darunter.
2. **Das Suchfeld hatte keinen Fokus.** Der Bildschirm geht auf, um ein
   Bier zu suchen — die Tastatur gehört dorthin, ohne einen Tipp extra.
3. **Die Reihenfolge der Treffer war alphabetisch.** Die Abfrage sucht
   mit `like '%wort%'` über Name, Brauerei und Stil; wer `gö` tippt,
   bekam deshalb „Aaa Zwickl Gösser Art" vor „Gösser Märzen". Sortiert
   wird jetzt nach `trefferRang` (`core/beer_suche.dart`): Name am
   Anfang, dann ein Wort darin, dann dasselbe für die Brauerei, dann
   irgendwo enthalten, zuletzt der Stil. Bei gleichem Rang bleibt es
   alphabetisch — `sort` ist in Dart nicht stabil, das muss dastehen.

Dazu zwei Ergänzungen, die aus derselben Lage folgen:

- **Leeres Feld zeigt „Zuletzt getrunken"** (höchstens sechs, aus dem
  eigenen Tagebuch, ohne Wiederholung) statt 660 Bieren alphabetisch.
  Wer im Wirtshaus eincheckt, trinkt meistens etwas, das dort schon
  einmal stand — ein Tipp statt zehn.
- **Kein Treffer endet nicht.** Ab zwei Zeichen ohne Fund steht der
  Knopf „Bier anlegen" da, mit dem Getippten als Namen. Sonst bricht
  das Einchecken genau hier ab.

Die Rangfolge liegt in `core/`, weil sie nur Zeichenketten kennt: keine
Datenbanktypen, kein Widget, und ohne Datenbank prüfbar
(`test/schnelles_einchecken_test.dart`). Eine **Serversuche** wie beim
Anlegen ([Funktion 28](28-live-vorschlaege.md)) gibt es hier bewusst
nicht: Einchecken muss offline gehen, und ein Bier, das nur ein anderer
Nutzer angelegt hat, liegt nach dem Abgleich ohnehin lokal.

### Warum die 500 KB nachgerechnet werden (2026-09-03)

`image_picker` nimmt `maxWidth` und `imageQuality` entgegen — als
**Bitte, nicht als Zusage**. Auf Android hängt die Umsetzung an der
Kamera-App, im Browser gilt sie teilweise gar nicht. Und selbst wo sie
greift, ist ein 1280er JPEG bei Qualität 80 je nach Motiv 200 KB oder
900 KB. Wer eine Grenze zusagen will, muss sie nachrechnen.

Das Verfahren in der Reihenfolge, in der es Qualität kostet: Kante auf
1280 px begrenzen (kostet nichts Sichtbares) → JPEG-Qualität schrittweise
senken → erst danach die Kante halbieren. Ist das Bild schon JPEG, im
Budget und innerhalb der Kante, wird es **nicht** angefasst: Neu zu
kodieren würde nur Qualität kosten.

Lässt sich ein Bild nicht entschlüsseln, kommen die ursprünglichen Bytes
zurück. Ein verlorenes Foto wäre schlimmer als ein großes; der Bucket
begrenzt seit 0035 ohnehin auf 5 MB.

Gerechnet wird in einem eigenen Isolat (`compute`) — ein
12-Megapixel-Bild zu entschlüsseln dauert auf dem Telefon lange genug,
dass die Oberfläche sonst hakt. Reines Dart, also dieselbe Rechnung im
Browser wie auf Android.

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
