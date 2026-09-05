# 13 — Migrationen & Lehren

> **Zweck:** Das Gedächtnis des Backends. Was am Server steht, warum es so
> steht — und die Fehler, die dabei Geld gekostet haben.
> **Zuletzt geprüft:** 2026-09-04 (gegen die Datenbank, nicht gegen diese Datei)

Dieses Dokument stand bis 2026-09-04 in `CLAUDE.md` und hatte es auf 283
Zeilen gebracht — zwei Drittel der Datei, die jede Sitzung als erstes
liest. Damit war die Anleitung in ihrer eigenen Geschichte begraben, und
die Geschichte veraltete unbemerkt.

Jetzt gilt die Arbeitsteilung: **`CLAUDE.md` sagt, was zu tun ist.
Dieses Dokument sagt, was war und was man daraus gelernt hat.**

---

## Teil 1 — Die Lehren

Vier Fehler, die sich wiederholen können. Sie stehen vorn, weil sie mehr
wert sind als jede Migrationsnummer.

### 1. Eine Datei, die einen Vorbehalt behauptet, ist kein Beleg für ihn

`0026` sollte die Spalte `profiles.thirsty_until` vor fremden Blicken
verbergen. Monatelang stand in `CLAUDE.md`, sie sei „bewusst NICHT
eingespielt und wartet". **Der Rechtestand widersprach dem seit dem
ersten Tag:** Tabellenrecht entzogen, `thirsty_until` nicht gewährt,
22 Einzelspalten gewährt — die Migration war längst gelaufen.

Aufgefallen erst, als ein Rollout anstand und jemand nachsah.

> **Wer plant, ob eine Migration laufen darf, fragt die Datenbank —
> `information_schema.table_privileges` und `column_privileges` —, nicht
> einen Absatz.** Ein Vorbehalt, den man für aktiv hält, obwohl er längst
> gefallen ist, ist gefährlicher als gar keiner: Man baut die nächste
> Entscheidung darauf.

Die Abfragen dafür stehen in [`CLAUDE.md`](../CLAUDE.md) unter „Prüfen
statt glauben".

### 2. Rechte prüft man in der Rolle, die sie betrifft

`0041` erzeugte den Crew-Beitrittscode per **Spaltenvorgabe**
(`default neuer_crew_code()`). Eine Spaltenvorgabe wird aber **mit den
Rechten des Einfügenden** ausgewertet, nicht mit denen des Besitzers. Die
Funktion war für `authenticated` gesperrt — „Crew gründen" scheiterte für
**alle** mit `permission denied for function neuer_crew_code`, auch in der
veröffentlichten 0.10.11.

Warum es durchrutschte: Die Live-Probe legte die Wegwerf-Crew als
`postgres` an, und der darf die Funktion rufen. Geprüft war, dass der
Code richtig *aussieht* — nicht, dass ihn der richtige Rolleninhaber
bekommt.

> **Wer eine Regel prüft, die an Rechten hängt, prüft sie in der Rolle,
> die sie betrifft:** `set local role authenticated` +
> `request.jwt.claims`. Auch die MCP-Probe läuft als `postgres`, und
> `postgres` umgeht RLS.

Behoben in `0042` mit einem `before insert`-Trigger als SECURITY DEFINER
(Muster: `friendships_notify`).

### 3. `insert … returning` braucht auch die SELECT-Policy

`crews_select` verlangte eine Mitgliedschaft, die es beim Anlegen noch
gar nicht geben kann. Folge: **Crews ließen sich seit 0.9.12 überhaupt
nie anlegen** — und die null Crews in der Datenbank hatte ich als „noch
keine gegründet" gelesen.

> **Eine leere Tabelle ist eine Beobachtung, keine Erklärung.** Bevor man
> sie als „wird halt nicht genutzt" abtut: einmal in der richtigen Rolle
> versuchen, eine Zeile anzulegen.

