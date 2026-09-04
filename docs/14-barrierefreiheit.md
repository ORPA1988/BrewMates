# 14 — Barrierefreiheit

> **Zuletzt geprüft:** 2026-09-04 (0.10.13-beta)
> Querschnitt, keine Funktion: Es gibt keinen Bildschirm „Barrierefreiheit",
> sondern eine Eigenschaft, die jeder Bildschirm hat oder nicht hat.

## Warum das hier zählt

BrewMates wird abends benutzt, in Lokalen, einhändig, oft mit dem Glas in
der anderen Hand — und von Menschen jeden Alters, weil Bier keine
Zielgruppe von 25 bis 34 hat. Genau die Lage, in der ein 40-Pixel-Knopf
danebengeht und grauer Text auf hellem Grund verschwindet.

Das ist keine Rücksicht auf eine Minderheit. Es ist die Bedienbarkeit
unter den Bedingungen, unter denen die App tatsächlich benutzt wird.

## Was heute zugesichert ist

`app/test/barrierefreiheit_test.dart` fährt **Home, Feed, Entdecken und
Profil** in **heller und dunkler** Palette gegen die drei Prüfungen, die
Flutter mitbringt:

| Prüfung | Was sie verlangt |
|---|---|
| `androidTapTargetGuideline` | jedes antippbare Ziel mindestens 48×48 |
| `labeledTapTargetGuideline` | kein Knopf ohne Beschriftung — sonst liest TalkBack nur „Schaltfläche" |
| `textContrastGuideline` | 4,5:1 zwischen Text und Untergrund (WCAG AA), 3:1 bei großem Text |

**Beide Helligkeiten**, weil es zwei Paletten sind: `BrewTheme.light`
keimt aus Kupfer, `BrewTheme.dark` aus Bernstein. Ein Kontrast, der hell
trägt, kann dunkel durchfallen.

Dazu `app/test/vorlesehilfe_test.dart`: Die Bewertungssterne
(`widgets/rating_stars.dart`) sprechen als **ein Satz** — „3,5 von 5
Sternen" statt „Stern, Stern, Halber Stern, Rahmen Stern, Rahmen Stern".
Sie stehen an jeder Bewertung der App; eine Stelle, viele Bildschirme.

Sonst gibt es im Code kaum ausdrückliche `Semantics` — und das ist in
Ordnung. Ein `ListTile` mit Text spricht für sich; Material liefert die
Semantik mit. Ausdrücklich nötig wird sie erst dort, wo Bedeutung aus der
**Anordnung** von Symbolen entsteht, wie bei den Sternen.

## Der Befund, der beim Bauen dieser Tests auffiel

Der erste Testlauf war grün — und wertlos. Widget-Tests laufen
standardmäßig auf **800×600**. Auf dieser Fläche lag die
Navigationsleiste außerhalb des Ausschnitts und stand deshalb gar nicht
im Semantik-Baum: **drei** antippbare Knoten auf Home statt acht. Der
Test hätte das zentrale Bedienelement der App nie angesehen und trotzdem
Entwarnung gegeben.

Deshalb setzt der Test ein Telefonformat (1170×2532 bei
`devicePixelRatio` 3) und sichert zweierlei ausdrücklich zu, bevor er
überhaupt prüft:

1. Die eingestellte Helligkeit **schlägt bis ins Theme durch** — sonst
   wären vier der acht Fälle stille Dubletten.
2. Es sind **mehr als fünf** antippbare Knoten da — mehr also als die
   fünf Tabs der Leiste. Nichts zu prüfen ist nicht dasselbe wie nichts
   zu beanstanden.

Das ist dieselbe Lehre wie bei A-9 im Backlog: Ein Wächter mit blindem
Fleck ist schlimmer als keiner, weil er Vertrauen erzeugt, das er nicht
deckt.

## Was nicht geprüft ist

- **Die Karte.** `flutter_map` holt Kacheln aus dem Netz und braucht
  einen eigenen Stub (`map_screen_test.dart` hat einen). Ihre
  Bedienelemente sind dieselben Material-Bausteine wie überall sonst.
- **Detail- und Formularbildschirme** — Check-in, Bier anlegen,
  Gasthaus bearbeiten, Konto. Mehrere davon stehen ohnehin bei 0 %
  Testabdeckung; Barrierefreiheit kommt dort mit den ersten
  Widget-Tests dazu.
- **Große Schriftgrößen.** Wer im System auf 200 % stellt, bekommt
  Überläufe, die niemand gemessen hat. `textScaler` kommt im Code nicht
  vor. Das ist die nächste sinnvolle Ausbaustufe: dieselben Bildschirme
  noch einmal bei `textScaleFactor: 2.0`.
- **Screenreader-Navigation als Ganzes** — Reihenfolge, Fokusführung,
  Ankündigungen bei Zustandswechseln. Prüft man nicht automatisch,
  sondern mit eingeschaltetem TalkBack in der Hand.

## Wie man einen Bildschirm dazunimmt

Im Test die Tab-Liste erweitern — oder für einen Bildschirm hinter der
Navigation den Weg dorthin ergänzen. Die drei `expectLater`-Zeilen
bleiben gleich. Fällt einer durch, nennt die Meldung den Knoten mitsamt
Größe bzw. das Farbpaar und das erreichte Verhältnis.
