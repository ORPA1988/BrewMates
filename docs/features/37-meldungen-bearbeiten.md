# 37 Meldungen bearbeiten (Moderation)

> **Status:** 🟢 fertig für den Zweck „ansehen und beantworten" — ohne
> Maßnahmen gegen den Gemeldeten (bewusst, siehe unten).
> **Seit:** 0.10.11-beta (Migration 0040) · **Zuletzt geprüft:** 2026-09-03

## Zielsetzung

Melden gibt es seit 0009. Bearbeiten nicht.

Die Zeile landete in `reports`, der Meldende sah sie in seiner eigenen
Liste — und danach passierte nichts. Lesen durfte sie außer ihm nur ein
Admin, und auch der hatte keine Oberfläche dafür. **Eine Meldung, die
niemand ansieht, ist ein Versprechen, das die App nicht hält.** Wer eine
Belästigung meldet und nie eine Reaktion sieht, meldet kein zweites Mal.

Woran man merkt, dass es funktioniert: Der Stapel „Offen" ist leer, und
zu jeder abgeschlossenen Meldung steht, wer sie wann mit welchem Befund
geschlossen hat.

## Funktion (Nutzersicht)

**Für alle:** unverändert. Melden geht wie bisher im Freunde-Bildschirm
beim jeweiligen Profil.

**Für Moderatoren (Vertrauensstufe 4) und Admins (5):**

1. Einstieg über „Meldungen bearbeiten" — im Konto-Bildschirm, bei Admins
   zusätzlich als Karte im Admin-Bereich mit der Zahl der offenen
   Meldungen
2. Vier Stapel: **Offen · Erledigt · Verworfen · Alle**
3. Je Meldung: Art (Profil, Check-in, Kommentar, Runde), wer gemeldet
   wurde, wer gemeldet hat, der Grund im Wortlaut und wie lange es her ist
4. Zwei Wege hinaus: **Erledigen** (etwas wurde unternommen) oder
   **Verwerfen** (nichts zu tun). Beide fragen nach einem kurzen Befund —
   freiwillig im Text, nicht im Schritt
5. Abgeschlossenes lässt sich **wieder öffnen**; Bearbeiter und Zeitpunkt
   werden dabei zurückgesetzt, denn „offen" heißt: noch niemand hat es
   abgeschlossen

Sonderfälle:

- **Ohne Rolle** steht „Nur für Moderatoren" mit dem Hinweis, dass Melden
  jedem offensteht. Ein leerer Bildschirm wäre die schlechtere Antwort:
  Er sieht aus wie „keine Meldungen" und ist in Wahrheit „nicht für dich".
- **Ohne Verbindung** bleibt die Liste leer und ein Abschließen meldet
  ehrlich „Hat nicht geklappt" (Regel A-8). Wer glaubt, eine Meldung
  bearbeitet zu haben, sieht nicht mehr nach.
- **Der Befund ist nur für Moderatoren sichtbar** — weder für den
  Meldenden noch für den Gemeldeten. Das steht auch im Dialog.

## Technische Umsetzung

- **Server:** `supabase/migrations/0040_moderation.sql`
  - `is_moderator(uid)` — dieselbe Bauart wie `is_admin` (0006): Die
    Funktion beantwortet nur die Frage nach dem Aufrufer selbst. Ein „ist
    X Moderator?" über andere wäre eine Auskunft über Fremde
  - `reports` bekommt `handled_by`, `handled_at`, `note` (+ Index auf dem
    neuen Fremdschlüssel, Regel aus 0036)
  - `reports_select` / `reports_update` gelten jetzt für Moderatoren,
    nicht nur für Admins
  - RPC `moderation_reports(status)` und `resolve_report(id, status, note)`
- **App:** `data/online/api/moderation_api.dart`,
  `data/providers/moderation.dart`,
  `features/moderation/moderation_screen.dart`, Route `/moderation`
- **Modell:** `ModerationReport` in `data/online/models.dart`

### Warum eine RPC und nicht ein breiteres Leserecht auf `profiles`

