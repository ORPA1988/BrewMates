# 🍻 BrewMates

**Die Bier-App, die Entdecken und Zusammensein vereint.**

BrewMates kombiniert das Beste aus zwei Welten:

- **Untappd** – Biere entdecken, einchecken, bewerten, Abzeichen sammeln und ein persönliches Bier-Tagebuch führen.
- **Beer with Me** – mit einem Tap den Freunden sagen *„Ich trinke gerade ein Bier – komm vorbei!"*, Freunde live auf der Karte sehen und spontane Treffen ermöglichen.

**Plattformen:** Android · iOS · Windows (sowie macOS und Web als Bonus über dieselbe Codebasis).

## 📚 Dokumentation

| Dokument | Inhalt |
|---|---|
| [01 – Produktvision](docs/01-produktvision.md) | Idee, Zielgruppe, Kernversprechen, Abgrenzung zu Untappd & Beer with Me |
| [02 – Funktionsspezifikation](docs/02-funktionsspezifikation.md) | Alle Features im Detail, priorisiert |
| [03 – Architektur & Tech-Stack](docs/03-architektur.md) | Flutter-Multi-Plattform-Strategie, Backend, Push, Karten, Offline-Sync |
| [04 – Datenmodell](docs/04-datenmodell.md) | Entitäten, Beziehungen, ER-Diagramm |
| [05 – UI & Screen-Flows](docs/05-ui-screens.md) | Navigationsstruktur, Wireframes, Kern-Flows |
| [06 – Roadmap](docs/06-roadmap.md) | MVP → v1.0 → v2.0 mit Meilensteinen |

## 💡 Das Kernkonzept: die „Session"

Die zentrale Innovation von BrewMates ist die **Bier-Session** – sie verschmilzt den
Untappd-Check-in mit dem Beer-with-Me-Beacon:

1. Du startest eine Session („Ich bin im Biergarten am See 🍺").
2. Deine Freunde bekommen eine Push-Benachrichtigung und sehen dich auf der Karte – sie können mit einem Tap „Bin dabei!" antworten oder virtuell anstoßen.
3. Jedes Bier, das du während der Session trinkst, checkst du wie bei Untappd ein: Bewertung, Foto, Geschmacksnoten.
4. Nach der Session hast du automatisch ein Tagebuch des Abends – und deine Statistiken & Abzeichen wachsen mit.

## 🚀 Status: Version 1.0 (release-fähig)

Version 1.0 ist **local-first** und voll funktionsfähig – ohne Konto, ohne Backend:

- ✅ **Sessions & Beacon**: Ein-Tap-Session mit Sichtbarkeit, Stealth-Modus, Auto-Ende, Live-Karte
- ✅ **Check-ins**: Bewertung in 0,25er-Schritten, Geschmacks-Tags, Serving-Style, Venue, Notizen
- ✅ **Bier-Datenbank**: 31 Biere / 14 Brauereien als Start, Suche, Stil-Filter, eigene Einreichungen
- ✅ **12 Abzeichen** mit grafischer Galerie und Fortschrittsanzeige (belohnt Vielfalt, nie Menge)
- ✅ **Statistiken, Tagebuch, Wunschliste**, Feed mit Toasts & Kommentaren
- ✅ Drei Demo-Freunde mit Aktivität, damit die App ab Sekunde 1 lebt

Der Mehrspieler-Sync (Supabase, `supabase/`) ist vorbereitet und folgt in v2.

| Bereich | Inhalt |
|---|---|
| [`app/`](app/README.md) | Flutter-App (Android · iOS · Windows), SQLite/Drift, Riverpod |
| [`docs/`](docs/01-produktvision.md) | Produktvision → Roadmap, inkl. [Release-Playbook](docs/07-release-playbook.md) |
| [`store/`](store/listing-de.md) | Store-Texte für Play Store, App Store, Microsoft Store |
| [`supabase/`](supabase/README.md) | Backend-Schema für den v2-Sync |
| [`PRIVACY.md`](PRIVACY.md) | Datenschutzerklärung (lokal-only) |

CI: Analyze + Tests je PR; ein Git-Tag `v*` baut APK, AAB und Windows-MSIX als Release-Artefakte.
