---
description: Änderungen abschließen — prüfen, committen, PR vorbereiten
---

Schließe die aktuelle Arbeit sauber ab. Arbeite die Definition of Done aus
`.claude/conventions.md` Punkt für Punkt ab und zeige mir das Ergebnis:

1. `cd app && flutter analyze`
2. `cd app && flutter test > ../test_out.txt 2>&1`, dann die Datei lesen
   (**nie nach `tail` pipen**)
3. `cd app && flutter build web --release` — fängt `dart:io`-Regressionen
4. Bei Schemaänderung: Migration vorhanden? Drift-Version erhöht? Neue RPC
   mit `grant execute … to authenticated`?
5. Version in `pubspec.yaml` **und** `core/config.dart` gleich?
6. `git diff` durchsehen: ungenutzte Imports, auskommentierter Code,
   `print()` im Produktivpfad, geloggte Standort-/Kontaktdaten?

Wenn ein Punkt fehlschlägt: **stopp, melde ihn, committe nicht.**

Wenn alles grün ist:

- Commit im Conventional-Commits-Format (Englisch, siehe conventions.md)
- Branch pushen und PR anlegen — **frag mich vorher**
- PR-Beschreibung auf Deutsch: was geändert, warum, was bewusst nicht

Zum Schluss drei Sätze in einfacher Sprache: Was kann die App jetzt, was
sie vorher nicht konnte?
