# Architektur — Landkarte

Kurzfassung zum schnellen Einlesen. Die Tiefe steht in
`docs/03-architektur.md`, `docs/04-datenmodell.md` und
`docs/11-modularitaet-und-portierbarkeit.md`. Diese Datei sagt nur, **wo
etwas liegt und was wovon abhängen darf**.

## Schichten

```
features/*  Bildschirme, nur UI + Riverpod-Zugriff
   ↓ darf lesen
domain/*    reine Dart-Logik, keine Flutter-, keine DB-Importe
   ↓
data/*      Drift-DB, Supabase, Synchronisation, Provider
   ↓
core/*      Konfiguration, Theme, Router, Formatierung, externe Links
```

**Regeln, die nicht verhandelbar sind:**

- Ein `features/`-Ordner importiert **nie** einen anderen. Navigation läuft
  über `core/router.dart`. Deshalb ist jede Funktion einzeln entfernbar.
- `domain/` importiert nichts aus `data/` oder `features/` — reine Logik,
  direkt testbar (`badges`, `challenges`, `streak`, `statistics`,
  `account_level`, `opening_hours`). Braucht die Logik Daten aus `data/`,
  bekommt sie einen **eigenen Eingabetyp** in `domain/` (Vorbild
  `StatsEntry`); ein reines Wert-Enum wandert nach `core/` (Vorbild
  `ServingStyle`). Die Übersetzung gehört in das Feature, das beides
  liest — **nicht** in `data/`, sonst hängen die Schichten aneinander.
  `test/architecture_test.dart` erzwingt das, und die Ausnahmeliste dort
  ist **seit 15.08.2026 leer**. Sie darf nur schrumpfen.
- `core/` trägt neben Konfiguration, Theme, Router und Formatierung auch
  die **geteilten Wertetypen**, die `domain/` und `data/` beide brauchen
  (`serving_style.dart`, `checkin_facts.dart`). Sie enthalten keine Logik
  und keine Abfragen — nur Form. Das ist der Weg, der die beiden Schichten
  verbindet, ohne sie aneinanderzuhängen.
- Nur `data/` spricht mit Drift oder Supabase. Kein Bildschirm setzt eine
  Abfrage selbst ab.
- `data/db/database.g.dart` ist generiert. Nie von Hand ändern —
  `dart run build_runner build` nach jeder Schemaänderung.

## Datenhaltung: drei Quellen, klar getrennt

| Quelle | Inhalt | Schreibrichtung |
|---|---|---|
| **Drift/SQLite** (lokal) | Check-ins, Tagebuch, Wunschliste, Cache der Community-DB | Wahrheit für alles Eigene, offline nutzbar |
| **Community-JSON** (`app/assets/data/`) | Biere + Brauereien AT/BY/DE/CH | **READ-ONLY in der App.** GitHub-Sync überschreibt wholesale. Korrekturen nur als GitHub-Issue |
| **Supabase** (EU) | Konten, Freunde, Beacons, Gasthäuser, Challenges, Foto-Check-ins | Serverseitig per RLS/RPC durchgesetzt |

**Sync-Invariante:** Biere mit `isUserSubmitted == false` und Brauereien mit
Nicht-UUID-ID sind unveränderlich. Bearbeitbar sind nur nutzererstellte
Zeilen (UUID) und Gasthäuser.

## Schreibpfade sind Warteschlangen

Jede schreibende Aktion wirkt sofort lokal und wird später abgeglichen:
`venue_edit_queue` (FIFO, last-write-wins) und `checkin_delete_queue`. Das
ist das Vorbild für alle künftigen Schreibpfade — nicht der direkte
Serveraufruf.

## Bekannte Ballungen (bei Änderungen beachten)

- `data/online/online_service.dart` (~1.570 Z.) — sämtliche Supabase-Aufrufe
- `data/providers.dart` (~940 Z.) — sämtliche Riverpod-Provider

Beide wachsen mit jedem Feature. **Neue Funktionen bekommen eine eigene
Datei**, nicht noch einen Block in diesen beiden. Siehe Backlog B-3.

## Plattform-Weiche

`data/db/connection/` entscheidet per Conditional Import zwischen nativer
SQLite-Anbindung und `WasmDatabase` im Browser. Der native Pfad ist
byte-identisch zur vorherigen Fassung — hier nichts „aufräumen".

## Monetarisierung später ohne Bruch

Phase 1 ist kostenlos, ohne Paywall, ohne Tracking, ohne Werbung. Damit
Phase 2 kein Refactoring erzwingt: Premium-Kandidaten kommen als eigene
Feature-Ordner mit eigenem Provider, und die Prüfung „darf der Nutzer das?"
läuft über **eine** Stelle (analog `accountLevelProvider` /
`user_features`). Keine verstreuten `if (isPro)`-Abfragen.
