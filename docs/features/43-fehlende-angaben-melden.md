# 43 Fehlende Angaben melden

> **Status:** 🟡 in Arbeit
> **Seit:** 0.10.18 · **Zuletzt geprüft:** 2026-09-05

## Zielsetzung

Nach dem Scannen weiß die App oft alles über ein Bier — außer der
Gebindegröße. **106 der 432 gebündelten EANs haben keine**
([Funktion 03](03-barcode-scanner.md)), und Open Food Facts kennt sie
nicht: Von 110 Abfragen kamen vier verwertbare Antworten.

Wer die Flasche in der Hand hält, weiß es dagegen sofort. Genau dieser
Mensch steht im richtigen Moment vor dem richtigen Produkt — und die App
fragt ihn bisher nicht.

**Woran man merkt, dass es funktioniert:** Die Zahl der EANs ohne
Gebindegröße sinkt, ohne dass jemand Datenpflege betreibt.

## Funktion (Nutzersicht)

**Rot heißt: das fehlt.** Im Treffer nach dem Scannen steht eine fehlende
Angabe nicht als Leerstelle da, sondern in der Fehlerfarbe des Themes,
mit einem Stift daneben. Heute betrifft das die Gebindegröße; die Form
trägt weitere Felder, ohne dass sich die Bedienung ändert.

**Ein Tipp genügt.** Antippen öffnet die Größen zur Auswahl — dieselben,
die auch der Check-in anbietet. Danach:

- die Größe steht **sofort** an diesem Barcode, auch für alle anderen
- der Check-in übernimmt sie in derselben Sekunde
- es gibt **2 Punkte** auf das Datenpflege-Konto (Funktion 15/31)
- und daraus entsteht ein **Issue zur Prüfung**

**Wer korrigieren darf** — und warum hier nichts gebaut werden musste:

| Fall | Wer darf |
|---|---|
| leere Angabe füllen | jeder Angemeldete |
| die **eigene** Angabe richtigstellen | der, der sie eingetragen hat |
| eine **fremde** Angabe ändern | ab Vertrauensstufe 2 (Stammgast) |

