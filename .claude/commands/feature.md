---
description: Neue Funktion planen und bauen — $ARGUMENTS
argument-hint: <kurze Beschreibung der Funktion>
---

Neue Funktion: **$ARGUMENTS**

Arbeite in dieser Reihenfolge und **halte nach Schritt 2 an**:

1. **Einordnen.** Gibt es dazu schon ein Dokument in `docs/features/`?
   Steht die Funktion in `docs/06-roadmap.md`? Widerspricht sie der Liste
   „bewusst NICHT übernehmen"? Wenn ja: sag es und bau nichts.
2. **Planen.** Schreibe ein neues Dokument nach dem Muster
   `docs/features/_vorlage.md`: Zielsetzung, technische Umsetzung,
   betroffene Dateien, Datenmodell-/Migrationsbedarf, Plattformen,
   Skalierung, Umsetzungsplan in Schritten. Dann **stopp und frag mich**.
3. **Bauen** — erst nach meiner Freigabe, in kleinen Schritten, jeder mit
   Begründung. Regeln aus `.claude/architecture.md`:
   - eigene Datei/eigener Ordner unter `features/`, kein Querimport
   - reine Logik nach `domain/`, dort direkt testbar
   - Datenzugriff nur über `data/`, **nicht** in `online_service.dart`
     anhängen, sondern eine neue Datei unter `data/online/`
   - schreibende Aktionen local-first über eine Warteschlange
   - Sicherheit serverseitig (RLS/RPC), die UI spiegelt nur
4. **Abschließen** mit `/pr`.

Keine Scope-Ausweitung. Was dir zusätzlich auffällt, kommt nach
`.claude/backlog.md`, nicht in diesen Commit.