Die Liste braucht **Namen**. Der bequeme Weg wäre, `profiles_select` um
„oder is_moderator" zu erweitern — damit könnte ein Moderator jedes
private Profil der App lesen, jederzeit, vollständig, ohne Anlass. **Ein
Dauerrecht für einen Einzelfall.**

`moderation_reports()` gibt stattdessen genau die Namen heraus, die an
einer Meldung hängen. Der pgTAP-Test hält beides fest: dass der Name des
privaten Profils in der Liste steht — und dass dasselbe Profil über
`profiles` weiterhin unsichtbar bleibt.

### Eigener Weg neben `/admin`

Moderatoren sind keine Admins. Im Admin-Bereich hängen Rollen und
Funktionen anderer Leute; wer Meldungen bearbeiten soll, braucht davon
nichts. Deshalb eine eigene Route mit eigener Prüfung.

### Sicherheit

Durchgesetzt wird die Regel am Server: RLS-Policy und beide RPCs prüfen
`is_moderator` selbst. Die Oberfläche **spiegelt** nur — wer sie umgeht,
bekommt eine leere Liste und ein `false` beim Abschließen.

## Modularität

- **Hängt ab von:** Konto (01), Vertrauensstufen (15), Freunde (08, dort
  wird gemeldet)
- **Wird gebraucht von:** nichts
- **Ausbauen:** Feature-Ordner, Route, `moderation_api.dart` und
  `providers/moderation.dart` löschen, die beiden Einstiege entfernen. Am
  Server können Spalten und Funktionen stehen bleiben; die alten
  Admin-Policies aus 0009 wiederherzustellen wäre eine Migration.

## Plattformen

Android · Web · Windows · iOS · macOS — überall gleich, reines Flutter
ohne plattformgebundenes Paket.

## Skalierung

`moderation_reports` liefert höchstens 200 Zeilen, sortiert nach Datum,
gedeckt vom Index `reports_open_idx` (0009). Bei mehr Meldungen als das
braucht die Liste Seitenladen — dann aber auch ein zweiter Moderator.
Der Zähler der offenen Meldungen ist eine zweite Abfrage; bewusst nicht
aus der Liste abgeleitet, weil die den gerade gewählten Stapel zeigt und
ein Zähler, der sich beim Umschalten eines Filters ändert, kein Zähler
ist.

## Umsetzungsstatus

Vollständig für den Zweck „ansehen und beantworten".

**Was bewusst fehlt:** jede Handhabe gegen den Gemeldeten — kein Sperren,
kein Löschen, kein Verstecken. Der Grund ist nicht Zurückhaltung, sondern
Reihenfolge: Erst muss jemand die Meldungen überhaupt sehen und
beantworten können. Welche Maßnahmen es braucht, zeigt der erste echte
Fall; heute gibt es keinen einzigen. **Eine Maßnahme auf Vorrat wäre eine
Vermutung mit Löschrechten.** Was es schon gibt, reicht für den Anfang:
Blockieren kann jeder selbst (0009), und ein Admin kann `edit_lock`
setzen.

Abgesichert durch `supabase/tests/moderation.test.sql` (13 Prüfungen:
Unbeteiligte sehen nichts, der Meldende nur seine eigene Zeile, der
Moderator die Liste samt Namen des privaten Profils — bei weiterhin
unsichtbarem Profil; Abschließen hinterlässt Bearbeiter, Zeitpunkt und
Befund) und `app/test/moderation_test.dart` (6 Widget-Tests).

## Umsetzungsplan

1. ~~Rolle, Spalten, Policies, RPCs~~ — erledigt (0040)
2. ~~Liste, Stapel, Abschließen mit Befund~~ — erledigt
3. Offen: **Benachrichtigung an den Meldenden**, wenn seine Meldung
   abgeschlossen wird. Der Weg dafür steht (0031/0033), es fehlt der
   Trigger und die Entscheidung, wie viel der Befund verraten darf
4. Offen: **Maßnahmen** — sobald ein echter Fall zeigt, welche

## Offene Punkte / Ideen

- Ein Sprung von der Meldung zum gemeldeten Inhalt (`subject_id` zeigt
  schon dorthin, die Oberfläche nutzt es noch nicht)
- Mehrfachmeldungen desselben Profils zusammenfassen — heute stehen sie
  einzeln untereinander
