# 08 Freunde

> **Status:** 🟢 fertig — Anfragen, Suche, QR-Codes, Blockieren und
> abgestufte Sichtbarkeit.
> **Seit:** 0.9.2 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ohne Freunde ist BrewMates ein Tagebuch. Mit ihnen wird es das, wofür es
gebaut ist: ein Weg, sich auf ein Bier zu verabreden. Der Aufbau der
Freundesliste ist deshalb die wichtigste Hürde der ganzen App — was hier
klemmt, kostet den gesamten sozialen Teil.

## Funktion (Nutzersicht)

- Suche nach Nutzername **oder** Anzeigename (ab 3 Zeichen)
- Anfrage stellen, annehmen, ablehnen
- Freundesliste mit Zugang zu Crews
- Blockieren: der andere verschwindet vollständig und kann nichts mehr
  sehen
- Melden mit Begründung, Bearbeitung durch Moderatoren

## Technische Umsetzung

- **Dateien:** `features/friends/friends_screen.dart`,
  `data/online/online_service.dart` (Abschnitt „Freunde")
- **Server:** `friendships` (0001) mit `status`, eindeutig je Paar;
  `blocks` und `reports` (0009)
- **Sicherheit:** `are_friends()` ist die Grundlage aller
  Sichtbarkeitsregeln; wer blockiert hat, ist für den anderen unsichtbar —
  umgekehrt bleibt die eigene Blockliste einsehbar, sonst ließe sie sich
  nicht verwalten
- **Suche skaliert** (0027, 2026-08-15): `pg_trgm`-GIN-Indizes auf
  `username` und `display_name`. Die Suche fragt `ilike 'begriff%'` und
  `ilike '%begriff%'` ab — beides kann ein B-Tree nicht bedienen, Postgres
  las bisher bei **jedem Tastendruck** die ganze Tabelle. Bei zwei
  Profilen unmessbar; das ist der Grund, warum es niemandem auffiel, kein
  Gegenargument. Die Erweiterung liegt im Schema `extensions`, nicht in
  `public` — der Advisor-Befund zu Erweiterungen in `public` (PostGIS)
  muss nicht wachsen.
- **Fehlschläge werden gemeldet** (2026-08-15, Backlog A-8): Anfrage
  annehmen/ablehnen und Blockierung aufheben schluckten Fehler und zeigten
  trotzdem Erfolg. Beides sind Entscheidungen über Sichtbarkeit — wer
  glaubt, abgelehnt oder entsperrt zu haben, richtet sein Verhalten danach.
  Schlägt der Aufruf fehl, bleibt die Liste jetzt auf dem Stand des
  Servers stehen (kein Invalidieren) und sagt es.

**Zwei Fallen, beide behoben:** Die Suche verglich lange nur den
Nutzernamen, während neue Konten automatisch `mate_<hex>` hießen — neue
Nutzer waren über ihren echten Namen unauffindbar. Und sie fing ihre
Fehler still ab: Ohne Anmeldung meldete sie „keine Treffer" statt „nicht
angemeldet". Seit 0.9.13 sucht sie auch über den Anzeigenamen, und
Migration 0019 vergibt sprechende Nutzernamen.

### Anfragen auf der Startseite (2026-08-15)

Offene Freundschaftsanfragen standen nur im Freunde-Bildschirm. Wer dort
nicht hinsah, ließ jemanden wochenlang warten — und eine Anfrage ist die
einzige Stelle der App, an der ein anderer Mensch auf eine **Antwort**
wartet. Sie gehört dorthin, wo man ohnehin hinschaut.

Drei Antworten, und sie sind bewusst nicht gleichwertig:

| | |
|---|---|
| **Annehmen** / **Ablehnen** | endgültig, geht sofort an den Server |
| **Später** | nur diese Sitzung, nur die Startseite — **keine** Antwort |

„Später" darf nichts an den Server melden. Eine Schaltfläche, die
aussieht wie „nicht jetzt" und wirkt wie „abgelehnt", wäre die
gefährlichste der drei; ein Test hält deshalb fest, dass dabei **kein**
Aufruf erfolgt.

Im Freunde-Bildschirm bleibt jede Anfrage sichtbar und änderbar, auch die
zurückgestellten.

### Der QR-Code stellte keine Anfrage (2026-08-16)

Ein Scan endete beim **Anzeigen** des Profils und wartete auf einen
zweiten Tipp auf „Freundschaft anfragen". Für den Menschen davor sah das
aus wie eine reine Suche: Er sah den Namen, steckte das Telefon ein — und
beim anderen kam nie etwas an. Wer einen fremden QR-Code scannt, will
genau dieses eine; der Scan **ist** die Absicht.

Jetzt geht die Anfrage mit dem Scan raus. Damit trägt das Präfix
`brewmates:friend:` die volle Last: Ohne die Prüfung würde jeder
WLAN- oder Speisekarten-Code eine Anfrage auslösen, und zwar ohne
Rückfrage. Ein Test hält das fest.

### Gestellte Anfragen waren unsichtbar

Wer jemanden angefragt hatte, sah davon **nichts mehr** — nicht in der
Suche, nicht in der Freundesliste. Ein zweiter Versuch lief in „Anfrage
läuft schon", ohne dass je erkennbar war, dass man selbst der Absender
ist. Zurücknehmen ging gar nicht: Ein Fehlgriff war endgültig, und man
konnte nur hoffen, dass der andere ablehnt.

Neu: `outgoingRequests()` und `withdrawRequest()`, eine Liste „Von dir
angefragt" mit „Zurücknehmen", und dieselbe Rücknahme direkt nach dem
Scan. Die Zeile wird **gelöscht** statt auf einen Status gesetzt — sonst
ließe der Unique-Index auf dem Paar keine neue Anfrage mehr zu.

### Offene Anfragen sind jetzt von überall sichtbar

Eine Zahl am Profil-Tab. Vorher standen Anfragen nur auf der Startseite;
wer die App auf einem anderen Tab offen hatte, sah nie, dass jemand auf
eine Antwort wartet.

### Eingehende Anfragen waren zweieinhalb Wochen unsichtbar (2026-09-02)

Vom 2026-08-15 bis zum 2026-09-02 zeigte die App **keine einzige**
eingehende Anfrage, keine Freundesliste und keine Blockierliste — obwohl
Senden funktionierte und die Pushes ankamen. Ursache: sechs
Select-Strings interpolierten `$OnlineApi.profileCols` statt
`${OnlineApi.profileCols}`. Dart setzt dann den **Klassennamen** ein und
hängt `.profileCols` als Text an; der Server bekam wörtlich
`OnlineApi.profileCols` als Spaltenliste und antwortete 400. Der Client
fing den Fehler mit `catch (_) => []` und zeigte „keine Anfragen".

Gefunden über die API-Logs (400 auf `/rest/v1/friendships`), nicht über
Tests: Die Widget-Tests laufen gegen eine Attrappe, die die Zeichenkette
nie an einen Server schickt. Deshalb jetzt `select_interpolation_test.dart`
— er liest die Quelltexte und lehnt `'…$Klasse.feld…'` in Zeichenketten
ab (Köder-Datei geprüft: wird erkannt). Und `incomingRequests` loggt
seinen Fehler, statt ihn zu schlucken.

Das ist der vierte Fall des immer gleichen Musters in diesem Projekt: eine
Sache, die aussieht, als wirke sie, und nichts tut.

### Die Glocke: Benachrichtigungen aus der Datenbank (0031, 2026-08-16)

`notifications` gab es seit 0001 als „Quelle der Wahrheit für die
In-App-Glocke" — beschrieben hat sie nie jemand. Jetzt füllt ein
**Trigger** auf `friendships` sie: Anfrage → `friend_request` an den
Empfänger; Annahme → `friend_accepted` an den Absender, die offene
Anfrage verschwindet; Zeile gelöscht (Ablehnen, Zurücknehmen) → alles
dazu verschwindet. In der Datenbank und nicht im Client, weil ein Client
vergessen, abstürzen oder alt sein kann.

Der Client **liest** nur (`NotificationsApi`): live über Realtime
(`incoming()`, Tabelle ist in der Publikation, RLS gilt) und als Bestand
(`unread()`). Kommt eine Zeile an, entwertet `incomingNotificationsProvider`
die betroffenen Listen und die Shell zeigt ein Banner mit „Ansehen" —
auf **jedem** Tab. Fällt Realtime aus, lädt der 30-Sekunden-Takt weiter;
nichts hängt am Live-Kanal. pgTAP prüft: Absender bekommt nichts,
Unbeteiligte sehen nichts, direktes Einfügen ist gesperrt, Zurücknehmen
räumt die Glocke.

### Was weiterhin fehlt: eine Meldung bei geschlossener App

Realtime wirkt nur, solange die App läuft. Seit 0.10.4 hängt der
[Push](29-push-benachrichtigungen.md) an genau dieser Tabelle — jede
neue Zeile ist ein Anlass.

Echte Meldungen brauchen Firebase Cloud Messaging: ein Firebase-Projekt,
`google-services.json`, ein Gerätetoken je Installation und eine
Edge Function, die über die FCM-HTTP-v1-Schnittstelle sendet. Der
Projektschlüssel ist der Teil, der nicht aus dem Repo kommen kann.

## Modularität

- **Hängt ab von:** Konto (01)
- **Wird gebraucht von:** Feed, Karte, Sessions, Crews — praktisch alles
  Soziale
- **Ausbauen:** nicht sinnvoll ohne Verlust des Produktkerns.

## Plattformen

Alle.

## Skalierung

Die Suche über den Anzeigenamen nutzt `ilike '%begriff%'` und kann damit
keinen normalen Index verwenden. Bei wenigen tausend Profilen wird das
langsam; die Lösung ist `pg_trgm` mit GIN-Index — bekannt, noch nicht
nötig.

Die Freundesliste selbst ist durch die menschliche Freundeszahl begrenzt.

## Umsetzungsstatus

Vollständig. Seit 0.10 gibt es die Abstufung in drei
[Freundeskreise](24-freundeskreise.md) — vorher sah jeder Freund alles,
was für eine App, die Standort und Trinkverhalten zeigt, zu grob war.

~~Zweite Lücke: Freundschaften entstehen nur über die Namenssuche.~~ Seit
0.9.14 gibt es [QR-Codes](22-freunde-per-qr-code.md) — den Weg für den
Wirtshaustisch, an dem die Namenssuche am schlechtesten funktioniert.

## Umsetzungsplan

1. ~~[Freunde per QR-Code](22-freunde-per-qr-code.md)~~ — erledigt (0.9.14)
2. ~~[Freundeskreise](24-freundeskreise.md) — löst die Abstufung~~ — erledigt (0.10)
3. Trigram-Index, sobald die Suche spürbar langsamer wird

## Offene Punkte / Ideen

- Vorschläge („ihr wart dreimal in derselben Session")
- Freundschaften aus dem Adressbuch — datenschutzrechtlich heikel, eher
  nicht