Behoben in `0043`: Auch `owner_id = (select auth.uid())` sieht seine Crew.

### 4. Entziehen und Ersetzen gehören nie in dieselbe Migration

Zwei Teile, beide teuer erkauft:

- Eine Migration, die ein Recht **entzieht**, darf nicht dieselbe Datei
  sein wie die **Ersatzschnittstelle** — sonst gibt es kein Zeitfenster,
  in dem alter und neuer Client zugleich funktionieren.
- `revoke select (spalte)` ist **wirkungslos**, solange ein Recht auf
  Tabellenebene besteht. Postgres meldet „REVOKE" und lässt die Spalte
  lesbar. Wer eine Spalte verbergen will, entzieht das Tabellenrecht und
  gewährt alle übrigen Spalten einzeln — mit der Folge, dass jede neue
  Spalte auf `profiles` ihr `grant select (…)` mitbringen muss.

Dazu die kleine Schwester aus `0047`: Ein **Enum-Literal in einer
`language sql`-Funktion** wird beim Anlegen aufgelöst. Steht der neue Wert
drei Zeilen darüber im selben `alter type`, scheitert die Migration mit
`unsafe use of new value of enum type`. Über `k::text` verglichen stellt
sich die Frage nicht.

---

## Teil 2 — Die Migrationen

**`0001–0053` sind live, lückenlos** (Stand 2026-09-05). Die Nummern ohne
eigenen Abschnitt sind unauffällig: Sie haben getan, was ihr Name sagt.

| # | Name | Wofür |
|---|---|---|
| 0001 | initial_schema | Tabellen, Enums, RLS-Grundgerüst |
| 0002–0007 | seed_badges … active_users_count | Abzeichen, Mehrbenutzer, Kontomodell, erste Härtung, Rollen, Kartenzähler |
| 0008 | function_privileges | **EXECUTE wird von PUBLIC entzogen** und pro Funktion gewährt |
| 0009–0019 | blocking … username_from_name | Blockieren, Community-Biere, Gasthäuser, Challenges, Vertrauensstufen, Öffnungszeiten, Cloud-Sync, Kontolöschung, Bierlaune, sprechende Nutzernamen |
| 0020–0024 | feed_index … friend_tiers | Feed-Index, Beacon-Laufzeit 29 min–24 h, Füllmenge, Hintergrundgeschichten, **Freundeskreise** |
| 0025 | table_grants | Tabellenrechte — siehe unten |
| 0026 | thirsty_until_column_privilege | Bierlaune nur über `my_thirsty_until()` lesbar |
| 0027 | freundessuche_trigram | `pg_trgm`-GIN-Indizes für die Freundessuche |
| 0028–0032 | beer_barcodes … drop_beers_barcode | Mehrere EANs je Bier — siehe unten |
| 0029 | app_config | `min_supported_version` — der Riegel |
| 0033–0034 | notifications_push_webhook, notify_webhook_secret_rpc | Push über pg_net + Vault-Geheimnis |
| 0035 | security_hardening_2 | `anon` schreibt nie — siehe unten |
| 0036 | performance_policies_and_fk_indexes | `(select auth.uid())` in allen Policies, Indizes auf allen FKs |
| 0037 | feedback_roadmap_participant_notifications | Prost/„Bin dabei" erreichen den Gastgeber; Feedback + Roadmap |
| 0038 | feedback_github | Feedback als anonyme GitHub-Issues |
| 0039 | beacon_notifications | Beacon weckt genau die, die ihn sehen dürfen |
| 0040 | moderation | Moderatorenrechte, ohne `profiles_select` zu öffnen |
| 0041–0044 | crew_join_code … crew_invites | Crews vollständig — siehe unten |
| 0045 | rechte_reste | TRUNCATE entzogen — siehe unten |
| 0046 | auth_providers | Welche Anmeldewege die App zeigen darf |
| 0047 | beacon_zusagen | Zusagen **und Absagen** auf einen Beacon |
| 0048 | geplante_sessions_typ | Enum-Wert `planned`, Spalte `scheduled_for` |
| 0049 | geplante_sessions_regeln | Checks, `sessions_select` um Verabredungen erweitert, Aufräumen |
| 0050 | runden_checkins | Mitrundige sehen die Check-ins der Runde (`is_my_round`) |
| 0051 | checkin_crews | Welche Crews bei einem Check-in dabei waren — Momentaufnahme per Trigger |
| 0052 | checkin_crews_rechte | Entzieht, was 0051 nur behauptet hatte |
| 0053 | verabredung_erinnerungen | Zwei Meldungen zur Verabredung; Laufzeit-Constraint gilt nur noch für laufende Runden |

