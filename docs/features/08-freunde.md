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

**Zwei Fallen, beide behoben:** Die Suche verglich lange nur den
Nutzernamen, während neue Konten automatisch `mate_<hex>` hießen — neue
Nutzer waren über ihren echten Namen unauffindbar. Und sie fing ihre
Fehler still ab: Ohne Anmeldung meldete sie „keine Treffer" statt „nicht
angemeldet". Seit 0.9.13 sucht sie auch über den Anzeigenamen, und
Migration 0019 vergibt sprechende Nutzernamen.

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
