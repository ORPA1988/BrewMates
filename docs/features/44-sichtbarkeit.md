# 44 Wer sieht meine Check-ins

> **Status:** 🟢 fertig — Voreinstellung im Konto, je Check-in
> übersteuerbar, nachträglich änderbar
> **Seit:** 0.10.20 · **Zuletzt geprüft:** 2026-09-05
>
> Roadmap-Rang 3, [#130](https://github.com/ORPA1988/BrewMates/issues/130) —
> und die älteste offene Zusage der App: Sie steht seit dem Anfang als
> [v1]-Ziel in [docs/02](../02-funktionsspezifikation.md), Abschnitt 10.

## Zielsetzung

**Die Spalte gibt es seit Migration 0001. Die Bedienung nie.**
`checkins.visibility` kennt `friends`, `crew` und `private`, die
Sichtbarkeitsregel wertet alle drei aus — und die App schreibt an genau
einer Stelle hart `'visibility': 'friends'`. Wer einen Check-in für sich
behalten wollte, konnte es nicht.

Seit Migration 0050 hängt daran mehr als vorher: Wer in einer Runde
eincheckt, dessen Check-in sehen **alle Mitrundigen** — auch Leute, mit
denen man nicht befreundet ist. Das ist gewollt und der Sinn der
Funktion, aber es war nicht abwählbar.

**Woran man merkt, dass es funktioniert:** Ein Check-in, den niemand
sehen soll, ist mit einem Tipp privat — und bleibt es auch, wenn man in
einer Runde sitzt.

## Die Entscheidung: global **und** je Check-in

Vom Menschen entschieden (2026-09-05): **beides**, nicht eines von
beidem.

- **Eine Voreinstellung** im Konto gilt für alles Neue. Wer grundsätzlich
  privat unterwegs ist, sagt das einmal statt bei jedem Glas.
- **Je Check-in übersteuerbar**, beim Anlegen und nachträglich beim
  Bearbeiten. Der eine Abend, den man doch teilen will, kostet keinen
  Umweg über die Einstellungen.

Die Voreinstellung steht **am Server**, nicht nur auf dem Gerät: Sie ist
eine Aussage über einen Menschen, nicht über ein Telefon, und gilt
deshalb auch im Browser.

## Funktion (Nutzersicht)

Drei Stufen, überall mit denselben Worten:

| Auswahl | Wer sieht den Check-in |
|---|---|
| **Freunde** | deine Freunde — und Mitrundige, wenn du in einer Runde eincheckst |
| **Nur meine Crew** | Mitglieder der Crew, zu der die Runde gehört |
| **Privat** | nur du. Auch Mitrundige nicht |

- **Beim Einchecken** ein Zeilenwahl unter der Notiz, vorbelegt mit der
  Voreinstellung.
- **Nachträglich** im Bearbeiten-Blatt der Check-in-Karte
  ([Funktion 27](27-check-ins-bearbeiten.md)).
- **Die Voreinstellung** im Konto-Bildschirm.

**„Nur meine Crew" ohne Runde ist wirkungslos** — die Regel verlangt eine
Session mit Crew. Die App sagt das an der Auswahl, statt eine Sicherheit
zu behaupten, die die Datenbank nicht hält.

## Technische Umsetzung

**Was schon da war** (und nur benutzt werden musste):

- `checkins.visibility` mit dem Enum `visibility` (0001)
- die Regel `checkins_select` (0050), die alle drei Werte auswertet —
  **inklusive `private`, das Mitrundige ausschließt**
- `SessionVisibility` in Dart mit denselben drei Werten

**Neu:**

- **Server:** Migration 0058 — `profiles.default_visibility`, Vorgabe
  `friends`. Ändern darf nur der Besitzer (bestehende `profiles_update`).
- **Lokal:** Drift v16 — `checkins.visibility` und
  `profiles.defaultVisibility`. Bis dahin kannte die lokale Datenbank die
  Sichtbarkeit eines Check-ins gar nicht; sie entstand erst beim
  Hochladen.
- **Geändert:** `checkins_api.dart` sendet die gespeicherte Sichtbarkeit
  statt der festen Zeichenkette. Das ist die eigentliche Zeile, um die es
  geht.

## Was beim Bauen schiefging (2026-09-05)

**Die neue Spalte hatte keine Rechte.** Der erste Entwurf von 0058 endete
nach dem `alter table` — mit der Begründung, `profiles_update` decke ja
jede Spalte ab. Die CI hat das in Sekunden widerlegt:

```
ERROR: permission denied for table profiles
```

Seit 0025/0026 hat `authenticated` auf `profiles` **keine
Tabellenrechte, sondern Spaltenrechte** — so wurde `thirsty_until`
entzogen, ohne die Tabelle zu sperren. Eine neu angelegte Spalte erbt
davon nichts: Sie ist für die App unsichtbar und unbeschreibbar, bis sie
ausdrücklich freigegeben wird.

Das ist wörtlich das Muster von 0051/0052 („entzieht, was 0051 nur
behauptet hatte"), nur diesmal vor dem Livegang bemerkt. Beides steht
jetzt in einer Datei, und der pgTAP-Test prüft **die Rechte mit**, nicht
nur das Verhalten:

```sql
select ok(has_column_privilege('authenticated', 'public.profiles',
                               'default_visibility', 'update'), …);
```

Ohne diese zwei Zeilen wäre es erst aufgefallen, wenn ein Mensch seine
Voreinstellung nicht speichern kann.

## Modularität

- **Hängt ab von:** Check-ins (02), Konto (01), Runden (40)
- **Wird gebraucht von:** nichts — die Regel greift auch ohne die
  Bedienung, sie sah bloß immer denselben Wert
- **Ausbauen:** Auswahl entfernen, `visibility` wieder fest auf `friends`.
  Bestehende Zeilen behalten ihren Wert und bleiben gültig.

## Plattformen

Alle gleich. Die Voreinstellung liegt am Server und gilt geräteübergreifend.

## Skalierung

Unkritisch: eine Spalte mehr je Zeile, dieselbe Policy.

## Umsetzungsplan

| Schritt | Was | Prüfkriterium |
|---|---|---|
| ~~1~~ | ~~Migration 0058 + Drift v16~~ — erledigt | ✅ pgTAP, fünf Tests |
| ~~2~~ | ~~Auswahl im Check-in, Voreinstellung im Konto~~ — erledigt | ✅ Vorbelegung greift, Wahl gewinnt |
| ~~3~~ | ~~`checkins_api` sendet den gewählten Wert~~ — erledigt: **das war die eine Zeile, um die es ging** | ✅ eigener Test |
| ~~4~~ | ~~Nachträglich änderbar (Funktion 27)~~ — erledigt | ✅ zwei Tests, darunter „ohne Angabe bleibt es, wie es war“ |

## Bewusst nicht

- **Keine Sichtbarkeit „öffentlich".** Es gibt keinen öffentlichen Feed,
  und eine Stufe anzubieten, die nichts tut, wäre ein Versprechen.
- **Keine Ausnahmen je Person** („alle außer Anna"). Das ist eine
  Blockierliste mit anderem Namen, und die gibt es schon.
- **Kein nachträgliches Ändern fremder Check-ins**, auch nicht für
  Moderatoren: Wer etwas privat gestellt hat, hat entschieden.