### 0025 — Tabellenrechte, oder: das Repo konnte das Projekt nicht wiederherstellen

Das Live-Projekt gab `anon` und `authenticated` volle DML-Rechte, begrenzt
allein über RLS. Diese Rechte standen aber in **keiner Migration** — sie
stammten aus Supabase-Default-Privileges, die nur greifen, wenn Tabellen
über den SQL-Editor entstehen.

Ein Aufbau allein aus `supabase/migrations/` wäre mit einer App
hochgekommen, die nichts lesen und nichts schreiben darf. Aufgefallen erst
beim ersten echten From-scratch-Aufbau für die RLS-Tests.

**Deshalb baut die CI die Datenbank bei jedem PR neu aus den Migrationen.**
Der Aufbauweg ist keine Theorie, er wird getestet.

### 0028–0032 — Eine EAN bezeichnet die Handelseinheit, nicht das Getränk

`beers.barcode` (eine Spalte, ein Code) passte nicht: Dasselbe Bier hat in
der Dose einen anderen Code als in der Flasche. `0028` legte
`beer_barcodes` an — **stellte aber die Lesestelle nicht um**. Ergebnis:
Nachgetragene Codes wurden gespeichert und beim Suchen ignoriert. `0030`
zog nach, `0032` entfernte die alte Spalte, nachdem der Riegel auf 0.10.4
stand.

Für Barcodes gibt es am Server nur noch eine Wahrheit: `beer_barcodes`.

### 0035 — `anon` schreibt nie

`anon` hatte INSERT/UPDATE/DELETE auf allen 30 Tabellen (Erbe der
Default-Privileges). RLS fing das immer ab — aber ein Recht, das nie
gebraucht wird, ist eine Tür, die niemand bewacht. Dazu: Bucket
`beer-photos` auf 5 MB und Bildtypen begrenzt, eigene Fotos löschbar.

### 0039 — Wer geweckt wird, ist dieselbe Frage wie: wer darf es sehen

Trigger `sessions_notify` schreibt beim Start eines Beacons
`notifications`-Zeilen an genau die, die ihn auch sehen dürfen —
**wortwörtlich die Bedingung aus `sessions_select`**. Eine Meldung über
eine Runde, die man beim Hintippen nicht sehen darf, wäre schlimmer als
gar keine.

Spam-Bremse: ein Wecken je Gastgeber und Stunde, **gemessen an
`sessions`**, nicht an `notifications` — die verschwinden beim Beenden,
sonst setzte „starten, beenden, starten" die Bremse zurück.

Der Trigger benutzt bewusst **nicht** `are_friends`/`is_crew_member`: Die
verlangen seit `0009` eine Beteiligung von `auth.uid()` und lieferten bei
einem Insert ohne Sitzung still `false`.

### 0041–0044 — Crews, und zwei Reparaturen

