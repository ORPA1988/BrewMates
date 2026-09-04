# 06 – Roadmap

> **Stand: 2026-09-04, Version 0.10.13-beta.**
> Diese Datei sagt **wann** etwas kommt und in welcher Reihenfolge.
> **Was** eine Funktion ist und wie sie gebaut ist, steht je Funktion in
> [docs/features/](features/README.md) — hier wird nur verlinkt, nicht
> wiederholt.

## Was als Nächstes ansteht

| Rang | Vorhaben | Warum jetzt |
|---|---|---|
| 1 | **[Geplante Sessions](features/39-geplante-sessions.md)** („Freitag 19 Uhr“) | Die Zu- und Absage gibt es seit 0.10.13 — es fehlt nur der Termin in der Zukunft. **Der Entwurf steht** (Funktion 39), Schritt 1 ist eine Rechteprobe von zwanzig Minuten |
| 2 | **Anmeldeverfahren freischalten** | Die App kann fünf weitere Anbieter; drei davon kosten nichts. Schritte im [Release-Playbook](07-release-playbook.md) |
| 3 | **[Crew-Challenges und Rollen](features/09-crews.md)** | Sinnvoll, sobald es mehr als eine aktive Crew gibt |
| 4 | **[Statistik: CSV-Export](features/20-feed-statistiken.md)** | Die Maschinerie steht seit 0.10.14, Reinalkohol ist entschieden und gebaut; der Export fällt aus der Trennung Auswahl/Aufteilung/Zahlen fast heraus |
| 5 | **[Play Store](https://github.com/ORPA1988/BrewMates/issues/67)** | Braucht Konto, Ausweisprüfung und Store-Prozess — Menschenarbeit |

---

Diese Roadmap ersetzt die Roadmap 1.0 vollständig. Sie stellt die App auf ihren
neuen Kern: Der Startbildschirm hat **zwei Hero-Aktionen** –

1. **🍺 Bier scannen** – Barcode/EAN scannen → Bier erkannt → direkt einchecken;
   unbekanntes Bier → in Sekunden anlegen (lokal sofort, Community-Vorschlag optional).
2. **🍻 Zusammenkommen!** – Ein-Tap-Beacon mit echtem GPS: Die Session startet
   sofort, Freunde sehen den Standort auf der Karte, Botschaft: **„Alle willkommen!"**

Alle Tagebuch-Funktionen (Check-ins, Bewertungen, Bier-Datenbank, Abzeichen,
Statistiken, Wunschliste) und alle Treffen-Funktionen (Beacon, Live-Karte,
Sessions) gruppieren sich um diese zwei Hauptfunktionen – sie sind Vertiefungen,
keine gleichrangigen Einstiege mehr.

Zeitschätzungen gelten für ein Team von **2–3 Entwicklern**; **mit
KI-Unterstützung deutlich schneller** (erfahrungsgemäß etwa halbe bis drittel Zeit).

> **Diese Roadmap sagt, wann etwas kommt.** Was eine Funktion ist, wie sie
> gebaut ist und wie weit sie steht, steht je Funktion in einem eigenen
> Dokument unter **[docs/features/](features/README.md)** — samt
> Zielsetzung, technischer Umsetzung, Plattformen, Skalierung und
> Umsetzungsplan. Der aktuelle Gesamtbefund zu allen bestehenden
> Funktionen steht im **[Funktionsaudit](12-funktionsaudit.md)**.

## Was sich gegenüber Roadmap 1.0 geändert hat

- **Hero-Aktionen statt Tab-zentriertem Einstieg**: Die alte Roadmap dachte die
  App von der Tab-Navigation her; jetzt führen zwei große Buttons auf dem
  Home-Screen direkt in die beiden Kern-Momente „Bier vor mir" und „Leute zu mir".
- **Android-Fokus**: Statt gleichzeitigem Android/iOS/Windows-Ausbau konzentriert
  sich die Entwicklung auf Android (iOS bleibt über die Flutter-Codebasis offen;
  Windows/macOS/Web sind Entwickler-Targets).
- **GitHub-Community-DB schon live**: Die redaktionelle österreichische
  Bier-/Brauerei-Datenbank inkl. Issue-Einreichung und App-Abgleich existiert
  bereits – sie ist kein Roadmap-Punkt mehr, sondern Fundament (siehe
  [docs/08](08-funktionsweise-fuer-alle.md)).
- **Windows-Store und Apple-Store zurückgestellt**: Verteilung läuft über
  GitHub Releases (APK), später zusätzlich Play Store. Microsoft Store und
  App Store sind auf unbestimmt verschoben.

---

## Stufe A — „Scan & Beacon" *(✅ abgeschlossen mit Beta 0.9)*

Ziel: Die zwei Hero-Aktionen funktionieren Ende-zu-Ende – komplett local-first,
ohne Konto, ohne Backend.

- [x] **Neuer Home-Screen** mit den zwei Hero-Buttons „🍺 Bier scannen" und
      „🍻 Zusammenkommen!"; Navigation: **Home, Feed, Karte, Entdecken, Profil**
- [x] **Barcode-Scanner** (`mobile_scanner`, EAN-8/EAN-13; manuelle
      EAN-Eingabe überall verfügbar und einziger Weg auf Desktop)
- [x] **Lookup-Kette**: lokale Bier-DB → Open Food Facts → vorausgefülltes
      Anlegen-Formular, wenn das Bier nirgends bekannt ist
- [x] **Echtes GPS** (`geolocator`) für Beacon & Sessions: Berechtigungs-Flow
      in `data/location_service.dart`, Fallback auf manuelle Venue-Wahl
- [x] **Barcodes in der Bier-DB** — kam bereits mit Schema v2 von
      `beers-at.json` (`barcodes`-Array), EAN-Feld im Issue-Formular existiert
- [x] **Releases als APK über GitHub Releases** — Workflow `release.yml` per
      workflow_dispatch; Versionierung läuft als Beta 0.9.x bis zum
      Play-Store-1.0 (die frühen Alpha-Releases wurden nachträglich von
      1.1/1.2 auf 0.1.0/0.2.0 umbenannt)

**Exit-Kriterium:** Ein gescanntes österreichisches Supermarkt-Bier landet in
unter 15 Sekunden als Check-in; der Beacon zeigt die echte eigene Position auf
der Karte. Standort bleibt dabei wie bisher rein lokal auf dem Gerät.

## Stufe B — v2.0 „Echte Freunde" *(Online, komplett auf Supabase; in Beta-Umsetzung — ca. 8–12 Wochen, mit KI-Unterstützung deutlich schneller)*

Ziel: Der Mehrspieler-Betrieb – echte Freunde statt Demo-Daten. **Wichtig:
unabhängig von jeder bestimmten Domain.** Datenschutz-URL und Download-Seite
laufen über GitHub (Pages/Releases); eine eigene Domain ist nice-to-have,
niemals Voraussetzung.

- [x] **Supabase-Projekt aktivieren** — erledigt mit der Beta 0.9: Schema
      liegt in `supabase/` (Migrationen 0001–0003), Server-Region EU,
      RLS-Policies scharf geschaltet
- [x] **Konten** — E-Mail + Passwort seit Beta 0.9 (Google/Apple-Login später);
      die App bleibt ohne Konto weiter voll als lokales Tagebuch nutzbar
- [x] **Migration lokale Daten → Konto**: automatischer Abgleich statt
      Einmal-Assistent — offline entstandene Check-ins überträgt die App
      selbstständig (bei Anmeldung, nach jedem Check-in, alle 5 Minuten
      als Retry; idempotent per Upsert, Demo-Daten bleiben lokal), der
      Konto-Screen zeigt den Sync-Status samt manuellem Anstoß. Abzeichen
      leiten sich aus Check-ins ab, die Wunschliste bleibt bewusst lokal,
      solange das Online-Schema keine denormalisierte Wunschliste kennt
- [x] **Echte Freundschaften** — seit Beta 0.9 per Nutzername-Suche (Anfrage,
      Bestätigung); QR-Code-Einladung später
- [x] **Live-Beacon über Geräte hinweg** (Supabase Realtime): Freunde sehen die
      Session in Sekunden auf ihrer Karte — seit Beta 0.9
- [ ] **Push-Benachrichtigungen** (FCM): „Anna hat eine Session gestartet – alle
      willkommen!"
- [x] **Aggregierte echte Community-Bewertungen**, die die redaktionelle
      `community_rating` schrittweise ersetzen (klar gekennzeichneter
      Übergang) — RPC `beer_rating_stats` (nur Aggregat, keine Identitäten),
      Anzeige im Bier-Detail oberhalb der redaktionellen Einschätzung
- [x] **Blockieren & Melden serverseitig** (durchsetzbar, nicht nur lokal) —
      Migration 0009: `blocks`-/`reports`-Tabellen, Blockierung wirkt über
      `are_friends` in allen RLS-Policies; UI im Freunde-Screen
- [x] **Neue Datenschutzerklärung** — PRIVACY.md um Abschnitt 4d
      (Online-Modus) ergänzt; Konto-Löschung in der Beta auf Anfrage, in-App
      ab v1.0; Standort-Regeln unverändert streng
- [ ] **Play-Store-Launch** parallel zur weiterhin verfügbaren GitHub-APK

**Exit-Kriterium:** Der magische Moment aus der Produktvision – ≥ 25 % der
Beacons erhalten binnen 30 Minuten eine Reaktion („Prost!" oder „Bin dabei!").

## Stufe C — v2.x „Tiefe & Nachhaltigkeit" *(fortlaufend, Priorisierung nach Nutzung)*

Ziel: Gründe, jede Woche zurückzukommen – und ein Modell, das die laufenden
Kosten trägt (siehe [docs/09](09-wachstum-und-geschaeftsmodell.md)).

- [ ] **Venues & Tap-Listen** für verifizierte Betreiber („Was läuft gerade
      vom Fass?") — *Fundament fertig: gemeinsame Gasthaus-DB (Supabase, 0011)
      mit Preisen (0,5 l/0,3 l), Kategorien, Karte, Schnellansicht,
      Google-Maps-Link, Venue-Picker in Session/Check-in,
      Vertrauensstufen-Datenpflege (0013 inkl. Audit-Log), durchsuchbarer
      Gasthausliste (A–Z/Nähe/Preis/Aktuell), Offline-Warteschlange für die
      Pflege (Drift v8) und strukturierten Öffnungszeiten inkl.
      „Jetzt geöffnet"-Filter (0015); Tap-Listen und
      Betreiber-Verifizierung stehen noch aus*
- [ ] **Geplante Sessions & Events** (Termin in der Zukunft, Erinnerungen,
      Kalender-Export) — *die Zu- und Absage samt sichtbarer Antwortliste
      ist seit 0.10.13 fertig (0047,
      [Funktion 07](features/07-sessions-und-beacons.md)); es fehlt der
      Termin*
- [ ] **Empfehlungen**: „Das könnte dir schmecken" auf Basis eigener Bewertungen
- [ ] **Jahresrückblick** („Dein Bierjahr") mit teilbarem Bild-Export
- [ ] **Etikett-Foto-KI** als Ausbau des Scanners: Kein Barcode? Foto vom
      Etikett genügt — *Vorstufe fertig: Foto + EAN landen beim Anlegen
      direkt in der Community-DB (Migration 0010), die Community validiert
      über Check-ins vs. „Kein Bier"-Meldungen (±10-Regel)*
- [x] **Crews** (Gruppen) mit Crew-Beacons — *seit 0.9.12 anlegen und
      beitreten; seit 0.10.12 vollständig: Runden-Feed, Bilanz,
      sechsstelliger Code zum Vorlesen, QR und **Freunde einladen**
      (0041–0044). Offen bleibt nur der Ausbau — Challenges und Rollen
      neben dem Gründer (siehe [Funktion 09](features/09-crews.md))*
- [ ] **Monetarisierung gemäß docs/09**: Premium („BrewMates Pro") zuerst,
      Werbung nur optional und dezent – Kernfunktionen bleiben gratis
- [x] **Bier-DB über Österreich hinaus**: Erweiterung auf den DACH-Raum
      (Deutschland, Schweiz) mit demselben Community-Workflow — *seit
      0.9.13: 95 Biere / 40 Brauereien Restdeutschland + 45 Biere /
      18 Brauereien Schweiz (`beers-de/ch.json`, `breweries-de/ch.json`)*

---

## Stufe D — „Nachschärfen & Abstufen" *(✅ abgeschlossen mit 0.10.0-beta)*

Ziel: die Lücken schließen, die das [Funktionsaudit](12-funktionsaudit.md)
gefunden hat, und den Daten mehr Bedeutung geben. Jeder Punkt hat ein
eigenes Dokument mit Umsetzungsplan.

**Lücken im Bestand (0.9.14):**

- [x] **[Feed-Einträge löschen](features/19-feed-eintraege-loeschen.md)** —
      eigene Check-ins entfernen, offlinefähig, mit „Rückgängig"
      (Drift v10, `checkin_delete_queue`)
- [x] **Listen auf Wachstum vorbereitet** — Feed und Tagebuch laden
      30er-Seiten, fünf wachsende Listen bauen faul, Migration 0020 bringt
      den fehlenden `created_at`-Index
- [x] **[Freunde per QR-Code](features/22-freunde-per-qr-code.md)** —
      Code anzeigen und scannen (`qr_flutter`, `mobile_scanner`)
- [x] **[Beacon-Laufzeit](features/23-beacon-laufzeit.md)** — 30 min bis
      12 h, verlängerbar, Grenzen serverseitig (0021)

**Mehr Bedeutung (0.9.15 / 0.9.16):**

- [x] **[Statistiken](features/20-feed-statistiken.md)** — Menge, Land,
      Stil, Gebinde, Zeitraum und Filter; Füllmenge je Check-in neu
      (Drift v11, 0022)
- [x] **[Hintergrundgeschichten](features/21-hintergrundgeschichten.md)** —
      Feld, Anzeige und Erst-Scan-Hinweis (Drift v12, 0023); 30 von 125
      Brauereien erzählt, der Rest folgt bei der laufenden Datenpflege

**Abstufung (0.10):**

- [x] **[Freundeskreise](features/24-freundeskreise.md)** — Bekannte,
      Freunde, Best Buddys; Beacon-Position und Bierlaune serverseitig
      abgestuft (0024). Offen: Aufteilung je Zeile einstellbar,
      Session-Sichtbarkeit „nur Best Buddys"

**Später — Wirtschaftliches (nach 1.0):**

- [ ] **[Brauerei-Besitz](features/25-brauerei-besitz.md)** — echte
      Betreiber beantragen ihre Brauerei, Admins verifizieren, danach
      pflegen sie ihre Daten selbst.
- [ ] **[Bier-Angebote](features/26-bier-angebote.md)** — sehr späte
      Ausbaustufe; das Dokument hält vor allem die Leitplanken fest,
      damit sie nicht später verhandelt werden.

---

## Prioritäten aus der Wettbewerbsanalyse (2026-08)

Quelle: Wettbewerbsanalyse-Dokument (Google Docs, 14.08.2026). Kernbefund:
BrewMates verbindet beide Hälften strukturell bereits; die
Maßnahmen sind überwiegend Aktivierung des Vorhandenen.

**Bereits umgesetzt (Stand 0.9.11):**

- [x] **One-Tap-Check-in** („⚡ Nochmal: <letztes Bier>" auf dem Home-Tab —
      loggen in unter zwei Sekunden, Details später ergänzbar)
- [x] **„Bierlaune"-Status** (0018): Lust signalisieren, ohne zu trinken —
      Chip auf Home (4 Stunden), Freunde mit Bierlaune erscheinen als
      Home-Karte. Die meistgewünschte fehlende Funktion der Treffen-Hälfte.
- [x] **Badges sichtbar feiern** (Vollbild-Celebration, Galerie mit
      Fortschritt), **EAN-Scan als Katalog-Motor** (0010),
      **Foto-Feed dosiert** (Freunde-only, 0009-Moderation),
      **Challenges-Infrastruktur** (0012/0014) + erste Monats-Challenge
      live („Stil-Safari August" 🦁 — Vielfalt statt Menge)
- [x] **Statistiken frei** statt hinter Abo (Profil-Zähler; Ausbau s. u.)

**Nächste Schritte (priorisiert):**

- [x] **Session-Push mit Spam-Bremse** — der virale Kern der Treffen-Hälfte.
      *Erledigt mit 0039 (0.10.10): Push nur beim Session-Start, eine
      Meldung je Gastgeber und Stunde, und die Empfängerliste ist
      wortwörtlich die Sichtbarkeitsregel der Session. Antworten seit
      0.10.13: „Prost", „Ich komme vorbei", „Ich hab keine Zeit" (0047).*
- [x] **Crews aktiv nutzen** (seit 0.9.12): Crew gründen, Beitritt per
      Einladungscode (= Crew-UUID, bewusst kein Kontakte-Import),
      Mitgliederliste, verlassen/auflösen — und **Crew-Beacons**:
      Sessions mit Sichtbarkeit „Nur meine Crew" (RLS zeigt Beacon UND
      Check-ins der Runde nur Crew-Mitgliedern). Offen: eigener Crew-Feed.
- [x] **Badge-Level** (seit 0.9.12): 8 erreichbare Zwischenstufen
      (Stil-Kenner/-Professor, Globetrotter, Kurator, Brauerei-Pilger,
      Wirtshaus-Legende, Klarer Kopf, Landvermesser) + 🔥
      **Wochen-Serie** (Wochen statt Tage — kein täglicher Trinkanreiz)
      als Badge und Profil-Statistik. Offen: Heatmap.
- [ ] **Homescreen-Widget** („Session starten / letztes Bier einchecken",
      Flutter `home_widget`) — sichtbares Alleinstellungsmerkmal
- [ ] **„Year in Beer"-Story-Export** (teilbar = kostenloses Marketing)

**Bewusst NICHT übernehmen** (aus den Fehlern der Vorbilder):
Unique-Tick-Mechaniken/Volumen-Ranglisten (Ticking Culture, heikel bei
Alkohol — Milestones an Vielfalt/Orte/Soziales koppeln), Werbung im Feed,
Kontakte-Import (QR/Username bleibt), Spirituosen-Ausweitung,
Verified-Venue-Komplexität, 0,25er-Rating-Fetisch als öffentliche
Rangliste (Ratings primär privat/als Geschmacksprofil denken).

*Technik-Notiz: `spatial_ref_sys`-RLS (Advisor „critical") ist als
PostGIS-Systemtabelle nur durch `supabase_admin` änderbar — Versuch am
14.08. scheiterte an Ownership; bleibt dokumentierte, unkritische
Baseline (öffentliche Koordinatendaten).*

---

## Risiken & Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| **Open-Food-Facts-Abdeckung dünn** (viele Biere, v. a. von Kleinbrauereien, haben dort keinen oder unvollständigen Eintrag) | Lookup-Kette endet nie in einer Sackgasse: Scan → lokale DB → OFF → vorausgefülltes Anlegen-Formular; jeder neu erfasste Barcode fließt über das Issue-Formular in die gemeinsame DB zurück und verbessert die Trefferquote für alle |
| **`mobile_scanner` / AGP-Kompatibilität** (Plugin-Updates erzwingen mitunter neue Android-Gradle-Plugin-/SDK-Versionen und brechen den CI-Build) | Plugin-Version pinnen, Upgrades nur gezielt und mit CI-Build-Test; Fallback manuelle EAN-Eingabe existiert ohnehin plattformübergreifend, sodass die App nie vom Scanner-Plugin blockiert wird |
| **GPS & Privatsphäre** | Bleibt eisern: **Standort wird ausschließlich während einer aktiven Session geteilt**, nur mit Freunden, mit automatischem Ende und ohne Standort-Historie; in Stufe A verlässt der Standort das Gerät überhaupt nicht, in Stufe B wird die Regel serverseitig erzwungen (RLS + Auto-Ende) |
| **Kaltstart-Problem der Online-Stufe** (ohne Freunde kein Mehrspieler-Nutzen) | App trägt solo: Scan-Tagebuch, Abzeichen und Statistiken funktionieren komplett ohne Freunde; Onboarding fokussiert auf QR-Freundeseinladung, „Alle willkommen!"-Beacons senken die Hürde für spontane Runden |
