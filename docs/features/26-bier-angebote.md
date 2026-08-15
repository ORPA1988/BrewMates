# 26 Bier-Angebote

> **Status:** 🔴 Konzept — sehr späte Ausbaustufe, bewusst noch nicht
> ausgeplant.
> **Frühestens:** nach 1.0 und nach [Brauerei-Besitz](25-brauerei-besitz.md)
> **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Verifizierte Brauereien und Gasthäuser sollen über die App auf konkrete
Angebote hinweisen können: das Saisonbier, die Brauereiführung am
Wochenende, die Verkostung am Donnerstag.

Der Nutzen für die Nutzer muss vor dem Nutzen für die Anbieter kommen.
Ein Angebot ist dann willkommen, wenn es beantwortet, was jemand ohnehin
gerade wissen wollte — „was gibt es hier Besonderes?" — und dann störend,
wenn es zwischen die Check-ins der Freunde gerät.

Dieses Dokument hält die Idee fest und benennt vor allem, was **vorher**
stimmen muss. Es ist ausdrücklich kein Umsetzungsplan.

## Warum das Dokument jetzt schon existiert

Weil die Entscheidung, die alles bestimmt, früh fällt: Sobald Angebote
denkbar sind, entsteht die Versuchung, die App darauf hin zu bauen — mehr
Reichweite, mehr Aufmerksamkeit, mehr Daten. Genau das würde
[die Produktvision](../01-produktvision.md) beschädigen, die Vielfalt und
gemeinsames Erleben über Menge und Werbung stellt.

Festgehalten, solange es nichts kostet:

- **Kein Angebot im Freundes-Feed.** Der Feed gehört den Freunden. Angebote
  leben auf der Brauerei- bzw. Gasthausseite und höchstens in einem
  eigenen, klar getrennten Bereich.
- **Kein Angebot ohne verifizierten Absender.** Ohne
  [Funktion 25](25-brauerei-besitz.md) gibt es das hier nicht.
- **Immer abschaltbar,** vollständig und dauerhaft, ohne dass die App
  dadurch schlechter wird.
- **Keine Weitergabe von Nutzerdaten** an Anbieter. Ein Anbieter erfährt
  nicht, wer sein Angebot gesehen hat. Aggregierte Zahlen sind
  verhandelbar, personenbezogene nie.
- **Nichts, was zum Mehrtrinken drängt.** Keine Mengenrabatte, keine
  „noch 2 Bier bis zum Gratisbier"-Mechanik. Das ist die rote Linie —
  die App belohnt Vielfalt, niemals Konsummenge.

## Voraussetzungen

| Nr. | Voraussetzung | Status |
|---|---|---|
| 1 | [Brauerei-Besitz](25-brauerei-besitz.md) verifiziert Absender | 🔴 geplant |
| 2 | Dasselbe Verfahren für Gasthäuser | 🔴 nicht geplant |
| 3 | Version 1.0 im Play Store, echte Nutzerbasis | 🔴 offen |
| 4 | Rechtliche Klärung: Werbekennzeichnung, Alkoholwerberecht je Land | 🔴 offen |
| 5 | Geschäftsmodell entschieden (siehe [docs/09](../09-wachstum-und-geschaeftsmodell.md)) | 🟡 skizziert |

Punkt 4 ist kein Nebenschauplatz: Alkoholwerbung ist in Deutschland,
Österreich und der Schweiz unterschiedlich geregelt, und eine App, die
das falsch macht, hat ein Problem, das kein Update behebt.

## Offene Fragen

- Bezahlt oder kostenlos? Kostenlos wäre gut für die Datenqualität,
  bezahlt für die Ernsthaftigkeit der Anbieter.
- Angebote als eigener Bereich oder nur auf den Detailseiten?
- Ortsbezogene Hinweise („in deiner Nähe") — nützlich, aber der kürzeste
  Weg zu etwas, das sich wie Werbung anfühlt.
