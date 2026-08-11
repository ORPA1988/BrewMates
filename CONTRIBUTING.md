# Mitmachen bei BrewMates 🍻

Danke, dass du BrewMates besser machen möchtest! So kannst du beitragen:

## Ein Bier vorschlagen

Der einfachste Weg führt über die App: **„Bier hinzufügen" → „Der Community vorschlagen"**.
Die App öffnet dann ein vorausgefülltes GitHub-Issue-Formular.

Alternativ kannst du das Formular direkt auf GitHub ausfüllen:
[🍺 Bier vorschlagen](../../issues/new?template=bier-vorschlag.yml)

Nach dem Absenden erstellt ein Bot automatisch einen Pull Request mit deinem
Vorschlag für die Bier-Datenbank (`app/assets/data/beers-at.json`). Ein
Maintainer prüft den Eintrag (z. B. ob die Brauerei-ID stimmt) und merged ihn.

## Korrekturen an den Daten

Falsche Angaben (Stil, Alkoholgehalt, Beschreibung, …)? Zwei Möglichkeiten:

- **Issue eröffnen** und beschreiben, was falsch ist — ein Maintainer kümmert sich darum.
- **Direkt einen Pull Request** gegen `app/assets/data/beers-at.json` stellen,
  wenn du dich mit dem JSON-Format auskennst. Bitte `updated` auf das aktuelle
  Datum setzen und die bestehenden IDs nicht verändern.

## Code-Beiträge

Pull Requests für App-Code, Bugfixes und neue Features sind willkommen.
Bei größeren Änderungen bitte vorher kurz ein Issue eröffnen, damit wir die
Richtung abstimmen können.

Alle Pull Requests — Daten wie Code — werden von den Maintainern geprüft und
gemerged. Danke für deine Unterstützung! 🍺