- **0041** `crews.join_code`: sechs Zeichen aus einem Alphabet ohne
  Zwillinge (kein 0/O, kein 1/I/L), Beitritt über `join_crew_by_code()`.
  Die Funktion ist nötig, weil `crews_select` nur die eigenen Crews zeigt
  — der Client kann „welche Crew hat Code X?" gar nicht fragen, und das
  bleibt so. Sie unterscheidet bewusst **nicht** zwischen „gibt es nicht"
  und „ging nicht"; alles Feinere wäre ein Ratewerkzeug für fremde
  Gruppennamen.
- **0042** und **0043**: die beiden Reparaturen aus Lehre 2 und 3.
- **0044** `crew_invites`: einladen darf nur ein **Mitglied** und nur einen
  **Freund** und nur im eigenen Namen. Sonst wäre die Einladung ein Weg,
  Fremden ungefragt etwas zu schicken.

### 0045 — TRUNCATE umgeht RLS

`anon` und `authenticated` hatten auf jeder Tabelle noch
`TRUNCATE, REFERENCES, TRIGGER` — Erbe der Supabase-Vorgaben, das `0035`
nicht mitgenommen hatte. **TRUNCATE fragt keine Policy.** Offen war es
nie (PostgREST bietet kein TRUNCATE, und keine der beiden Rollen hat einen
Datenbankzugang) — genau darum ist es durch zwei Sicherheits-Checks
gerutscht: keine offene Tür, nur ein Schlüssel bei jemandem, der ihn nicht
braucht.

**Dabei gefunden:** Die Default-Privileges gibt es **zweimal**, gesetzt von
`postgres` und von `supabase_admin`. Welche greift, entscheidet, **wer die
Tabelle anlegt**. Die von `supabase_admin` gewährt `anon` weiterhin volle
DML und ist als `postgres` nicht änderbar. Folgenlos, solange niemand als
`supabase_admin` Tabellen in `public` anlegt — aber `0035`s Satz „auch
nicht auf künftigen" reichte weiter als seine Wirkung.

### 0047 — Schweigen ist mehrdeutig

`participant_kind` heißt jetzt `joined | toast | declined`. Wer nicht
konnte, hatte vorher keinen Knopf — und damit fehlte dem Gastgeber die
halbe Information: „Drei haben zugesagt" heißt nichts, solange offen ist,
ob die anderen noch überlegen oder längst abgesagt haben.

Zusage und Absage schließen einander aus (der **Client** räumt die andere
Zeile weg, weil der Schlüssel `(session, profil, art)` sonst beide
stehen ließe); Prost steht daneben, denn „kann heute nicht, trink eins auf
mich" ist der häufigste Fall.

### 0048/0049 — Lehre 1 hat sich selbst bestätigt

