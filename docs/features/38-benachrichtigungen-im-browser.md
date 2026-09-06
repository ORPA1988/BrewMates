# 38 Benachrichtigungen im Browser

> **Status:** 🟢 fertig für den festgelegten Zweck — Meldungen erreichen
> dich, **solange BrewMates in einem Tab offen ist**. Ist der Tab zu,
> kommt nichts; das ist die bewusste Grenze, nicht eine Lücke.
> **Seit:** 0.10.11-beta · **Zuletzt geprüft:** 2026-09-06

## Zielsetzung

Die Web-Fassung ist kein Zugeständnis, sondern der einzige Weg für alle
ohne Android — im Testkreis konkret: die iPhone-Nutzer. Eine
Freundschaftsanfrage und ein Beacon sind beide auf eine **Reaktion**
angewiesen; wer sie nicht mitbekommt, lässt jemanden warten.

**Der Zuschnitt kam vom Menschen** (2026-09-03): „Push für Browser muss
nur bei geöffneter Webapp funktionieren." Das ist die entscheidende
Festlegung dieses Dokuments — sie macht aus einem großen Umbau eine
kleine Änderung. Warum, steht unter „Was das erspart".

Woran man merkt, dass es funktioniert: Der Tab liegt hinten, jemand
startet einen Beacon, und man erfährt es trotzdem.

## Funktion (Nutzersicht)

1. **Die Startseite sagt, dass es das gibt** — nur im Browser, nur
   angemeldet, und nur solange es etwas zu tun gibt. Zwei Gesichter, je
   nach Lage: „Meldungen im Browser einschalten" führt zum Knopf im
   Konto, „BrewMates auf den Home-Bildschirm" öffnet die Anleitung für
   das iPhone. Wegwischen merkt sich der Browser dauerhaft
2. Im Konto steht — **nur im Browser** — „Benachrichtigungen erlauben".
   Ein Tipp, der Browser fragt, fertig
3. Danach: Liegt BrewMates vorn, erscheint wie bisher das Banner am
   unteren Rand. Liegt der Tab hinten, kommt eine Systemmeldung; ein
   Klick holt das Fenster nach vorn und springt an die richtige Stelle
4. **Ohne Erlaubnis geht nichts verloren:** Was während des Hintergrunds
   ankam, erscheint beim Zurückkommen als Banner — bei mehreren als
   „3 neue Meldungen, während du weg warst"
5. Ist der Tab geschlossen, kommt nichts. Dafür gibt es die Android-App

Zustände, die die App ausspricht statt zu schweigen:

| Lage | Was im Konto steht |
|---|---|
| noch nicht gefragt | der Knopf, mit dem Satz „Ist der Tab zu, kommt nichts" |
| erlaubt | „Du bekommst sie, solange BrewMates in einem Tab offen ist" |
| abgelehnt | der Weg zurück über das Schloss-Symbol — die App kann nicht erneut fragen |
| gibt es nicht (iPhone ohne installierte Web-App) | gar nichts; der Knopf wäre eine Sackgasse |

Und auf der **Startseite**, weil das Konto niemand von selbst aufsucht:

| Lage | Was auf der Startseite steht |
|---|---|
| kein Browser (Android-App) | nichts — dort gibt es echten Push |
| Browser ohne `Notification`, in einem Tab | „BrewMates auf den Home-Bildschirm", mit Anleitung |
| Browser ohne `Notification`, schon installiert | nichts — die Installation ist geschehen und hat nicht geholfen |
| noch nicht gefragt | „Meldungen im Browser einschalten", führt ins Konto |
| erlaubt oder abgelehnt | nichts — beides ist eine Antwort |
| weggewischt | nichts, dauerhaft und je Hinweis getrennt |

**Der Hinweis fragt nicht selbst.** Die Erlaubnis muss aus einer echten
Geste kommen und der Browser gibt nur einen Versuch — deshalb führt er
zum Knopf, statt ihn vorwegzunehmen.

**Auf dem iPhone** stellt Safari `Notification` außerhalb einer
installierten Web-App nicht bereit. Dort greift Punkt 3: Die Meldungen
werden gesammelt und beim Zurückkommen gezeigt. Das ist kein Ersatz für
eine Systemmeldung, aber es ist der Unterschied zwischen „später gesehen"
und „nie erfahren".

## Was das erspart — und warum der andere Weg verschlossen war

Der naheliegende Weg wäre gewesen, Firebase auch im Browser laufen zu
lassen. **Das geht an dieser Adresse nicht**, und der Grund ist belegbar:

