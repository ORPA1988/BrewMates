# 01 Konto & Anmeldung

> **Status:** 🟢 fertig — Google und E-Mail funktionieren, Konto ist
> in-App löschbar, Daten kehren nach Neuanmeldung zurück. Weitere
> Anmeldewege (Apple, Microsoft, Facebook, Discord, GitHub) sind in der
> App fertig und warten je auf ihre Einrichtung beim Anbieter.
> **Seit:** 0.9.2 (Kontopflicht); weitere Anbieter 0.10.13 ·
> **Zuletzt geprüft:** 2026-09-04

## Zielsetzung

Ein Konto ist kein Selbstzweck — es existiert, damit Freunde, Feed und
Beacons überhaupt möglich sind und damit ein Gerätewechsel nicht alles
löscht. Deshalb: so wenig Anmeldung wie nötig, ein Klick wenn möglich,
und ein ehrlicher Weg wieder hinaus.

## Funktion (Nutzersicht)

- Anmeldung per Google (ein Tipp) oder E-Mail und Passwort — ohne
  Bestätigungsmail, weil die Hürde sonst die Hälfte der Interessierten
  kostet
- **Weitere Anbieter erscheinen, sobald sie eingerichtet sind** — Apple,
  Microsoft, Facebook, Discord, GitHub. Der Anmeldebildschirm zeigt
  ausschließlich Knöpfe, die auch funktionieren
- Einmal anmelden, dauerhaft eingeloggt
- Nach der Anmeldung holt die Wiederherstellung eigene Check-ins,
  Abzeichen und Wunschliste zurück
- Nutzername wird aus dem echten Namen abgeleitet (seit 0019), Anzeigename
  und Emoji sind änderbar
- **Konto löschen** im Kontobereich: doppelte Rückfrage, dann werden alle
  Daten serverseitig entfernt (Play-Store-Pflicht)

## Technische Umsetzung

