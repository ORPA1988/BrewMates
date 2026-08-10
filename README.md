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

## 🚀 Status

Phase 0 (Fundament) hat begonnen. Das Repository enthält:

- **`docs/`** – vollständige Design- und Architekturdokumentation
- **`app/`** – Flutter-Projektgerüst (Android · iOS · Windows): adaptive Navigation, Theme, Router, alle Kern-Screens als funktionierende Platzhalter mit Demo-Daten ([Anleitung](app/README.md))
- **`supabase/`** – komplettes Postgres-Schema mit Row-Level-Security-Policies, Abzeichen-Seed und der `notify`-Edge-Function für den Beacon-Fan-out ([Anleitung](supabase/README.md))

CI (GitHub Actions) führt `flutter analyze` und `flutter test` bei jedem Pull Request aus.