Das Firebase-JS-SDK registriert seinen Service Worker fest unter
`/firebase-messaging-sw.js`, also im **Wurzelverzeichnis der Domain**. Ein
anderer Pfad lässt sich nicht angeben — in `firebase_messaging_web 4.1.5`
ist `serviceWorkerRegistration` in `GetTokenOptions` auskommentiert
(`// TODO - I imagine we won't be implementing…`). BrewMates liegt unter
`https://orpa1988.github.io/BrewMates/`, einer **Projektseite**; die
Wurzel gehört einem anderen Repository, ein `CNAME` existiert nicht
(`pages.yml` baut mit `--base-href /BrewMates/`).

Der Ausweg wäre eigenes Web-Push gewesen: eigener Service Worker,
VAPID-Schlüsselpaar, ES256-Signatur in der Edge Function, eine Migration
für `device_platform = 'web'`, ein zweiter Versandweg. Machbar — und
**hier grundsätzlich nicht prüfbar**, weil Web-Push eine echte
Veröffentlichung, einen echten Browser und eine erteilte Erlaubnis
braucht.

**Die Festlegung „nur bei geöffneter Web-App" macht all das überflüssig.**
Eine Meldung, die die geöffnete Seite selbst erzeugt, braucht keinen
Service Worker, keinen Push-Dienst, keinen Schlüssel und keine Migration.
Der Weg, auf dem die Nachricht ankommt, steht ohnehin längst: Realtime
liefert die Zeile aus `notifications` in Sekunden (0031). Gefehlt hat nur,
sie **sichtbar** zu machen, wenn der Tab hinten liegt.

Damit bleibt genau ein Fall unbedient: Tab geschlossen. Wer den auch will,
findet die Kosten oben — dieser Absatz bleibt stehen, damit sie nicht neu
ermittelt werden müssen.

## Technische Umsetzung

- **Dateien:** `data/push/browserfenster.dart` (Schnittstelle + Weiche),
  `browserfenster_stub.dart` (überall sonst), `browserfenster_web.dart`
  (Browser), `data/providers/glocke.dart` (Provider, `webHinweisFuer`),
  `features/shell/app_shell.dart` (Verzweigung),
  `features/account/account_screen.dart` (Erlaubnis),
  `features/home/home_screen.dart` (`_WebHinweisKarte`)
- **Paket:** `web: ^1.1.1` — reines Dart, kein Plugin, und ohnehin schon
  in genau dieser Fassung als transitive Abhängigkeit aufgelöst; die
  Zeile in `pubspec.yaml` macht sie nur benutzbar
- **Plattform-Weiche** nach dem Muster von `data/db/connection/`
  (`if (dart.library.js_interop)`), damit `dart:js_interop` nie in einen
  nativen Build gerät
- **Kein Servercode.** Keine Migration, keine Änderung an `notify`, kein
  Eintrag in `devices` — im Browser gibt es kein Gerätetoken, weil es
  keinen Push-Dienst gibt

### Die Verzweigung, um die es geht

```
Meldung kommt an (Realtime)
├─ Fenster sichtbar        → Banner wie bisher
├─ Hintergrund + erlaubt   → Systemmeldung (tag = Art, ersetzt statt stapelt)
└─ Hintergrund + nicht     → merken; beim Zurückkommen als Banner
```

Der dritte Zweig ist der, der ohne diese Änderung verloren ging — und der
einzige, den iPhone-Nutzer überhaupt erreichen.

### Drei Entscheidungen, die man kennen sollte

1. **Der Erlaubnis-Knopf steht im Konto, nicht im Start.** Die Frage muss
   aus einer echten Geste kommen: Firefox verlangt das seit Version 72,
   Chrome ignoriert ungefragte Anfragen zunehmend. Eine automatische
   Anfrage beim Start würde oft still abgelehnt — und verbraucht dabei den
   einen Versuch, den man hat.
2. **Merkmalsprüfung statt Versuch.** `Notification` fehlt auf dem iPhone
   außerhalb einer installierten Web-App **vollständig**; ein Zugriff wirft,
   statt `denied` zu melden. Deshalb `globalContext.has('Notification')`.
