# 17 App-Update

> **Status:** 🟢 fertig für Android — prüft gegen GitHub-Releases und
> bietet die neue Fassung an.
> **Seit:** 0.9.6 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Solange die App außerhalb des Play Stores verteilt wird, erfährt niemand
von neuen Fassungen. Die Update-Prüfung schließt diese Lücke — und stellt
sicher, dass Fehlerbehebungen die Nutzer erreichen, statt auf einem alten
Stand zu versanden.

## Funktion (Nutzersicht)

- Beim Start prüft die App im Hintergrund, ob es eine neuere Fassung gibt
- Wenn ja: Hinweis auf der Startseite mit den Neuerungen
- Ein Tipp lädt die APK herunter und startet die Installation
- Die Prüfung ist still: Ohne Netz oder ohne neue Fassung passiert nichts

## Technische Umsetzung

- **Dateien:** `core/app_update.dart`, `widgets/update_dialog.dart`,
  Anzeige in `features/home/home_screen.dart`
- **Quelle:** GitHub-Releases-API des Repositories
- **Vergleich:** `compareAppVersions` vergleicht numerisch und ignoriert
  Suffixe wie `-beta` — `0.9.13` ist damit korrekt neuer als `0.9.9`
- **Version:** `AppConfig.appVersion` muss mit `pubspec.yaml`
  übereinstimmen; ein Test erzwingt das

**Die Signierung ist Teil dieser Funktion,** auch wenn sie im Build
steckt: Ohne festen Schlüssel verweigert Android die Installation über
die bestehende App — und der Umweg über Deinstallation kostet die lokalen
Daten.

## Modularität

- **Hängt ab von:** nichts
- **Wird gebraucht von:** nichts
- **Ausbauen:** `core/app_update.dart`, den Dialog und die Karte auf der
  Startseite entfernen. Sobald die App im Play Store ist, wird das
  wahrscheinlich passieren — dann übernimmt der Store.

## Plattformen

| Plattform | Verhalten |
|---|---|
| Android | vollständig: Prüfung, Hinweis, Installation |
| Web | nicht nötig — ein Neuladen holt die aktuelle Fassung |
| Windows / iOS / macOS | keine Prüfung; dort gibt es keinen Verteilweg |

## Skalierung

Eine Abfrage je Appstart gegen die GitHub-API. Deren Grenze für
nicht angemeldete Zugriffe (60 Anfragen pro Stunde und IP) wird erst bei
vielen Nutzern hinter derselben Adresse relevant — dann wäre eine eigene
Versionsdatei der bessere Weg.

## Umsetzungsstatus

Vollständig für Android. Ein bekannter Fall aus der Praxis: Bei aktivem
VPN kann der Download hängen bleiben; die App kann das nicht beheben, aber
sie sollte es benennen.

## Umsetzungsplan

1. Hinweis, wenn ein Download ungewöhnlich lange steht („VPN aktiv?")
2. Nach dem Play-Store-Start: Funktion entfernen oder auf
   Store-Verweis umstellen

## Offene Punkte / Ideen

- Eigene Versionsdatei statt GitHub-API, falls deren Grenze stört