Das steht seit 0028 in `beer_barcodes_update` und musste nur nachgesehen
werden. **Der erste Entwurf hatte einen eigenen Trigger dafür** („ändern
erst ab Stufe 2") — der pgTAP-Test hat ihn erledigt, bevor er live ging:
Er hätte etwas verboten, das erlaubt sein muss, nämlich den eigenen
Tippfehler zu korrigieren. Die Begründung steht im Kopf von 0056.

## Die Entscheidung: erst glauben, dann prüfen

Die Angabe wirkt **sofort**, nicht nach der Prüfung. Das ist bewusst und
folgt der Vorgabe: *Die Angabe des Nutzers gilt als richtig, solange die
Recherche ihr nicht widerspricht.*

Der Grund ist nicht Bequemlichkeit, sondern das Kräfteverhältnis: Der
Mensch mit der Flasche in der Hand hat die bessere Quelle als jede
Datenbank. Ihn warten zu lassen, bis jemand nachgesehen hat, hieße, eine
schlechtere Information der besseren vorzuziehen — und niemand meldet
zweimal etwas, das beim ersten Mal nichts bewirkt hat.

**Was die Prüfung dann noch soll:** einen Widerspruch finden, wenn es
einen gibt. Das Issue trägt EAN, Bier und die gemeldete Größe. Bei der
laufenden Datenpflege ([docs/10](../10-community-datenpflege.md)) wird
recherchiert:

| Ergebnis | Was passiert |
|---|---|
| kein Widerspruch | Issue schließen — der Wert bleibt, wie er ist |
| Widerspruch belegt | Wert korrigieren, Issue mit der Quelle schließen |
| nichts zu finden | Issue schließen; „unbelegt" ist kein Widerspruch |

**Der Schaden eines Fehlers ist klein und umkehrbar:** eine falsche
Füllmenge in der eigenen Statistik, korrigierbar mit einem Tipp. Dagegen
steht der Nutzen von 106 Lücken, die sich sonst nie schließen.

## Technische Umsetzung

Alles Nötige gab es schon; die Arbeit ist, die Teile zu verbinden.

- **Punkte:** `account_level` zählt `edit_log`-Einträge mit
  `action = 'update'` doppelt. Migration 0056 hängt einen Trigger an
  `beer_barcodes`, der genau so einen Eintrag schreibt — **auf das Bier**
  (`entity = 'beer'`), weil `edit_log.entity_id` eine UUID ist und ein
  Barcode keine hat. Kein zweites Punktesystem.
- **Issue:** Die Meldung wird zusätzlich als `feedback`-Zeile angelegt,
  und die vorhandene Kette (Trigger → Edge Function `feedback-issue` →
  GitHub) macht daraus ein Issue. Neu ist nur die dritte Art `data`
  neben `bug` und `wish`; sie bekommt das Label `datenpflege`.
- **Schutz:** nichts Neues nötig — `beer_barcodes_update` (0028) regelt
  es bereits und besser, siehe oben. Die Regel steht in der Policy und
  nicht in der App: eine Grenze, die nur der Client kennt, umgeht der
  nächste Client.
- **Dateien (App):** `features/scan/scan_screen.dart` (rote Markierung
  und Melde-Blatt), `data/online/api/beers_api.dart` → bestehende
  `upsertBeerBarcode`, `FeedbackKind.data`.

## Was beim Bauen schiefging (2026-09-05)

**Die Meldung erreichte GitHub zuerst gar nicht.** App und Edge Function
kannten die neue Art `data`, die Datenbank nicht: `feedback.kind` ist ein
Enum mit zwei Werten, und der Insert scheiterte an

```
invalid input value for enum feedback_kind: "data"
```

Immerhin war es keine Falschmeldung — `FeedbackApi.submit` fängt den
Fehler ab, und die App sagt „die Meldung zur Gegenprüfung ging nicht
raus". Die Größe stand trotzdem am Barcode, die Punkte kamen an.
Wirkungslos war die Hälfte, die niemand sofort sieht.

**Warum es durchrutschte, ist der interessantere Teil:** Die Widget-Tests
sprechen mit `FakeOnlineService`, und der nimmt jede Art an — er weiß
nichts von Enums. Ein pgTAP-Test hätte es gefangen, aber es gab keinen,
der eine Meldung **schreibt**; geprüft war nur, wer sie lesen darf.

Behoben mit Migration 0057, und dazu `supabase/tests/feedback_arten.test.sql`:
Er legt eine Meldung **je Art** an. Eine vierte Art kann damit nicht mehr
still danebengehen.

## Modularität

- **Hängt ab von:** Scanner (03), Bierdatenbank (04), Vertrauensstufen
  (15), Feedback-Kette (35)
- **Wird gebraucht von:** nichts — rein additiv
- **Ausbauen:** Melde-Blatt und rote Markierung entfernen; Trigger
  löschen. Die Daten bleiben, wo sie sind.

## Plattformen

Alle. Der Weg braucht kein Gerät, nur ein Konto — auf Desktop und im
Browser genauso über die manuelle EAN-Eingabe.

## Skalierung

Ein Issue je Meldung ist tragbar, solange gemeldet wird, was fehlt: 106
offene EANs sind die Obergrenze des sinnvollen Aufkommens. Würde
irgendwann massenhaft gemeldet, gehörte eine Sammelmeldung her (ein
Issue je Tag statt je Angabe) — dann, nicht vorher.

## Umsetzungsplan

| Schritt | Was | Prüfkriterium |
|---|---|---|
| ~~1~~ | ~~Migration 0056~~ — **erledigt**, aber kleiner als geplant: nur der Punkte-Trigger. Der zweite, geplante Trigger fiel im Test durch (siehe oben) | ✅ pgTAP, 8 Tests: Punkte, eigene Korrektur erlaubt, fremde nur ab Stufe 2 |
| 2 | Edge Function um `data` erweitern | Issue trägt Label `datenpflege` |
| 3 | Rote Markierung im Scan-Treffer | Widget-Test: fehlt die Größe, ist die Zeile rot |
| 4 | Melde-Blatt, das beides schreibt | Widget-Test: Größe steht danach am Barcode |

## Bewusst nicht

- **Keine Prüfung vor der Übernahme.** Siehe oben: Das machte den
  Melder zum Bittsteller und die schlechtere Quelle zum Maßstab.
- **Kein Punkteabzug bei falschen Angaben.** Wer sich vertippt, soll
  nicht bestraft werden; das erzieht nur zum Nichtmelden.
- **Keine Meldung ohne Konto.** Punkte brauchen ein Konto, und eine
  anonyme Datenänderung ließe sich nicht zurückverfolgen.
