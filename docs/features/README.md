# Funktionsdokumentation

Jede Funktion von BrewMates hat hier ein eigenes Dokument — bestehende wie
geplante, nach derselben [Vorlage](_vorlage.md): Zielsetzung, Funktion aus
Nutzersicht, technische Umsetzung, Modularität, Plattformen, Skalierung,
Umsetzungsstatus und Umsetzungsplan.

Die [Roadmap](../06-roadmap.md) sagt, **wann** etwas kommt und in welcher
Reihenfolge. Diese Dokumente sagen, **was** es ist und **wie** es gebaut
ist bzw. gebaut wird.

## Pflegeregel

**Die Doku wird mit dem Code mitgezogen, im selben Commit.** Wer eine
Funktion anfasst, aktualisiert Status, Datum und die betroffenen
Abschnitte. Eine neue Funktion beginnt mit ihrem Dokument, nicht mit dem
ersten Widget — der Umsetzungsplan entsteht vor der Umsetzung.

Ein Dokument, das nicht mehr stimmt, ist schlimmer als keines: Es behauptet
Verlässlichkeit, die es nicht hat. Beim Prüfen darum lieber ein ehrliches
„🟡 teilweise" mit benannter Lücke als ein hoffnungsvolles Grün.

## Bestehende Funktionen

| # | Funktion | Status | Kurz |
|---|---|---|---|
| [01](01-konto-und-anmeldung.md) | Konto & Anmeldung | 🟢 | Google + E-Mail, Kontolöschung, Cloud-Wiederherstellung |
| [02](02-check-ins.md) | Check-ins | 🟢 | Bewertung, Tags, Foto, Notiz, Gasthaus |
| [03](03-barcode-scanner.md) | Barcode-Scanner | 🟢 | EAN-Scan, Lookup-Kette, Neuanlage mit Foto |
| [04](04-bier-und-brauerei-datenbank.md) | Bier- & Brauerei-DB | 🟢 | 280 Biere / 125 Brauereien DACH, GitHub-Sync |
| [05](05-gasthaeuser.md) | Gasthäuser | 🟢 | Gemeinsame DB, Öffnungszeiten, Offline-Queue |
| [06](06-karte.md) | Karte | 🟢 | Freunde, Brauereien, Gasthäuser, Zähler |
| [07](07-sessions-und-beacons.md) | Sessions & Beacons | 🟡 | Ein-Tap-Beacon; feste Laufzeit |
| [08](08-freunde.md) | Freunde | 🟡 | Anfragen, Suche, Blockieren; keine Abstufung |
| [09](09-crews.md) | Crews | 🟢 | Gruppen mit Einladungscode |
| [10](10-feed.md) | Feed | 🟡 | Check-in-Strom, Toasts, Kommentare; kein Löschen |
| [11](11-abzeichen.md) | Abzeichen | 🟢 | 22 Abzeichen, Vielfalt statt Menge |
| [12](12-challenges.md) | Challenges | 🟢 | Serverseitig validiert |
| [13](13-statistiken-und-tagebuch.md) | Statistiken & Tagebuch | 🟡 | Profilzahlen, Suche; wenig Auswertung |
| [14](14-wunschliste.md) | Wunschliste | 🟢 | Merken, Cloud-Sync |
| [15](15-vertrauensstufen-und-moderation.md) | Vertrauensstufen | 🟢 | 5 Stufen, Melden, Admin-Bereich |
| [16](16-datensynchronisation.md) | Datensynchronisation | 🟡 | Local-first, Cloud-Restore; kein Delta-Sync |
| [17](17-app-update.md) | App-Update | 🟢 | Prüfung gegen GitHub-Releases |
| [18](18-plattformen.md) | Plattformen | 🟡 | Android + Web live, Windows baubar |
| [19](19-feed-eintraege-loeschen.md) | Feed-Einträge löschen | 🟢 | Eigene Check-ins entfernen, offlinefähig, Rückgängig |
| [20](20-feed-statistiken.md) | Statistiken | 🟢 | Menge, Land, Stil, Gebinde, Zeitraum, Filter |
| [21](21-hintergrundgeschichten.md) | Hintergrundgeschichten | 🟡 | Technik fertig, 30 von 125 Brauereien erzählt |
| [22](22-freunde-per-qr-code.md) | Freunde per QR-Code | 🟢 | Anzeigen und scannen statt tippen |
| [23](23-beacon-laufzeit.md) | Beacon-Laufzeit | 🟢 | 30 min – 12 h, verlängerbar, serverseitig begrenzt |
| [24](24-freundeskreise.md) | Freundeskreise | 🟢 | Bekannte / Freunde / Best Buddys, RLS-durchgesetzt |
| [28](28-live-vorschlaege.md) | Live-Vorschläge | 🟢 | Beim Tippen passende Biere/Gasthäuser zum Antippen |

## Geplante Funktionen

| # | Funktion | Status | Kurz |
|---|---|---|---|
| [25](25-brauerei-besitz.md) | Brauerei-Besitz | 🔴 | Verifizierte Inhaber pflegen ihre Daten |
| [26](26-bier-angebote.md) | Bier-Angebote | 🔴 | Sehr späte Ausbaustufe |

## Querschnitt

Nicht funktionsgebunden, aber für jede Funktion verbindlich:

- [Modularität & Portierbarkeit](../11-modularitaet-und-portierbarkeit.md)
  — wie Funktionen geschnitten werden, damit sie einzeln wachsen,
  verschwinden und auf neue Plattformen wandern können
- [Funktionsaudit](../12-funktionsaudit.md) — der aktuelle Befund zu
  Vollständigkeit und Skalierbarkeit aller bestehenden Funktionen