- **Dateien:** `features/account/account_screen.dart`,
  `data/online/online_service.dart` (Abschnitt „Auth"),
  `core/anmeldeverfahren.dart` (welche Wege es gibt, rein Dart),
  `data/providers/anmeldung.dart`, `core/supabase_config.dart`
- **Server:** Supabase Auth; `profiles` (0001), Trigger
  `handle_new_user` (0004/0006/0019), RPC `delete_my_account` (0017)
- **Sicherheit:** RLS auf `profiles`; fremde Profile nur sichtbar, wenn
  nicht privat bzw. befreundet — und nie, wenn der andere blockiert hat
- **Web:** OAuth-Rücksprung über `Uri.base`, nativ über
  `de.brewmates.app://login-callback`

### Drei Lücken, geschlossen am 2026-09-02

- **Passwort vergessen** gab es nicht. Mit dem Beta-Gate hieß ein
  vergessenes Passwort: ausgesperrt, neues Konto, alle Freundschaften
  weg. Jetzt ein Link unter dem Passwortfeld (`resetPasswordForEmail`,
  Rückkehr über den bestehenden Deep-Link); die Antwort verrät nicht, ob
  die Adresse existiert. Dazu das Auge zum Anzeigen des Passworts.
- **„Profil bearbeiten" schrieb nur lokal.** Der Mensch änderte seinen
  Namen, die Startseite (liest den Server) zeigte weiter den alten, und
  Freunde sahen die Änderung nie. `updateProfile` schreibt jetzt auch
  `profiles` und sagt, ob der Server es hat.
- **„Alle Daten bleiben lokal auf deinem Gerät"** im Profil war falsch,
  seit Check-ins, Fotos, Erfolge und Wunschliste zum Konto
  synchronisiert werden. Der Satz sagt jetzt, was gilt: ohne Konto alles
  lokal, mit Konto sehen nur bestätigte Freunde die Check-ins. Die
  Versionsangabe daneben war hart „1.0.0" und kommt jetzt aus
  `AppConfig.appVersion`.

## Modularität

- **Hängt ab von:** nichts
- **Wird gebraucht von:** allem Online-Verhalten — Freunde, Feed, Crews,
  Sessions, Synchronisation
- **Ausbauen:** nicht sinnvoll. Die App funktioniert zwar abgemeldet
  (local-first), aber das Konto ist die Grundlage aller sozialen
  Funktionen.

### Warum die Liste der Anmeldewege vom Server kommt

Ein zweiter Anmeldeweg ist nicht mit einem Knopf getan. Jeder Anbieter
braucht am Server ein eingerichtetes Konto — Client-ID, Geheimnis,
hinterlegte Rück-URL —, und einrichten kann das nur ein Mensch beim
Anbieter selbst. Fehlt es, antwortet Supabase mit „provider is not
enabled".

Stünde die Liste im App-Code, hätte jede ausgelieferte Fassung genau die
Knöpfe, die beim Bauen bekannt waren: entweder Knöpfe für Anbieter, die es
noch nicht gibt, oder keinen Knopf für den, der inzwischen da ist. Beides
ist falsch, und **das erste ist schlimmer** — wer sich nicht anmelden
kann, kommt nicht wieder.

Deshalb steht in `app_config.auth_providers` (0046), was wirklich
eingerichtet ist; die App zeigt genau das. Ein freigeschalteter Anbieter
erscheint damit **ohne neues Release**, auch auf Geräten, die nie wieder
aktualisiert werden. Dieselbe Stelle und dieselbe Begründung wie beim
Riegel (0029) und beim Testphasen-Schalter (0037).

**E-Mail und Passwort stehen bewusst nicht in der Liste.** Das ist kein
OAuth-Weg, braucht keine Freischaltung und ist immer da — ein Schalter
dafür wäre einer, mit dem man sich selbst aussperrt.

**Kein Anbieterlogo auf den Knöpfen.** Apple und Facebook haben ein
Material-Symbol, die übrigen tragen ihren Anfangsbuchstaben. Zur Laufzeit
lädt die App nichts von fremden Servern (Leitplanke aus `docs/11`), und
ein Markenlogo mitzuliefern brauchte die Erlaubnis des Markeninhabers.

## Plattformen

Alle. Jeder OAuth-Anbieter braucht je Plattform eigene Client-IDs und die
hinterlegte Rück-URL; für Google sind Android und Web eingerichtet.

## Skalierung

Unkritisch — Supabase Auth trägt das. Der Trigger beim Anlegen macht
höchstens fünf Einfügeversuche für den Nutzernamen (0019).

## Umsetzungsstatus

In der App vollständig. Was fehlt, fehlt **außerhalb** des Codes: Jeder
weitere Anbieter braucht ein Konto bei ihm und einen Eintrag im
Supabase-Dashboard. Bei **Apple** kostet das die Mitgliedschaft im Apple
Developer Program (99 $/Jahr) — ohne die geht es nicht, mit Programmieren
ist da nichts zu machen. Facebook verlangt zusätzlich eine App-Prüfung
für die Berechtigung `email`; Microsoft, Discord und GitHub sind
kostenlos und in Minuten erledigt.

Abgesichert durch `test/anmeldeverfahren_test.dart` (6 Tests: Reihenfolge
bleibt die des Servers, unbekannter Anbieter wird übergangen statt alles
mitzureißen, `azure` ≠ `microsoft`) und
`supabase/tests/auth_providers.test.sql` (4 Prüfungen, darunter die
wichtigste: ohne Anmeldung lesbar).

Offen bleibt die Selbstbedienung beim Nutzernamen: Er wird einmal
abgeleitet und kann danach nicht geändert werden.

## Umsetzungsplan

1. ~~Weitere Anmeldewege in der App~~ — erledigt in 0.10.13 (0046)
2. Einrichtung je Anbieter im Dashboard — Schritte in
   `docs/07-release-playbook.md`
3. Nutzernamen ändern können (einmal je Zeitraum, Eindeutigkeit geprüft)

## Offene Punkte / Ideen

- **Apple ist Pflicht, sobald es eine iOS-Fassung gibt** und dort ein
  anderer Fremdanbieter angeboten wird — App-Store-Regel, nicht unsere
  Entscheidung. Auf Android und im Web ist Apple freiwillig
- Magic Link (Anmeldung per E-Mail-Link statt Passwort) wäre der einzige
  weitere Weg, der überhaupt kein fremdes Konto braucht — hängt aber am
  E-Mail-Versand: Der eingebaute SMTP von Supabase ist auf wenige
  Nachrichten je Stunde gedeckelt und für echten Betrieb nicht gedacht
- Die Redirect-URLs in Supabase müssen für neue Plattformen ergänzt werden