Zwei Dateien statt einer, und der Grund ist eine Postgres-Eigenheit:
`alter type ... add value` legt den Wert an, aber **dieselbe Transaktion
darf ihn nicht mehr benutzen** („unsafe use of new value of enum type").
Jede Migrationsdatei ist eine Transaktion. `0047` hat dieselbe Klippe mit
`k::text` umschifft — dort richtig, weil es eine Funktion war, die je
Trigger einmal läuft. Hier wäre es falsch gewesen: Die Bedingung landet
in `sessions_select` und damit in **jeder** Abfrage, die die Karte alle
30 Sekunden stellt. Also `0048` legt an, `0049` benutzt.

**Der eigentliche Fund kam vorher.** Der Entwurf zu
[Funktion 39](features/39-geplante-sessions.md) nahm an,
`sessions_select` filtere nur nach Sichtbarkeit, und notierte das
ausdrücklich als *zu belegende Vermutung* — mit dem Hinweis, dass sie zu
überspringen genau Lehre 1 wäre. Die Probe kostete eine Abfrage und
ergab: **falsch.** Die Policy verlangte

```sql
status = 'active' and expires_at > now()
```

Eine Verabredung mit `status = 'planned'` wäre für **niemanden außer dem
Gastgeber** sichtbar gewesen. Auf der Annahme gebaut, wäre die Funktion
fertig geworden und hätte nichts getan — und die Suche hätte in der App
begonnen, während die Ursache hier saß. Dieselbe Form von Fehler wie
Lehre 1, nur eine Ebene tiefer: nicht ein Absatz, der einen Vorbehalt
behauptete, den es nicht gab, sondern ein Entwurf, der eine Bedingung
verschwieg, die es gab.

**Was dabei ausdrücklich richtig war**, ebenfalls geprüft statt
angenommen: `count_other_active_sessions` verlangt neben dem Status
`latitude is not null` — und eine geplante Session trägt per Constraint
keinen Ort. Der Kartenzähler brauchte deshalb keine Änderung. Dieselbe
Doppelbedingung, die `0024` aus einem anderen Grund eingeführt hat,
deckt diesen Fall mit ab.

**Und eine dritte Probe nach dem Einspielen:** `create or replace
function` behält die ACL. `end_expired_sessions()` ist weiterhin für
`anon` und `authenticated` gesperrt (`0005`) — nachgesehen, nicht
gehofft, denn ein Neuanlegen hätte die Rechte zurückgesetzt.

### 0050 — RLS gilt auch in der eigenen Unterabfrage

Der erste Entwurf prüfte die Rundenzugehörigkeit direkt in der Policy:
ein `exists` über `sessions` und `session_participants`. Die CI hat ihn
zerlegt — **sieben Gegenproben grün, ausgerechnet das Öffnen rot.**

`sessions` trägt selbst RLS. Die Unterabfrage lief als der fragende
Mensch, und der sieht die Runde eines Nicht-Freundes gar nicht
(`sessions_select` verlangt Freundschaft oder Crew). Also fand das
`exists` nichts: Die Regel sperrte einwandfrei und öffnete nie.

**Die Fehlerrichtung ist der eigentliche Punkt.** Ein
Sichtbarkeitsfehler, der zu **wenig** zeigt, fällt beim ersten Benutzen
auf. Einer, der zu **viel** zeigt, fällt vielleicht nie auf. Dass hier
die harmlose Richtung getroffen wurde, war Zufall der Konstruktion —
kein Verdienst. Deshalb prüft `runden_checkins.test.sql` beide
Richtungen, und die Gegenproben sind in der Überzahl.

Gelöst mit `is_my_round(session)` nach dem Muster von `are_friends`,
`is_crew_member` und `tier_for`. **Ohne Profil-Parameter**: Die Funktion
gibt nur über den Aufrufer Auskunft. Ein zweiter Parameter hätte sie zu
einem Auskunftsdienst über Dritte gemacht — genau der Maßstab, an dem
Teil 3 unten die übrigen Helfer misst.

**Dabei gefunden:** Der `crew`-Zweig in `checkins_select` greift seit
0001 **nie**. Er verlangt `visibility = 'crew'`, und die App schreibt
hart verdrahtet `'friends'`. Die Crew-Bilanz zeigte deshalb immer nur
Check-ins von Crew-Kollegen, mit denen man zusätzlich befreundet ist.
Stehen gelassen: Ihn zu entfernen wäre eine Entscheidung über die
Funktion, keine Aufräumarbeit — siehe Roadmap-Rang 3.

### 0051/0052 — zwei Regeln über nichts

**Erstens: `grant` entzieht nichts.** 0051 legte `checkin_crews` an und
schrieb als Kommentar dazu: „Kein insert/update/delete für irgendjemanden."
Nachgesehen nach dem Einspielen stand da:

    authenticated : DELETE, INSERT, SELECT, UPDATE
    anon          : SELECT

Aus den Default-Privileges, nicht aus einem `grant`. Dass trotzdem
niemand schreiben kann, liegt **allein** an RLS ohne Schreib-Policy. Es
war nie ein Loch — aber eine Sicherung, die anders zustande kommt als
der Kommentar sagt, ist eine, auf die sich der Nächste falsch verlässt:
Wer eine insert-Policy für „nur den Autor" ergänzt, gibt damit das
volle DML frei, weil das Tabellenrecht längst da ist. 0052 zieht die
`revoke`s nach, und der Test prüft jetzt **die Rechte**, nicht nur dass
ein Schreibversuch scheitert. Das sind zwei verschiedene Aussagen.

**Zweitens, und teurer: eine Server-Regel auf einem Feld, das der Client
nie füllt.** `uploadRow` in `data/online/api/checkins_api.dart` setzte
`'session_id': null` — hart verdrahtet, ohne Kommentar. Die Zuordnung
erreichte den Server also nie, auch die zur eigenen Runde nicht.

Damit war alles darüber wirkungslos: Die Crew-Bilanz jointe über
`sessions.crew_id` und fand nichts. Der Runden-Zweig aus 0050 hätte nie
gegriffen, weil `session_id is not null` nie zutraf. Beide hätten in
jedem pgTAP-Test bestanden — dort setzt der Test die Spalte ja selbst.

**Die Lehre:** Ein Server-Test belegt, dass die Regel richtig ist, wenn
die Daten so aussehen. Er belegt nicht, dass die Daten je so aussehen.
Wo eine Regel an einer Spalte hängt, die der Client füllt, gehört die
Frage dazu: **Füllt er sie überhaupt?** Diese eine Frage hätte hier drei
Migrationen früher gestellt gehört.

---

## Teil 3 — Was bewusst offen ist (Baseline)

Diese Befunde sind bekannt, geprüft und **kein Handlungsbedarf**. Neu
hinzukommende Funde sind an diesem Maßstab zu prüfen, **nicht pauschal
der Baseline zuzuschlagen**.

| Befund | Warum er bleibt |
|---|---|
| PostGIS im `public`-Schema (`spatial_ref_sys` ohne RLS, `st_estimatedextent` für `anon`) | Gehört `supabase_admin`; ein REVOKE als `postgres` läuft durch und ändert nichts (live geprüft 2026-09-02). Öffentliche Referenzdaten, keine Nutzerdaten |
| Default-Privileges von `supabase_admin` | Siehe 0045 — als `postgres` nicht änderbar, praktisch folgenlos |
| Leaked-Password-Protection aus | Braucht Supabase **Pro** (geprüft 2026-09-02) |
| E-Mail-Bestätigung aus | Bewusst, bis zur Play-Store-Veröffentlichung — die Hürde kostet sonst die Hälfte der Interessierten |
| Linter meldet **jede** SECURITY-DEFINER-Funktion für `authenticated` | Das sind sämtliche RPCs der App. Sie sind der Zugriffsweg, nicht das Leck. Geprüft ist, dass sie ihre Argumente selbst einschränken: `are_friends`/`has_blocked` beantworten nur Paare, an denen der Aufrufer beteiligt ist; `account_level` nur das eigene Konto oder das eines Admins |
| Performance-Advisor: `unused_index` (INFO) | Erwartbar bei einer fast leeren Datenbank |

---

## Teil 4 — Zwei Sitzungen auf einer Datenbank

Am 2026-09-03 hat eine zweite Sitzung parallel eine eigene Feedback-
Variante live eingespielt (`github_issue_number`, Trigger
`feedback_github_issue`, Function `feedback-to-github`). `0038` hat sie
idempotent abgeräumt; die Reste sind inzwischen weg.

> **Vor jedem Live-Eingriff:** `list_migrations` und `list_edge_functions`
> ansehen — **nicht nur das Repo**. Zwei Sitzungen auf einer Datenbank
> brauchen einen Menschen, der sagt, welche weitermacht.

Dasselbe gilt für das Arbeitsverzeichnis: Steht es auf einem fremden
Branch, arbeitet dort jemand anderes. Nicht committen, nicht stashen,
nicht wechseln — eigenen Klon oder Worktree von `origin/main` benutzen.
