# 16 Datensynchronisation

> **Status:** 🟡 teilweise — Wiederherstellung und Offline-Warteschlange
> funktionieren, echter Delta-Abgleich fehlt.
> **Seit:** 0.9.8 (0016) · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Die App ist **local-first**: Sie gehört dem Gerät, nicht dem Netz. Check-in,
Tagebuch und Bierdatenbank funktionieren im Bierkeller ohne Empfang. Der
Server ist Sicherung und Bindeglied zu anderen — nicht die Voraussetzung
zum Arbeiten.

Daraus folgt die Pflicht, die den Aufwand rechtfertigt: **Ein Update darf
niemals Daten kosten.**

## Funktion (Nutzersicht)

- Alles funktioniert offline; hochgeladen wird, sobald wieder Netz da ist
- Nach der Anmeldung auf einem neuen Gerät kehren Check-ins, Abzeichen und
  Wunschliste zurück
- Gasthaus-Änderungen ohne Netz werden gemerkt und später übertragen
- Ein einmaliger Assistent lädt alte, rein lokale Check-ins hoch

## Technische Umsetzung

- **Dateien:** `data/restore.dart` (Wiederherstellung),
  `data/venue_queue.dart` (Warteschlange), `data/venue_sync.dart`,
  `data/community_sync.dart`, `data/online/online_service.dart`
  (Abschnitte „Upload-Assistent" und „Cloud-Restore")
- **Server:** `checkins`, `user_badges`, `wishlist_items` (0016)
- **Grundsatz:** Zusammenführung als **Vereinigung**, nie als Ersetzung —
  und jede Wiedergabe muss wiederholbar sein, ohne Schaden anzurichten
- **Signierung:** Der Release-Build wird mit einem festen Schlüssel
  signiert. Ohne das ersetzt Android die App nicht, sondern verlangt
  Deinstallation — und die löscht die lokale Datenbank.

## Modularität

- **Hängt ab von:** Konto (01)
- **Wird gebraucht von:** allem, was Daten behalten soll
- **Ausbauen:** nicht sinnvoll.

## Plattformen

Alle. Im Browser liegt die Datenbank in OPFS statt in einer Datei — die
Weiche steht in `data/db/connection/`, der Rest der App merkt nichts davon.
Wichtig: Wer die Browserdaten löscht, löscht die lokale Datenbank; die
Wiederherstellung ist im Web also nicht Zugabe, sondern Rettungsanker.

## Skalierung

Die Wiederherstellung holt **immer alles** — bei tausenden Check-ins wird
der erste Start auf einem neuen Gerät zäh. Nötig wäre ein Abgleich nach
Zeitstempel (nur Neues seit dem letzten Mal). Das ist der klarste offene
Punkt dieser Funktion.

Der Community-Abgleich lädt acht Dateien vollständig, auch wenn sich
nichts geändert hat — mit `ETag` oder Versionsnummer ließe sich das
sparen.

## Umsetzungsstatus

Funktioniert und ist erprobt. Es fehlt die Effizienz, nicht die Funktion.

## Umsetzungsplan

1. Delta-Wiederherstellung über Zeitstempel
2. Community-Abgleich nur bei geänderter Version herunterladen
3. Löschungen mitsynchronisieren, sobald
   [Funktion 19](19-feed-eintraege-loeschen.md) steht

## Offene Punkte / Ideen

- Echtzeit-Abgleich über Supabase Realtime statt Abfragen
- Datenexport für die Nutzer (gehört zur Datenhoheit)
