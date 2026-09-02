# 30 Bierlaune

> **Status:** 🟢 fertig · **Seit:** 0.9.x (Migration 0018) ·
> **Zuletzt geprüft:** 2026-09-02

## Zielsetzung

Zwischen „nichts" und „ich sitze schon im Wirtshaus" (Beacon) fehlte die
Stufe davor: *„Ich hätte heute Lust."* Die Bierlaune ist genau das — ein
Signal ohne Ort, ohne Verpflichtung, das von selbst wieder verschwindet.
Sie senkt die Schwelle, sich zu verabreden, weil niemand der Erste sein
muss, der einen Ort nennt.

## Funktion (Nutzersicht)

- Auf der Startseite ein Knopf **„🍺 Bierlaune!"**. Ein Tipp setzt sie
  für **4 Stunden**; der Knopf zeigt dann „Bierlaune bis HH:MM" und ein
  zweiter Tipp nimmt sie zurück.
- Freunde sehen auf ihrer Startseite, **wer gerade Lust hat** — als
  Liste, nicht als Push. Sichtbar nur für den Kreis **„Freund"** und
  enger (siehe Freundeskreise, 24); Bekannte sehen nichts.
- Läuft ohne Zutun aus. Es gibt keine Historie und keine Statistik —
  bewusst: Eine Laune ist kein Datensatz.

## Technische Umsetzung

- **Dateien:** `features/home/home_screen.dart` (Knopf + Liste),
  `data/providers.dart` → `setBierlaune()`,
  `data/online/api/friends_api.dart` → `setBierlaune()` (schreibt
  `profiles.thirsty_until`), `myThirstyUntil()` (RPC `my_thirsty_until`),
  `thirstyFriends()` (RPC `thirsty_friends`)
- **Server:** Spalte `profiles.thirsty_until` (0018). Seit 0026 ist die
  Spalte **nicht direkt lesbar** — Lesen nur über die beiden RPCs, die
  serverseitig auf das eigene Konto bzw. den Kreis „Freund" filtern.
  Schreiben bleibt direkt (0026 fasst nur `select` an).
- **Ehrlichkeit vor Bequemlichkeit:** `setBierlaune` gibt zurück, ob der
  Server es angenommen hat. Eine Bierlaune, die niemand sieht, ist keine
  — ein Fehlschlag wird gemeldet, nicht als Erfolg dargestellt.
- Abgemeldet gibt es den Knopf nicht: Ohne Konto gibt es niemanden, der
  die Laune sehen könnte.

## UX-Hinweise

- Der Knopf steht neben dem Schnell-Check-in auf der Startseite — die
  beiden häufigsten Ein-Tipp-Handlungen nebeneinander.
- Die Restzeit steht im Knopf selbst („bis 21:30"), nicht in einem Dialog.

## Modularität

- **Hängt ab von:** Konto (01), Freunde/Freundeskreise (08, 24)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Knopf und Liste aus der Startseite nehmen, zwei RPCs
  entfernen. Kein anderer Teil liest `thirsty_until`.

## Plattformen

Alle.

## Skalierung

Zwei RPC-Aufrufe im 5-Minuten-Takt (`thirstyFriendsProvider`), gefiltert
über Index auf `friendships`. Unkritisch.

## Umsetzungsstatus

Vollständig. Fehlte bisher als eigenes Dokument — tauchte nur als
Nebensatz in 24 auf.

## Offene Punkte / Ideen

- Optionaler Push an den Kreis „Best Buddys", wenn jemand Bierlaune
  setzt — mit Spam-Bremse (nicht öfter als einmal pro Stunde je Person)
- Freitext „wo/was" zur Laune (z. B. „Gastgarten?"), bewusst noch nicht:
  Jedes Pflichtfeld macht aus dem Ein-Tipp-Signal ein Formular
