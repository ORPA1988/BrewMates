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
| [02](02-check-ins.md) | Check-ins | 🟢 | Bewertung, Tags, Foto, Notiz, Gasthaus; ohne Barcode in Sekunden |
| [03](03-barcode-scanner.md) | Barcode-Scanner | 🟢 | EAN-Scan, Lookup-Kette, Neuanlage mit Foto |
| [04](04-bier-und-brauerei-datenbank.md) | Bier- & Brauerei-DB | 🟢 | 660 Biere / 137 Brauereien DACH, GitHub-Sync |
| [05](05-gasthaeuser.md) | Gasthäuser | 🟢 | Gemeinsame DB, Öffnungszeiten, Offline-Queue |
| [06](06-karte.md) | Karte | 🟢 | Freunde, Brauereien, Gasthäuser, Zähler |
| [07](07-sessions-und-beacons.md) | Sessions & Beacons | 🟢 | Ein-Tap-Beacon, Laufzeit wählbar, Push an die, die ihn sehen dürfen |
| [08](08-freunde.md) | Freunde | 🟢 | Anfragen, Suche, QR-Code, Blockieren, Freundeskreise |
| [09](09-crews.md) | Crews | 🟢 | Vier Beitrittswege inkl. Einladung, Runden-Feed und Bilanz |
| [10](10-feed.md) | Feed | 🟢 | Check-in-Strom, Toasts, Kommentare, Löschen, Seitenladen |
| [11](11-abzeichen.md) | Abzeichen | 🟢 | 23 Abzeichen, Vielfalt statt Menge |
| [12](12-challenges.md) | Challenges | 🟢 | Serverseitig validiert |
| [13](13-statistiken-und-tagebuch.md) | Tagebuch & Wochen-Serie | 🟢 | Nachlesen und Suche — ausgewertet wird in 20 |
| [14](14-wunschliste.md) | Wunschliste | 🟢 | Merken, Cloud-Sync |
| [15](15-vertrauensstufen-und-moderation.md) | Vertrauensstufen | 🟢 | 5 Stufen, Admin-Bereich, Moderation (siehe 37) |
| [16](16-datensynchronisation.md) | Datensynchronisation | 🟡 | Local-first, Cloud-Restore; kein Delta-Sync |
| [17](17-app-update.md) | App-Update | 🟢 | Prüfung gegen GitHub-Releases |
| [18](18-plattformen.md) | Plattformen | 🟡 | Android + Web live, Windows baubar |
| [19](19-feed-eintraege-loeschen.md) | Feed-Einträge löschen | 🟢 | Eigene Check-ins entfernen, offlinefähig, Rückgängig |
| [20](20-feed-statistiken.md) | Statistiken & Auswertung | 🟢 | Acht Aufteilungen per Chip, neun Kennzahlen, freier Zeitraum, Vergleich zum Vorzeitraum |
| [21](21-hintergrundgeschichten.md) | Hintergrundgeschichten | 🟡 | Technik fertig, 34 von 137 Brauereien erzählt |
| [22](22-freunde-per-qr-code.md) | Freunde per QR-Code | 🟢 | Anzeigen und scannen statt tippen |
| [23](23-beacon-laufzeit.md) | Beacon-Laufzeit | 🟢 | 30 min – 12 h, verlängerbar, serverseitig begrenzt |
| [24](24-freundeskreise.md) | Freundeskreise | 🟢 | Bekannte / Freunde / Best Buddys, RLS-durchgesetzt |
| [27](27-check-ins-bearbeiten.md) | Check-ins bearbeiten | 🟢 | Bewertung, Notiz, Tags, Gebinde, Ort nachträglich ändern; offlinefähig |
| [28](28-live-vorschlaege.md) | Live-Vorschläge | 🟢 | Beim Tippen passende Biere/Gasthäuser zum Antippen |
| [29](29-push-benachrichtigungen.md) | Push-Benachrichtigungen | 🟢 | FCM, inhaltsleer, Anfragen + Beacons |
| [30](30-bierlaune.md) | Bierlaune | 🟢 | „Hätte Lust“ für 4 h, nur Kreis Freund |
| [31](31-datenpflege-bestenliste.md) | Datenpflege-Bestenliste | 🟢 | Top 20 nach Vertrauenspunkten |
| [32](32-bierpreise-und-preis-radar.md) | Bierpreise & Preis-Radar | 🟢 | 0,5/0,3 l am Gasthaus, Preis am Kartenschild |
| [33](33-orts-schnellansicht.md) | Orts-Schnellansicht | 🟢 | Bottom-Sheet für Gasthaus und Brauerei |
| [34](34-entdecken.md) | Entdecken | 🟢 | Biere, Brauereien, Gasthäuser mit Suche, Sortierung, Anlegen |
| [35](35-feedback-und-roadmap.md) | Fehler, Wünsche, Roadmap | 🟢 | Testphase: melden mit zwei Tipps, Status sehen, Roadmap in Alltagssprache |
| [36](36-rueckgaengig-statt-rueckfrage.md) | Rückgängig statt Rückfrage | 🟡 | Beacon, Anfrage, Wunschliste: Fehltipp fünf Sekunden lang zurücknehmbar |
| [37](37-meldungen-bearbeiten.md) | Meldungen bearbeiten | 🟢 | Moderatoren sehen gemeldete Profile und schließen sie mit Befund ab |
| [38](38-benachrichtigungen-im-browser.md) | Benachrichtigungen im Browser | 🟢 | Systemmeldung bzw. Nachreichen, solange die Web-App offen ist |
| [40](40-runden-checkins.md) | Check-ins in einer Runde | 🟢 | Mitrundige sehen sie, Zuordnung läuft automatisch, Crew-Bilanz zählt jede beteiligte Crew |
| [41](41-sortieren-in-entdecken.md) | Sortieren in Entdecken | 🟡 | Biere und Brauereien nach Nähe, Name, Alkohol, Sorte |
| [42](42-vergleich-mit-anderen.md) | Vergleich mit anderen | 🟡 | Anonymer Schnitt aller anderen, erst ab 20 Personen |

## Geplante Funktionen

| # | Funktion | Status | Kurz |
|---|---|---|---|
| [25](25-brauerei-besitz.md) | Brauerei-Besitz | 🔴 | Verifizierte Inhaber pflegen ihre Daten |
| [26](26-bier-angebote.md) | Bier-Angebote | 🔴 | Sehr späte Ausbaustufe |
| [39](39-geplante-sessions.md) | Geplante Sessions | 🟢 | „Freitag 19 Uhr“ — anlegen, sehen, zusagen, erinnert werden, starten |

## Querschnitt

Nicht funktionsgebunden, aber für jede Funktion verbindlich:

- [Modularität & Portierbarkeit](../11-modularitaet-und-portierbarkeit.md)
  — wie Funktionen geschnitten werden, damit sie einzeln wachsen,
  verschwinden und auf neue Plattformen wandern können
- [Funktionsaudit](../12-funktionsaudit.md) — der aktuelle Befund zu
  Vollständigkeit und Skalierbarkeit aller bestehenden Funktionen
- [Barrierefreiheit](../14-barrierefreiheit.md) — Trefferflächen,
  Beschriftungen und Kontrast; was `barrierefreiheit_test.dart` je
  Bildschirm zusichert und was es bewusst offenlässt
