# 23 Beacon-Laufzeit

> **Status:** 🔴 geplant — die Datenbank kennt die Laufzeit bereits
> (`sessions.expires_at`, Vorgabe 3 Stunden), die App lässt sie nicht
> wählen.
> **Geplant für:** 0.9.14-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ein Beacon sagt „ich bin da, kommt vorbei". Wie lange das gilt, ist von Ort
und Anlass abhängig: Das schnelle Feierabendbier dauert vierzig Minuten,
der Stammtisch fünf Stunden, das Bierfest den ganzen Tag. Eine feste
Laufzeit von drei Stunden ist für beide Enden falsch — sie lädt entweder
zu spät noch jemanden ein oder wirft die Runde vorzeitig aus der Karte.

Dass die Anzeige irgendwann von selbst verschwindet, ist dabei kein
Kompromiss, sondern ein Datenschutzmerkmal: Kein Beacon bleibt aus
Versehen stundenlang stehen.

## Funktion (Nutzersicht)

- Beim Starten einer Session eine Auswahl: **1 h · 2 h · 3 h · 5 h · bis
  Mitternacht**. Vorbelegt bleiben 3 Stunden — der heutige Wert, damit sich
  für niemanden etwas ändert, der nicht hinschaut.
- Die Session-Karte zeigt die verbleibende Zeit („noch 1 h 20").
- **Verlängern** mit einem Tipp, solange die Session läuft.
- Vorzeitig beenden geht wie bisher jederzeit.
- Läuft die Zeit ab, endet die Session automatisch und verschwindet von der
  Karte — daran ändert sich nichts, nur der Zeitpunkt ist jetzt gewählt.

## Technische Umsetzung

- **Geändert:** `features/session/start_session_screen.dart` (Auswahl),
  `widgets/session_card.dart` (Restzeit, Verlängern),
  `data/online/online_service.dart` (`upsertSession` überträgt
  `expires_at`), `data/providers.dart`
- **Server:** keine Migration nötig — `sessions.expires_at` existiert seit
  0001 samt `end_expired_sessions()`, das per Cron abgelaufene Sessions
  schließt. Es fehlt nur, dass der Wert vom Gerät gesetzt wird.
- **Grenzen:** mindestens 30 Minuten, höchstens 12 Stunden — serverseitig
  als `check`-Bedingung, damit die Regel nicht nur in der App steht.

**Restzeit-Anzeige** ohne Timer je Karte: Der bestehende `clockProvider`
tickt bereits im Minutentakt für die Karte; die Anzeige hängt sich daran.

## Modularität

- **Hängt ab von:** Sessions & Beacons (07)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Auswahl aus dem Start-Bildschirm entfernen, Vorgabewert
  serverseitig greifen lassen. Die Datenbank bleibt unverändert.

## Plattformen

Alle.

## Skalierung

Unkritisch, im Gegenteil: Kürzere Laufzeiten bedeuten weniger gleichzeitig
aktive Sessions in Kartenabfragen.

## Umsetzungsplan

1. **Auswahl beim Start** + Übertragung von `expires_at`, serverseitige
   Grenzprüfung (30 min bis 12 h).
   *Prüfkriterium:* Session mit 1 h endet nach einer Stunde automatisch;
   ein Wert außerhalb der Grenzen wird abgelehnt.
2. **Restzeit auf der Karte** über `clockProvider`.
   *Prüfkriterium:* Widget-Test mit fester Uhrzeit.
3. **Verlängern,** wieder gegen dieselbe Obergrenze geprüft.

## Offene Punkte / Ideen

- Hinweis kurz vor Ablauf („dein Beacon endet in 10 Minuten — verlängern?")
  — sinnvoll erst mit Push-Nachrichten
- Merken der zuletzt gewählten Dauer als neue Vorbelegung
