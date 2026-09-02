# 29 Push-Benachrichtigungen

> **Status:** 🟡 gebaut und ausgerollt — wartet auf das FCM-Secret im
> Supabase-Dashboard. · **Seit:** 0.10.4 · **Zuletzt geprüft:** 2026-08-16

## Zielsetzung

Eine Freundschaftsanfrage ist die eine Stelle der App, an der ein anderer
Mensch auf eine **Antwort** wartet. Bis 0.10.3 erfuhr er davon nur, wenn
er die App öffnete. Die Glocke (0031) machte es live — aber nur bei
offener App. Push schließt die Lücke: Das Telefon meldet sich, auch wenn
BrewMates geschlossen ist.

## Funktion (Nutzersicht)

Beim ersten Start nach der Anmeldung fragt Android (ab 13) um Erlaubnis
für Benachrichtigungen. Danach erscheint bei einer Anfrage oder Annahme
eine Systembenachrichtigung: *„Du hast eine neue Freundschaftsanfrage 🍻"*.
Tippen öffnet die App.

**Die Meldung nennt keinen Namen.** Absichtlich — siehe Datenschutz.

## Technische Umsetzung

Die Kette, von hinten nach vorn:

| Schritt | Wo | Datei |
|---|---|---|
| Anfrage → Zeile in `notifications` | Trigger `friendships_notify` | 0031 |
| Zeile → HTTP-Aufruf der Function (asynchron, `pg_net`) | Trigger `notifications_push` | 0033 |
| Geheimnis prüfen, Geräte laden, FCM v1 senden | Edge Function `notify` | `supabase/functions/notify/index.ts` |
| Gerätetoken beim Server halten | `pushRegistrationProvider`, `DevicesApi` | `data/providers/push.dart`, `data/online/api/devices_api.dart` |
| Firebase nur auf Android, sonst stumm | `FirebasePushService` / `NoPush` | `data/push/push_service.dart` |

**Geheimnisse, und wo sie liegen:**

- `notify_webhook_secret` — im **Supabase-Vault**, serverseitig
  zufällig erzeugt. Trigger und Function lesen denselben Wert; die
  Function über die RPC `notify_webhook_secret()` (0034), weil das
  Vault-Schema über PostgREST nicht erreichbar ist. Nur `service_role`
  darf sie aufrufen; pgTAP prüft, dass Angemeldete 42501 bekommen.
- `FCM_SERVICE_ACCOUNT` — das Dienstkonto von Firebase, als
  **Edge-Function-Secret** im Dashboard. Liegt nie im Repo.
- `google-services.json` — im Repo unter `app/android/app/`. Enthält
  keine Geheimnisse (Projekt-ID, App-ID, ein eingeschränkter API-Key);
  Firebase sieht das Einchecken ausdrücklich vor.

**Drei Entscheidungen, die man kennen sollte:**

1. **Push ist ein Zusatz.** Fehlt das Vault-Geheimnis, warnt der Trigger
   und die Anfrage geht durch. Fehlt Firebase auf dem Gerät (Web, Windows,
   Entwicklerrechner ohne Konfiguration), gibt es die stumme Fassung. Kein
   Fehler hier darf die App kosten — BrewMates funktioniert ohne Konto und
   ohne Netz vollständig.
2. **Aber nie still.** Fehlt der Function das FCM-Secret, antwortet sie
   **503 mit Klartext**, nicht 200. Ein Push-System, das „ok" sagt und
   nichts sendet, wäre das Fehlermuster, das dieses Projekt schon dreimal
   hatte. Der erste Probeaufruf fand genau so den Vault-Zugriffsfehler,
   der zu 0034 führte.
3. **Token vor dem Abmelden löschen**, nicht danach. Danach greift RLS
   nicht mehr für die eigene Zeile, und das Telefon klingelte weiter für
   ein Konto, das dort nicht mehr angemeldet ist.

**Weitere Folgen:** `minSdk` 21 → 23 (Android 6.0, 2015) — Vorgabe von
`firebase_messaging`. Berechtigung `POST_NOTIFICATIONS` im Manifest.
Tote Tokens (FCM meldet `UNREGISTERED`) werden beim Senden aus `devices`
entfernt.

## Datenschutz

Google erfährt, *dass* ein Gerät geweckt wird, nicht *warum*. Der Push
trägt einen festen Text je Typ und die ID der Benachrichtigung — keinen
Namen, keinen Inhalt. Den holt sich die App danach unter RLS von
Supabase. In der Datenschutzerklärung steht damit ein Satz zu Firebase
Cloud Messaging als Auftragsverarbeiter; keine Person und keine Anfrage
verlässt den eigenen Server.

## Modularität

- **Hängt ab von:** Glocke/`notifications` (08), Konto (01)
- **Wird gebraucht von:** nichts — rein additiv
- **Ausbauen:** Trigger 0033 entfernen, `pushRegistrationProvider` aus
  `main.dart` nehmen, Firebase-Pakete streichen. Die Glocke bleibt.

## Plattformen

Android. Web/Windows: stumme Fassung (kein Fehler, kein Push). iOS:
APNs-Zweig in der Function noch nicht gebaut — `devices.platform` ist
dafür vorbereitet.

## Skalierung

Ein HTTP-Aufruf je Benachrichtigung, asynchron über `pg_net`. Der
OAuth-Token wird in der Function für seine Laufzeit gecacht. Für Session-
Starts („Anna ist unterwegs") an alle Freunde muss der Beacon-Zweig in
`notify` erst wieder aktiviert werden — mit der Spam-Bremse aus der
Roadmap (nur beim Start, Mindestabstand).

## Umsetzungsstatus

Gebaut, getestet (4 Dart-Tests zur Registrierung, 4 pgTAP zur Webhook-
Härte), Migrationen 0033/0034 und Function live. **Offen:** das Secret
`FCM_SERVICE_ACCOUNT` muss von Hand ins Dashboard — der Schlüssel darf
weder ins Repo noch in eine Sitzung.

## Umsetzungsplan

1. ~~Registrierung, Trigger, Function~~ — erledigt
2. FCM-Secret setzen, dann Ende-zu-Ende-Test mit zwei Konten
3. Beacon-Push mit Spam-Bremse
4. iOS über APNs, wenn es eine iOS-Fassung gibt