3. **Der Text enthält den Namen** („Clara möchte dein BrewMate sein") —
   anders als der Android-Push, der bewusst inhaltsleer ist. Der
   Unterschied ist kein Versehen: Der Android-Push läuft über Google, das
   erfahren soll, *dass* ein Gerät geweckt wird, nicht *warum*. Diese
   Meldung entsteht **im Browser selbst**, aus Daten, die die Seite
   ohnehin schon unter RLS geladen hat. Sie verlässt das Gerät nie.

## Modularität

- **Hängt ab von:** Push/Glocke (29) für die Quelle, Konto (01)
- **Wird gebraucht von:** nichts
- **Ausbauen:** die drei Dateien unter `data/push/browserfenster*`, die
  drei Provider und die Verzweigung in der Hülle entfernen; `web` aus
  `pubspec.yaml`. Übrig bleibt das Banner von vorher.

## Plattformen

| Plattform | Verhalten |
|---|---|
| Chrome / Edge / Firefox (Desktop) | Systemmeldung im Hintergrund, Banner im Vordergrund |
| Safari (macOS) | wie oben, ab Safari 16 |
| Safari (iOS) | keine Systemmeldung; verpasste Meldungen kommen beim Zurückkommen |
| Android-App, Windows | unverändert — die stumme Fassung meldet „immer sichtbar" |

## Skalierung

Unkritisch. Eine Meldung je eintreffender Zeile, eine Liste im Speicher,
die sich beim Zurückkommen leert. Kein Serveraufruf, keine Tabelle.

## Umsetzungsstatus

Vollständig für den festgelegten Zweck.

Abgesichert durch `test/browser_benachrichtigungen_test.dart` (6 Tests:
alle drei Zweige, mehrere verpasste Meldungen werden gezählt statt
gestapelt, kein Banner ohne Inhalt, und ausdrücklich, dass die stumme
Fassung außerhalb des Browsers nichts ändert),
`test/web_hinweis_test.dart` (8 Tests auf die Verzweigung des Hinweises —
darunter der Fall „schon installiert und trotzdem keine Meldungen", in
dem zu schweigen ist, und dass zwei Hinweise getrennt weggewischt werden)
und `test/web_hinweis_karte_test.dart` (4 Tests auf die Karte selbst:
sichtbar angemeldet, still unangemeldet, Wegwischen landet im Browser,
Anleitung öffnet sich) — plus `flutter build web`, das das Interop
tatsächlich übersetzt.

Der Doppelgänger für alle drei liegt in `test/fake_browserfenster.dart`.

**Zwei der acht fassen keinen Doppelgänger an**, sondern das, was die
Weiche auf der jeweiligen Plattform wirklich baut — einer mit
`testOn: 'vm'`, einer mit `testOn: 'browser'`. Der Grund steht im Test:
Als es nur einen gab, behauptete er „die stumme Fassung schweigt" und
rief dafür `Browserfenster()`. Auf der VM stimmte das; im
Chrome-Lauf der CI baut derselbe Ausdruck die **echte** Fassung, und die
schweigt zu Recht nicht. Der Browserlauf hat damit keinen Codefehler
gefunden, sondern einen Denkfehler im Test — und wäre er nicht in der CI,
hätte niemand ihn gesehen ([Funktion 18](18-plattformen.md)).

**Was Tests hier nicht können:** die `Notification`-API selbst. Sie
braucht einen echten Browser und eine erteilte Erlaubnis. Geprüft ist die
Verzweigung — also die Stelle, an der Fehler entstehen; die API dahinter
ist ein Aufruf ohne Logik.

## Umsetzungsplan

1. ~~Untersuchung: warum Firebase im Browser nicht geht~~ — erledigt
2. ~~Zuschnitt durch den Menschen: nur bei geöffneter Web-App~~ — erledigt
3. ~~Weiche, Provider, Verzweigung, Erlaubnis-Knopf~~ — erledigt
4. **Am lebenden Objekt prüfen** — offen, geht erst nach der
   Veröffentlichung: Desktop-Browser (Erlaubnis erteilen, Tab wechseln,
   Beacon vom zweiten Gerät) und iPhone (verpasste Meldungen beim
   Zurückkommen)
5. Später, falls gewünscht: Tab geschlossen — dann eigenes Web-Push, mit
   den Kosten aus dem Abschnitt oben

## Offene Punkte / Ideen

- ~~Ein Hinweis beim ersten Anmelden im Browser, dass es den Knopf gibt~~
  — erledigt 2026-09-06: die Karte auf der Startseite (siehe oben)
- ~~Die Glocke hat keinen eigenen Bildschirm~~ — erledigt in 0.10.12
  ([Funktion 29](29-push-benachrichtigungen.md)). Für den Fall „Tab war
  zu" ist sie die eigentliche Antwort, nicht Push: Was währenddessen
  ankam, steht beim nächsten Öffnen in der Liste
- ~~„Zum Home-Bildschirm hinzufügen" gehört ins iOS-Onboarding~~ —
  erledigt 2026-09-06. Ein eigenes Onboarding gibt es nicht und brauchte
  es nicht: Der Hinweis erscheint dort, wo er hingehört — auf der
  Startseite, ausgelöst vom **fehlenden `Notification`**, nicht von einer
  Browserkennung. Das `manifest.json` war längst richtig (`standalone`);
  gefehlt hat nur der Satz, dass es die Möglichkeit gibt
