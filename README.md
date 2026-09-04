# 🍻 BrewMates

**Die Bier-App, die Entdecken und Zusammensein vereint.**

BrewMates kombiniert das Beste aus zwei Welten:

- **Untappd** – Biere entdecken, einchecken, bewerten, Abzeichen sammeln und ein persönliches Bier-Tagebuch führen.
- **Beer with Me** – mit einem Tap den Freunden sagen *„Ich trinke gerade ein Bier – komm vorbei!"*, Freunde live auf der Karte sehen und spontane Treffen ermöglichen.

**Plattform-Fokus: Android** (die iOS-Option bleibt über dieselbe Flutter-Codebasis offen; Windows/macOS/Web funktionieren als Entwickler-Targets).

**📲 APK herunterladen:** [Neuestes Release](https://github.com/ORPA1988/BrewMates/releases/latest) – `.apk` auf dem Android-Gerät öffnen und installieren.

## 📚 Dokumentation

| Dokument | Inhalt |
|---|---|
| [01 – Produktvision](docs/01-produktvision.md) | Idee, Zielgruppe, Kernversprechen, Abgrenzung zu Untappd & Beer with Me |
| [02 – Funktionsspezifikation](docs/02-funktionsspezifikation.md) | Alle Features im Detail, priorisiert |
| [03 – Architektur & Tech-Stack](docs/03-architektur.md) | Flutter-Multi-Plattform-Strategie, Backend, Push, Karten, Offline-Sync |
| [04 – Datenmodell](docs/04-datenmodell.md) | Entitäten, Beziehungen, ER-Diagramm |
| [05 – UI & Screen-Flows](docs/05-ui-screens.md) | Navigationsstruktur, Wireframes, Kern-Flows |
| [06 – Roadmap](docs/06-roadmap.md) | MVP → v1.0 → v2.0 mit Meilensteinen |
| [07 – Release-Playbook](docs/07-release-playbook.md) | Weg in die Stores; Anmeldeverfahren freischalten; Riegel anheben |
| [08 – Funktionsweise für alle](docs/08-funktionsweise-fuer-alle.md) | Dieselbe App, ohne Fachbegriffe erklärt |
| [09 – Wachstum & Geschäftsmodell](docs/09-wachstum-und-geschaeftsmodell.md) | Wie die App Nutzer und Kosten trägt |
| [10 – Community-Datenpflege](docs/10-community-datenpflege.md) | Nutzererstellte Biere prüfen — Routine bei jedem Lauf |
| [11 – Modularität & Portierbarkeit](docs/11-modularitaet-und-portierbarkeit.md) | Architekturgrenzen, die eingehalten werden |
| [12 – Funktionsaudit](docs/12-funktionsaudit.md) | Vollständigkeit und Skalierbarkeit des Bestands |
| [13 – Migrationen & Lehren](docs/13-migrationen-und-lehren.md) | Was am Server steht, warum — und welche Fehler es gekostet hat |
| [Funktionen im Einzelnen](docs/features/README.md) | Ein Dokument je Funktion: Zweck, Bedienung, Umsetzung, Status |

## 💡 Das Kernkonzept: zwei Buttons

Der Startbildschirm besteht aus zwei großen Hero-Aktionen — alles andere gruppiert sich darum:

1. **🍺 Bier scannen** — Barcode der Flasche/Dose scannen → Bier erkannt → bewerten und ins Tagebuch. Unbekannter Code? Erkennung über Open Food Facts oder in 30 Sekunden selbst anlegen (und der Community vorschlagen).
2. **🍻 Zusammenkommen!** — ein Tap: deine Session startet mit echtem GPS-Standort, Freunde sehen dich auf der Karte, Botschaft: „Alle willkommen!" Nach 3 Stunden endet sie automatisch.

Jedes Bier während einer Session landet automatisch im gemeinsamen Abend-Album; Statistiken und Abzeichen wachsen mit.

## 🚀 Status: Beta 0.9 — lokaler Kern (Alpha 0.2) + Online-Beta

Die App ist bewusst als **0.x** versioniert, bis der Play-Store-Release
1.0 kommt (der interne Android-`versionCode` zählt weiter hoch, Updates
funktionieren normal); die ersten Alpha-Releases heißen 0.1.0 und 0.2.0.
Der lokale Kern (Funktionsumfang der Alpha 0.2) ist
**local-first** und voll funktionsfähig – ohne Konto, ohne Backend:

- ✅ **Hero-Aktionen**: Barcode-Scanner (EAN-8/13, Open-Food-Facts-Fallback) und Ein-Tap-Beacon mit echtem GPS

- ✅ **Sessions & Beacon**: Ein-Tap-Session mit Sichtbarkeit, Stealth-Modus, Auto-Ende, Live-Karte
- ✅ **Check-ins**: Bewertung in 0,25er-Schritten, Geschmacks-Tags, Serving-Style, Venue, Notizen
- ✅ **Bier-Datenbank**: 31 Biere / 14 Brauereien als Start, Suche, Stil-Filter, eigene Einreichungen
- ✅ **12 Abzeichen** mit grafischer Galerie und Fortschrittsanzeige (belohnt Vielfalt, nie Menge)
- ✅ **Statistiken, Tagebuch, Wunschliste**, Feed mit Toasts & Kommentaren
- ✅ Drei Demo-Freunde mit Aktivität, damit die App ab Sekunde 1 lebt (nur abgemeldet)
- 🧪 **Online-Beta**: Konto-Pflicht ab v0.9.2 (einmal anmelden, dauerhaft eingeloggt), Freunde per Nutzername, Live-Beacons und Feed echter Freunde (Supabase, EU); Karte zeigt Freunde mit Standort, alle übrigen aktiven Nutzer nur als Zähler rechts oben

**🇦🇹🇩🇪🇨🇭 Fokus: DACH-Raum (Herz: Österreich + Bayern).** Die App bringt eine redaktionelle Datenbank mit **280 Bieren** (68 Österreich, 72 Bayern, 95 Restdeutschland, 45 Schweiz) und **125 Brauereistandorten** (34 AT / 33 BY / 40 DE / 18 CH) mit: Geschmacksbeschreibungen laut Brauerei + Community-Erfahrungen, Bewertung, EAN-Barcodes und Etikett-Fotos (verlinkt von Open Food Facts, CC-BY-SA) sowie Brauerei-Detailinfos (Eigentümer, Gründungsjahr, Kennzahlen soweit öffentlich). Biere und Brauereien sind miteinander verknüpft — von jedem Bier zur Brauerei und zurück. Gepflegt wird alles direkt in diesem Repository (`app/assets/data/`), von der App beim Start via GitHub aktualisiert und auf der Karte sichtbar (Brauerei-Ebene abschaltbar; herausgezoomt als Punkte). Die Suche im Entdecken-Tab findet Biere **und** Brauereien. Neue Biere schlägst du direkt aus der App vor ([Anleitung](CONTRIBUTING.md)).

| Bereich | Inhalt |
|---|---|
| [`app/`](app/README.md) | Flutter-App (Fokus Android; iOS-Option offen), SQLite/Drift, Riverpod |
| [`app/assets/data/`](app/assets/data/DATENHERKUNFT.md) | 🇦🇹🇩🇪🇨🇭 Community-Datenbank: Biere + Brauereien für den DACH-Raum (JSON) |
| [`docs/`](docs/01-produktvision.md) | Produktvision → Roadmap, [Release-Playbook](docs/07-release-playbook.md), **[So funktioniert BrewMates (für alle)](docs/08-funktionsweise-fuer-alle.md)**, **[Wachstum & Geschäftsmodell](docs/09-wachstum-und-geschaeftsmodell.md)** |
| [`store/`](store/listing-de.md) | Store-Texte (Play Store; App Store optional) |
| [`supabase/`](supabase/README.md) | Backend (Schema & Migrationen) für die Online-Beta |
| [`PRIVACY.md`](PRIVACY.md) | Datenschutzerklärung |
| [`LICENSE`](LICENSE) | **Proprietär — der Code ist einsehbar, aber nicht frei verwendbar** |

CI: Analyze + Tests je PR. Ein Release entsteht per Git-Tag `v*` **oder** manuell im Actions-Tab („Release" → „Run workflow") — beides baut die APK und veröffentlicht sie unter [Releases](https://github.com/ORPA1988/BrewMates/releases).

## Lizenz

**Der Quellcode ist öffentlich einsehbar, aber nicht frei verwendbar.**
Es wird keine Nutzungslizenz erteilt — Einzelheiten und die wenigen
Ausnahmen (Lesen, Forks für Beiträge, Zitate) stehen in
[LICENSE](LICENSE). Für die mitgelieferten Bier- und Brauereidaten gelten
die Angaben in
[DATENHERKUNFT.md](app/assets/data/DATENHERKUNFT.md); Produktbilder liegen
nicht im Repository, es werden nur URLs hinterlegt.
