# 01 Konto & Anmeldung

> **Status:** 🟢 fertig — Google und E-Mail funktionieren, Konto ist
> in-App löschbar, Daten kehren nach Neuanmeldung zurück.
> **Seit:** 0.9.2 (Kontopflicht) · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Ein Konto ist kein Selbstzweck — es existiert, damit Freunde, Feed und
Beacons überhaupt möglich sind und damit ein Gerätewechsel nicht alles
löscht. Deshalb: so wenig Anmeldung wie nötig, ein Klick wenn möglich,
und ein ehrlicher Weg wieder hinaus.

## Funktion (Nutzersicht)

- Anmeldung per Google (ein Tipp) oder E-Mail und Passwort — ohne
  Bestätigungsmail, weil die Hürde sonst die Hälfte der Interessierten
  kostet
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
  `core/supabase_config.dart`
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

## Plattformen

Alle. Google-Login braucht je Plattform eigene Client-IDs; eingerichtet
sind Android und Web.

## Skalierung

Unkritisch — Supabase Auth trägt das. Der Trigger beim Anlegen macht
höchstens fünf Einfügeversuche für den Nutzernamen (0019).

## Umsetzungsstatus

Vollständig. Offen ist nur die Selbstbedienung beim Nutzernamen: Er wird
einmal abgeleitet und kann danach nicht geändert werden.

## Umsetzungsplan

1. Nutzernamen ändern können (einmal je Zeitraum, Eindeutigkeit geprüft)
2. Passwort zurücksetzen prüfen — der Weg existiert bei Supabase, ist in
   der App aber nicht angeboten

## Offene Punkte / Ideen

- Apple-Anmeldung, sobald iOS ernsthaft ansteht (App-Store-Pflicht, wenn
  Google-Login angeboten wird)
- Die Redirect-URLs in Supabase müssen für neue Plattformen ergänzt werden
