# 01 – Produktvision

## Elevator Pitch

> **BrewMates** ist die App für Menschen, die Bier lieben – und zwar am liebsten gemeinsam.
> Sie vereint das **Bier-Tagebuch mit Entdecker-Community** und die spontane
> **„Komm auf ein Bier vorbei!"-Einladung** in einer einzigen App
> für Android, iOS und Windows.

## Das Problem

Heute braucht man zwei Apps für zwei Hälften desselben Erlebnisses:

| | Die Katalog-Hälfte | Die Treffen-Hälfte |
|---|---|---|
| **Stärke** | Biere entdecken, bewerten, katalogisieren; riesige Bier-Datenbank; Abzeichen & Statistiken | Freunde in Echtzeit wissen lassen, dass man gerade (wo) ein Bier trinkt; spontane Treffen |
| **Schwäche** | Sozial eher passiv: Man sieht *nachher*, was Freunde getrunken haben | Kein Bier-Wissen: *was* getrunken wird, wie es schmeckt, keine Historie |

Der Moment „Ich sitze gerade mit einem großartigen Bier im Biergarten" ist **ein**
Moment – aber er zerfällt heute in zwei Apps: eine für das Bier, eine für die Freunde.

## Die Lösung

BrewMates macht aus dem Check-in einen **sozialen Beacon** und aus dem Beacon ein
**Bier-Tagebuch**:

- **Jeder Check-in kann Freunde einladen.** Bewertung, Foto und Geschmacksnoten – plus optional „Ich bin hier, kommt vorbei!".
- **Jede Session wird automatisch dokumentiert.** Wer auf den Beacon eines Freundes reagiert und dazukommt, hat hinterher gemeinsame Check-ins, gemeinsame Statistiken, gemeinsame Abzeichen.

## Zielgruppen

1. **Craft-Bier-Enthusiasten**: wollen Biere loggen, bewerten, Neues entdecken, Sammlungen und Statistiken pflegen.
2. **Gesellige Gelegenheitstrinker**: wollen unkompliziert Freunde treffen; das Bier ist der Anlass, nicht das Studienobjekt.
3. **Freundesgruppen & Stammtische**: wiederkehrende Crews, die gemeinsame Rituale pflegen (Feierabendbier, Stammtisch, Braurunden).

Die App muss für Gruppe 2 **mit einem einzigen Tap** funktionieren (Beacon senden)
und für Gruppe 1 **beliebig tief** gehen (Stile, IBU, Brauereien, Verkostungsnotizen).

## Kernversprechen

1. **Ein Tap genügt.** Session starten = Freunde wissen Bescheid. Alles Weitere ist optional.
2. **Nichts geht verloren.** Jedes Bier, jeder Abend, jeder Ort landet automatisch im persönlichen Tagebuch.
3. **Privatsphäre zuerst.** Standort wird nur während einer aktiven Session geteilt, nur mit ausgewählten Freunden/Crews, und endet automatisch.
4. **Überall zu Hause.** Volle Funktion auf Android, iOS und Windows – ein Konto, ein Datenstand, nahtloser Sync.

## Warum Windows?

Ungewöhnlich für eine Social-Bier-App – aber bewusst gewählt:

- **Planungs- und Auswerte-Ansicht:** Statistiken, Tagebuch, Wunschliste und Venue-Recherche machen auf dem großen Bildschirm mehr Spaß.
- **Heimbrauer & Bar-Betreiber:** pflegen Tap-Listen und Rezepte bevorzugt am Desktop.
- Mit **Flutter** kostet die Windows-Version fast keinen Mehraufwand (siehe [Architektur](03-architektur.md)).

## Abgrenzung / Nicht-Ziele (v1)

- Kein Marktplatz / kein Bier-Verkauf.
- Kein öffentliches „Fremde treffen Fremde" – BrewMates ist freundeszentriert (Venues & Events sind die Ausnahme, siehe Roadmap v2).
- Keine Alkohol-Gamification, die zu Mehrkonsum anreizt: Abzeichen belohnen **Vielfalt, Orte und Gemeinsamkeit**, nie Menge. Integrierte Features für verantwortungsvollen Konsum (z. B. alkoholfreie Kategorie, persönliche Wochenübersicht).

## Erfolgskriterien

- **Aktivierung:** ≥ 60 % der Neu-Nutzer senden in Woche 1 mindestens einen Check-in *oder* Beacon.
- **Der magische Moment:** ≥ 25 % der Beacons erhalten mindestens eine Reaktion („Prost!" oder „Bin dabei!") innerhalb von 30 Minuten.
- **Retention:** ≥ 35 % Wochen-4-Retention bei Nutzern mit ≥ 3 Freunden.
