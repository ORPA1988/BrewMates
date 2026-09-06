# 11 Abzeichen

> **Status:** 🟢 fertig — **55 Abzeichen** in vier Rängen, als geprägte
> Medaillons mit Fortschrittsring, cloud-gesichert.
> **Seit:** 0.2.0, Stufen seit 0.9.12, Ränge und Medaillons seit
> 0.10.28 · **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Abzeichen geben dem Sammeln eine Richtung. Die Richtung ist bewusst
gewählt und in der [Produktvision](../01-produktvision.md) festgeschrieben:
Belohnt werden **Vielfalt, Orte und Gemeinsamkeit — niemals Konsummenge.**

Es gibt kein Abzeichen für „100 Bier getrunken". Es gibt eines für
„5 alkoholfreie Biere — zählt voll!". Das ist keine Kosmetik, sondern die
Entscheidung, die die App von einer Trink-Zähl-App unterscheidet.

## Funktion (Nutzersicht)

- Galerie mit **Medaillon** je Abzeichen: Metallrand nach Rang, der
  Fortschritt läuft als Ring darum herum
- Beim Erreichen eine kurze Gratulation
- Gestaffelte Reihen, damit immer etwas in Reichweite ist: Stil-Entdecker
  (5) → Stil-Kenner (10) → Stil-Professor (20) → Stil-Archivar (30)
- Abzeichen bleiben über Gerätewechsel erhalten
- Ganz oben das **Trophäenband**: die Auszeichnungen aus abgeschlossenen
  Challenges, quer scrollbar, mit Metall (Rang) und Band samt Jahreszahl
  (Jahr) — siehe [Funktion 12](12-challenges.md)

## Die Ränge

**Das Metall sagt den Rang — sonst nichts.** Nicht das Jahr, nicht das
Thema, nicht eine Menge. Drei Bedeutungen gleichzeitig wären keine.

| Rang | Wofür | Farben |
|---|---|---|
| Bronze | erste Stufe einer Reihe | das **Kupfer der Palette** samt heller und dunkler Kante |
| Silber | zweite Stufe | kühl, hell |
| Gold | Endstufe einer Reihe | der Bernstein der Palette |
| Platin | **nur Challenge-Ränge** | ein zweiter dünner Reif, damit er sich auch in Graustufen von Silber unterscheidet |

Metall statt fünf bunter Abzeichenfarben, weil die Palette warm und
einfarbig ist: Eine Helligkeitsstaffel liest sich neben Bernstein und
Kupfer, ohne sich damit zu beißen — und sie funktioniert in Graustufen.
`test/abzeichen_katalog_test.dart` hält fest, dass **kein Dauerabzeichen
Platin trägt**.

## Technische Umsetzung

- **Dateien:** `domain/badges.dart` (Katalog und Auswertung — ohne
  Flutter **und ohne Datenbank**), `data/badge_engine.dart` (Laden und
  Vergeben), `features/profile/badges_screen.dart`,
  `widgets/badge_celebration.dart`
- **Auswertung:** `BadgeContext` enthält einmal alle nötigen Zahlen, jedes
  Abzeichen rechnet daraus seinen Fortschritt — kein Abzeichen fragt selbst
  die Datenbank
- **Eingabetyp:** `core/checkin_facts.dart` — dieselben Tatsachen, aus
  denen auch Statistiken und Challenges rechnen

**Nachtrag 2026-08-15 (Backlog A-7):** `domain/badges.dart` importierte die
Datenbank und lud über `BadgeContext.load(db, …)` selbst — ein Verstoß
gegen „`domain/` importiert nichts aus `data/`", gefunden vom neuen
`test/architecture_test.dart`. Das Laden liegt jetzt in
`data/badge_engine.dart`, die Bewertung im Domain. Erst dadurch lässt sich
der Katalog ohne Datenbank prüfen — siehe
`test/domain_ohne_datenbank_test.dart`, das unter anderem festhält, dass
kein Länder-Abzeichen mit fünfzig Check-ins **desselben** Biers fällt.
- **Lokal:** `user_badges` (Drift); **Server:** `user_badges` (0016) für
  die Wiederherstellung

**Ein neues Abzeichen ist ein Eintrag in einer Liste** — Name,
Beschreibung, Emoji, Ziel, Rang, Rechenvorschrift. Das ist die modularste
Stelle der ganzen App: Die Erweiterung von 23 auf 55 (0.10.28) brauchte
**keine Migration, keine neue Abfrage und kein neues Feld** — alle 32 neuen
rechnen aus `CheckinFacts`, das die nötigen Angaben längst trägt.

**Das Symbol bleibt ein Emoji.** Der Entwurf sah gezeichnete Zeichen vor;
bei 55 Abzeichen wären das 55 Pfadsätze, die niemand pflegt. Gezeichnet ist
das *Medaillon* (`widgets/abzeichen_medaillon.dart`), das Symbol darin
bleibt das Emoji — die Fallback-Kette dafür steht in `core/theme.dart` und
ist für genau diesen Zweck gebaut.

**Ein Kontrastfehler nebenbei behoben:** Der gesperrte Zustand legte
`Opacity(0.35)` über die ganze Kachel — auch über die Schrift, die damit
unter 4,5:1 fiel. Aufgefallen war es nie, weil
`barrierefreiheit_test.dart` nur Home, Feed, Entdecken und Profil anfährt.
Jetzt verliert nur das Medaillon seine Farbe, die Beschriftung bleibt voll
lesbar (docs/14).

## Modularität

- **Hängt ab von:** Check-ins (02), Sessions (07), Gasthäuser (05)
- **Wird gebraucht von:** Profil
- **Ausbauen:** `allBadges` leeren — die Galerie ist dann leer, sonst
  passiert nichts.

## Plattformen

Alle.

## Skalierung

`BadgeContext.load` holt **alle** eigenen Check-ins in den Speicher und
wertet 55 Abzeichen darüber aus. Bei einigen tausend Check-ins wird das
träge; dann gehören die Zähler in SQL-Aggregate. Die Trennung ist bereits
richtig geschnitten: Nur `BadgeContext` müsste sich ändern.

## Umsetzungsstatus

Vollständig. Vergabe läuft lokal und wird best-effort zum Server
gespiegelt — bewusst so, damit Abzeichen auch offline sofort erscheinen.

## Umsetzungsplan

Nur Pflege: neue Abzeichen ergänzen, wenn Funktionen dazukommen (etwa für
Hintergrundgeschichten oder Crews). Bei wachsender Datenmenge
`BadgeContext` auf Aggregate umstellen.

## Offene Punkte / Ideen

- Saisonale Abzeichen (Starkbierzeit, Bockanstich)
- Crew-Abzeichen für gemeinsam Erreichtes
- **Nicht** umsetzen: Abzeichen für Mengen. Auch nicht auf Wunsch.
