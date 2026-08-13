# 06 – Roadmap 2.0

Diese Roadmap ersetzt die Roadmap 1.0 vollständig. Sie stellt die App auf ihren
neuen Kern: Der Startbildschirm hat **zwei Hero-Aktionen** –

1. **🍺 Bier scannen** – Barcode/EAN scannen → Bier erkannt → direkt einchecken;
   unbekanntes Bier → in Sekunden anlegen (lokal sofort, Community-Vorschlag optional).
2. **🍻 Zusammenkommen!** – Ein-Tap-Beacon mit echtem GPS: Die Session startet
   sofort, Freunde sehen den Standort auf der Karte, Botschaft: **„Alle willkommen!"**

Alle Untappd-Funktionen (Check-ins, Bewertungen, Bier-Datenbank, Abzeichen,
Statistiken, Wunschliste) und alle Beer-with-Me-Funktionen (Beacon, Live-Karte,
Sessions) gruppieren sich um diese zwei Hauptfunktionen – sie sind Vertiefungen,
keine gleichrangigen Einstiege mehr.

Zeitschätzungen gelten für ein Team von **2–3 Entwicklern**; **mit
KI-Unterstützung deutlich schneller** (erfahrungsgemäß etwa halbe bis drittel Zeit).

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

## Stufe A — v1.2 „Scan & Beacon" *(in Umsetzung; ca. 3–5 Wochen, mit KI-Unterstützung deutlich schneller)*

Ziel: Die zwei Hero-Aktionen funktionieren Ende-zu-Ende – komplett local-first,
ohne Konto, ohne Backend.

- [ ] **Neuer Home-Screen** mit den zwei Hero-Buttons „🍺 Bier scannen" und
      „🍻 Zusammenkommen!"; Navigation: **Home, Feed, Karte, Entdecken, Profil**
- [ ] **Barcode-Scanner** (`mobile_scanner`, EAN-8/EAN-13; Windows als
      Entwickler-Target: manuelle EAN-Eingabe statt Kamera)
- [ ] **Lookup-Kette**: lokale Bier-DB → Open Food Facts → vorausgefülltes
      Anlegen-Formular, wenn das Bier nirgends bekannt ist
- [ ] **Echtes GPS** (`geolocator`) für Beacon & Sessions: sauberer
      Berechtigungs-Flow, Fallback auf manuelle Venue-Wahl, wenn Standort
      verweigert oder nicht verfügbar
- [ ] **Barcodes in der Bier-DB**: Schema v3 für `beers-at.json`,
      Barcode-Feld im Issue-Formular für Bier-Vorschläge
- [ ] **Release v1.2.0** als APK über GitHub Releases (CI-Workflow wie gehabt)

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
- [ ] **Migration lokale Daten → Konto**: Upload-Assistent, der Check-ins,
      Abzeichen, Wunschliste & Co. einmalig und nachvollziehbar ins Konto
      überträgt — *teilweise: neue Check-ins werden seit der Beta für Freunde
      gespiegelt, der Alt-Bestand wird noch nicht übertragen*
- [x] **Echte Freundschaften** — seit Beta 0.9 per Nutzername-Suche (Anfrage,
      Bestätigung); QR-Code-Einladung später
- [x] **Live-Beacon über Geräte hinweg** (Supabase Realtime): Freunde sehen die
      Session in Sekunden auf ihrer Karte — seit Beta 0.9
- [ ] **Push-Benachrichtigungen** (FCM): „Anna hat eine Session gestartet – alle
      willkommen!"
- [ ] **Aggregierte echte Community-Bewertungen**, die die redaktionelle
      `community_rating` schrittweise ersetzen (klar gekennzeichneter Übergang)
- [ ] **Blockieren & Melden serverseitig** (durchsetzbar, nicht nur lokal)
- [x] **Neue Datenschutzerklärung** — PRIVACY.md um Abschnitt 4d
      (Online-Modus) ergänzt; Konto-Löschung in der Beta auf Anfrage, in-App
      ab v1.0; Standort-Regeln unverändert streng
- [ ] **Play-Store-Launch** parallel zur weiterhin verfügbaren GitHub-APK

**Exit-Kriterium:** Der magische Moment aus der Produktvision – ≥ 25 % der
Beacons erhalten binnen 30 Minuten eine Reaktion („Prost!" oder „Bin dabei!").

## Stufe C — v2.x „Tiefe & Nachhaltigkeit" *(fortlaufend, Priorisierung nach Nutzung)*

Ziel: Gründe, jede Woche zurückzukommen – und ein Modell, das die laufenden
Kosten trägt (siehe [docs/09](09-wachstum-und-geschaeftsmodell.md)).

- [ ] **Venues & Tap-Listen** für verifizierte Betreiber („Was läuft gerade vom Fass?")
- [ ] **Geplante Sessions & Events** (Einladungen, Erinnerungen, Kalender-Export)
- [ ] **Empfehlungen**: „Das könnte dir schmecken" auf Basis eigener Bewertungen
- [ ] **Jahresrückblick** („Dein Bierjahr") mit teilbarem Bild-Export
- [ ] **Etikett-Foto-KI** als Ausbau des Scanners: Kein Barcode? Foto vom
      Etikett genügt
- [ ] **Crews** (Gruppen) mit Crew-Feed und Crew-Beacons
- [ ] **Monetarisierung gemäß docs/09**: Premium („BrewMates Pro") zuerst,
      Werbung nur optional und dezent – Kernfunktionen bleiben gratis
- [ ] **Bier-DB über Österreich hinaus**: Erweiterung auf den DACH-Raum
      (Deutschland, Schweiz) mit demselben Community-Workflow

---

## Risiken & Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| **Open-Food-Facts-Abdeckung dünn** (viele Biere, v. a. von Kleinbrauereien, haben dort keinen oder unvollständigen Eintrag) | Lookup-Kette endet nie in einer Sackgasse: Scan → lokale DB → OFF → vorausgefülltes Anlegen-Formular; jeder neu erfasste Barcode fließt über das Issue-Formular in die gemeinsame DB zurück und verbessert die Trefferquote für alle |
| **`mobile_scanner` / AGP-Kompatibilität** (Plugin-Updates erzwingen mitunter neue Android-Gradle-Plugin-/SDK-Versionen und brechen den CI-Build) | Plugin-Version pinnen, Upgrades nur gezielt und mit CI-Build-Test; Fallback manuelle EAN-Eingabe existiert ohnehin plattformübergreifend, sodass die App nie vom Scanner-Plugin blockiert wird |
| **GPS & Privatsphäre** | Bleibt eisern: **Standort wird ausschließlich während einer aktiven Session geteilt**, nur mit Freunden, mit automatischem Ende und ohne Standort-Historie; in Stufe A verlässt der Standort das Gerät überhaupt nicht, in Stufe B wird die Regel serverseitig erzwungen (RLS + Auto-Ende) |
| **Kaltstart-Problem der Online-Stufe** (ohne Freunde kein Mehrspieler-Nutzen) | App trägt solo: Scan-Tagebuch, Abzeichen und Statistiken funktionieren komplett ohne Freunde; Onboarding fokussiert auf QR-Freundeseinladung, „Alle willkommen!"-Beacons senken die Hürde für spontane Runden |
