# 38 Benachrichtigungen im Browser

> **Status:** 🔴 geplant — die Untersuchung ist fertig, der Bau nicht.
> Es fehlt **eine Entscheidung des Menschen**, nicht Arbeit an der Tastatur.
> **Seit:** — · **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Die Web-Fassung ist kein Zugeständnis, sondern der einzige Weg für alle
ohne Android — im Testkreis konkret: die iPhone-Nutzer. Alles, was die
App kann, soll dort auch gehen. Seit 0.10.10 fehlt genau ein Stück:
**Benachrichtigungen.** Wer im Browser mitmacht, erfährt nichts von einer
Freundschaftsanfrage und nichts von einem Beacon, solange er die Seite
nicht offen hat.

Woran man merkt, dass es funktioniert: Ein Beacon weckt ein iPhone, auf
dem BrewMates als Web-App auf dem Startbildschirm liegt.

## Funktion (Nutzersicht) — geplant

1. Beim ersten Anmelden im Browser fragt die Seite einmal nach der
   Erlaubnis für Mitteilungen. Sagt jemand Nein, ändert sich nichts —
   Push ist ein Zusatz, wie überall in BrewMates
2. Danach kommen dieselben Meldungen wie auf Android, inhaltsleer
   („Du hast eine neue Benachrichtigung"); Namen und Anlass holt die
   Seite von Supabase, unter RLS
3. Ein Tipp auf die Meldung öffnet BrewMates an der richtigen Stelle
4. Beim Abmelden verschwindet das Gerät wieder aus `devices`

**Auf dem iPhone gibt es eine zusätzliche Hürde**, die keine App der Welt
umgehen kann: Safari erlaubt Web-Push erst, wenn die Seite über „Teilen →
Zum Home-Bildschirm" installiert wurde (seit iOS 16.4). Das gehört ins
Onboarding, nicht in den Code.

## Der Befund: warum das nicht einfach „Firebase auch für Web" ist

Der naheliegende Weg wäre, `FirebasePushService` auch im Browser laufen
zu lassen — dieselbe Kette, ein Paket mehr Konfiguration. **Das
funktioniert an der heutigen Adresse nicht.**

Das Firebase-JS-SDK registriert seinen Service Worker fest unter
`/firebase-messaging-sw.js`, also im **Wurzelverzeichnis der Domain**.
Der Dart-Aufsatz reicht keine eigene Registrierung durch: In
`firebase_messaging_web 4.1.5` ist `serviceWorkerRegistration` in
`GetTokenOptions` auskommentiert (`// TODO - I imagine we won't be
implementing serviceWorkerRegistration type…`). Es gibt also keinen Weg,
dem SDK einen anderen Pfad zu nennen.

BrewMates liegt aber unter `https://orpa1988.github.io/BrewMates/` —
einer **Projektseite**. Die Wurzel `orpa1988.github.io/` gehört einem
anderen Repository; dort eine Datei abzulegen ist nicht möglich. Ein
eigenes Zertifikat oder eine eigene Domain gibt es nicht (kein `CNAME`
im Repo, `--base-href /BrewMates/` in `pages.yml`).

**Das ist ein Hosting-Problem, kein Konfigurationsproblem.** Ein
Firebase-Web-Schlüssel und ein VAPID-Schlüssel aus der Konsole würden
daran nichts ändern — deshalb steht hier auch keine Anleitung, sie zu
holen. Sie wären beschafft und wirkungslos.

## Drei Wege, und was jeder kostet

### A — Eigenes Web-Push statt Firebase *(Empfehlung)*

Der Browser kann Push auch ohne Firebase: `PushManager.subscribe()` mit
einem VAPID-Schlüsselpaar, ein eigener Service Worker, und der Server
schickt direkt an den Endpunkt, den der Browser nennt.

Der entscheidende Punkt: **ein eigener Service Worker darf überall
liegen.** `navigator.serviceWorker.register('sw.js')` bekommt den Bereich
`/BrewMates/` und genau der reicht. Das Hosting-Problem verschwindet.

Und es passt zum Rest: BrewMates verschickt **inhaltsleere** Meldungen.
Ein Web-Push ohne Nutzlast braucht **keine Verschlüsselung** (das sonst
nötige `aes128gcm` entfällt vollständig) — es genügt ein signierter
VAPID-Kopf und ein POST ohne Rumpf. Der Service Worker zeigt einen festen
Satz, den Inhalt holt die Seite wie gehabt von Supabase.

| Was zu bauen ist | Wo |
|---|---|
| VAPID-Schlüsselpaar erzeugen (P-256), öffentlicher Teil in die App, privater als Edge-Function-Secret | einmalig |
| `web/brewmates-push-sw.js` — `push`-Ereignis zeigt die feste Meldung, `notificationclick` öffnet die App | neu |
| Anmeldung im Browser (`PushManager.subscribe`) über eine Plattform-Weiche wie in `data/db/connection/` | `data/push/` |
| `device_platform` um `'web'` erweitern; `devices.push_token` hält im Web die Abo-Daten als JSON | Migration |
| ES256-JWT signieren und an den Endpunkt schicken | `supabase/functions/notify` |

**Aufwand:** überschaubar, aber nicht klein. **Das eigentliche Risiko ist
ein anderes:** Web-Push lässt sich **hier nicht testen.** Es braucht eine
echte HTTPS-Veröffentlichung, einen echten Browser und einen Menschen,
der die Erlaubnis erteilt. Kein Widget-Test und kein pgTAP deckt das ab.
Wer das baut, baut es blind und prüft es danach am lebenden Objekt — mit
genau einem Prüfer je Browser.

### B — BrewMates an die Wurzel einer Domain stellen

Entweder eine eigene Domain (dann `CNAME` im Repo und ein DNS-Eintrag)
oder das Repository `ORPA1988/ORPA1988.github.io` als Wurzelseite. Danach
läge `/firebase-messaging-sw.js` im eigenen Bereich, und Firebase
funktionierte im Browser genau wie auf Android — dieselbe Kette,
dieselbe Edge Function, ein Paket Konfiguration.

**Aufwand am Code:** klein. **Aufwand außerhalb:** eine Domain oder ein
zweites Repository, eine geänderte Adresse für alle Tester, und
[docs/09](../09-wachstum-und-geschaeftsmodell.md) hält ausdrücklich fest,
dass keine Domain Voraussetzung sein soll. Das spricht dagegen, ist aber
keine technische Hürde.

### C — Nichts tun und es sagen

Der Browser bleibt ohne Benachrichtigungen; wer sie will, nimmt die
Android-App. Ehrlich, kostenlos — und schließt die iPhone-Nutzer im
Testkreis von der Hälfte der App aus (Beacon und Freundschaftsanfrage
sind beide auf eine Reaktion angewiesen).

## Empfehlung

**A.** Es löst das Problem an der Stelle, an der es entsteht, ohne die
Adresse zu ändern und ohne eine Domain zur Voraussetzung zu machen. Dass
die Nutzlast entfällt, ist kein Zufall, sondern folgt aus einer
Entscheidung, die dieses Projekt schon getroffen hat: Der Push weckt das
Gerät, er erzählt nichts.

**Vor dem Bau zu klären** — und das ist die eigentliche Frage an den
Menschen:

1. Ist der ungetestete Bau in Ordnung? Er wird erst nach der
   Veröffentlichung prüfbar, und der erste Versuch wird vermutlich nicht
   sitzen (Berechtigungen, iOS-Eigenheiten, Endpunkt-Fehler).
2. Wer testet? Es braucht mindestens ein iPhone mit installierter
   Web-App und einen Desktop-Browser.

## Technische Umsetzung

Noch nichts gebaut. Was heute steht und wiederverwendet wird:

- `notifications` (0031) als einzige Quelle, `notifications_push` (0033)
  als Auslöser, `notify` als Versender — alle drei bleiben, es kommt nur
  ein zweiter Versandweg dazu
- `DevicesApi.register(token, platform:)` nimmt den Plattformwert schon
  entgegen; heute steht dort immer `'android'`
- `FirebasePushService` liefert im Browser bewusst `NoPush` — die Weiche
  ist da, sie führt nur noch nirgendwohin

**Was `notify` heute davon abhält:** die Zeile
`.eq("platform", "android")`. Sie bleibt richtig, bis es einen zweiten
Weg gibt; ein Web-Abo an FCM zu schicken, ginge nicht gut aus.

## Modularität

- **Hängt ab von:** Push (29), Konto (01)
- **Wird gebraucht von:** nichts — es ist ein zweiter Versandweg
- **Ausbauen:** Service Worker, Plattform-Weiche und den Web-Zweig in
  `notify` entfernen. Die `'web'`-Zeilen in `devices` verwaisen und
  schaden nicht.

## Plattformen

| Plattform | Heute | Nach Weg A |
|---|---|---|
| Android | ✅ FCM | unverändert |
| Web (Chrome, Edge, Firefox, Desktop) | ❌ | ✅ |
| Web (Safari iOS) | ❌ | ✅, aber nur als installierte Web-App |
| Web (Safari macOS) | ❌ | ✅ ab Safari 16 |
| Windows / macOS (Flutter) | ❌ | unverändert — dort gibt es kein Push-Ziel |

## Skalierung

Ein Abo je Browser und Konto, dieselbe Größenordnung wie `devices` heute.
Der Versand ist ein HTTP-Aufruf je Gerät — wie bei FCM. Tote Endpunkte
melden `404`/`410` und gehören dann aus `devices` gelöscht, genau wie
heute `UNREGISTERED`.

## Umsetzungsstatus

Untersucht, nicht gebaut. Der Befund oben ist das Ergebnis: Der Weg über
Firebase ist an dieser Adresse verschlossen, und das ließ sich am
Paketstand (`firebase_messaging_web 4.1.5`) und an `pages.yml` belegen,
nicht nur vermuten.

## Umsetzungsplan (Weg A)

1. **Entscheidung** einholen (siehe Empfehlung) — *offen*
2. VAPID-Schlüsselpaar erzeugen; öffentlicher Teil in `core/`, privater
   als Edge-Function-Secret im Dashboard. *Ergebnis:* beide Seiten haben
   ihren Teil. *Prüfkriterium:* die Function startet ohne Fehler
3. Migration: `device_platform` um `'web'`; Kommentar an
   `devices.push_token`, dass dort im Web ein JSON-Abo steht.
   *Prüfkriterium:* pgTAP legt eine `'web'`-Zeile an
4. `web/brewmates-push-sw.js` und die Registrierung in `index.html`.
   *Prüfkriterium:* der Worker erscheint in den Entwicklerwerkzeugen mit
   Bereich `/BrewMates/`
5. Plattform-Weiche in `data/push/` nach dem Muster
   `data/db/connection/` (Conditional Import, kein `dart:js_interop` im
   nativen Zweig). *Prüfkriterium:* `flutter build apk` und
   `flutter build web` bleiben beide grün
6. `notify`: zweiter Versandweg, ES256-JWT, POST ohne Rumpf; `404`/`410`
   räumen die Zeile ab. *Prüfkriterium:* Probeaufruf mit einem echten Abo
7. Veröffentlichen und **am lebenden Objekt prüfen** — Desktop-Browser
   zuerst, iPhone danach

## Offene Punkte / Ideen

- Der Onboarding-Hinweis für iOS („Zum Home-Bildschirm hinzufügen") fehlt
  unabhängig von Push und wäre auch ohne ihn nützlich
- Die Glocke hat keinen eigenen Bildschirm ([Funktion 29](29-push-benachrichtigungen.md));
  im Browser fällt das stärker auf, weil dort öfter etwas verpasst wird
