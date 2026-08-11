# 02 – Funktionsspezifikation

Priorisierung: **[MVP]** = Muss für den ersten Release · **[v1]** = erste Vollversion · **[v2]** = Ausbau (siehe [Roadmap](06-roadmap.md)).

---

## 1. Konto & Profil

- **[MVP]** Registrierung/Login per E-Mail, Google und Apple (Apple-Login ist App-Store-Pflicht, sobald andere Social-Logins angeboten werden).
- **[MVP]** Profil: Anzeigename, Avatar, Bio, Lieblingsstile.
- **[MVP]** Altersverifikation (Selbstauskunft ≥ 18/21 je nach Land, App-Store-Kennzeichnung).
- **[v1]** Öffentliches Profil mit Statistiken (optional privat schaltbar).

## 2. Freunde & Crews *(aus Beer with Me)*

- **[MVP]** Freunde finden per Nutzername/QR-Code; Anfrage → Bestätigung (beidseitig).
- **[MVP]** Freundesliste mit Status: aktive Session sichtbar („🍺 gerade im Hopfengarten").
- **[v1]** **Crews**: benannte Gruppen (z. B. „Stammtisch Donnerstag"), eigenes Feed- und Beacon-Ziel.
- **[v2]** Kontaktbuch-Abgleich (opt-in, gehasht) zum Freunde-Finden.

## 3. Session & Beacon *(Herzstück, aus Beer with Me)*

- **[MVP]** **Session starten mit einem Tap**: wählt automatisch aktuellen Standort (optional Venue), sendet Push an gewählte Zielgruppe (alle Freunde / Crew / niemand = Stealth-Session).
- **[MVP]** Beacon-Antworten: **„Prost! 🍻"** (Reaktion) und **„Bin dabei!"** (Teilnahme, erscheint in der Session).
- **[MVP]** **Live-Karte**: aktive Sessions von Freunden auf einer Karte; eigener Standort nur während aktiver Session sichtbar.
- **[MVP]** **Auto-Ende**: Session endet manuell oder automatisch (Standard 3 h, konfigurierbar) – danach ist der Standort sofort nicht mehr sichtbar.
- **[v1]** Gemeinsame Sessions: Teilnehmer sehen gegenseitig ihre Check-ins in einer Session-Timeline („der Abend als Feed").
- **[v1]** Session-Nachricht („Wir sitzen hinten im Garten, Tisch 12").
- **[v2]** Geplante Sessions („Freitag 18 Uhr, Craft-Bar" → Einladung + Erinnerung, Kalender-Export).

## 4. Check-ins & Bewertung *(aus Untappd)*

- **[MVP]** Check-in eines Biers: Suche in Bier-Datenbank, Bewertung (0,25er-Schritte bis 5 ⭐), Freitext-Notiz, Foto.
- **[MVP]** Check-in optional mit Venue und innerhalb einer Session.
- **[v1]** Geschmacks-Tags (fruchtig, hopfig, malzig, sauer …) und Serving-Style (Fass, Flasche, Dose, Growler).
- **[v1]** Barcode-Scanner für Flaschen/Dosen.
- **[v2]** Foto-Erkennung des Etiketts (ML-basiert).

## 5. Bier-Datenbank & Entdecken *(aus Untappd)*

- **[MVP]** Datenbank: Bier (Name, Stil, ABV, IBU, Beschreibung), Brauerei (Name, Ort, Logo). Start mit Open-Data-Import + Community-Einreichungen (moderiert).
- **[MVP]** Suche nach Bier, Brauerei, Stil.
- **[v1]** **Wunschliste** („will ich probieren") und **Sammlung** („hatte ich schon").
- **[v1]** Entdecken-Feed: beliebt bei Freunden, Top-Biere in der Nähe, neue Biere deines Lieblingsstils.
- **[v2]** Personalisierte Empfehlungen („Dir schmeckt NEIPA → probiere …").

## 6. Venues *(aus Untappd)*

- **[MVP]** Venue-Zuordnung beim Check-in/Session (Karten-POI-Suche).
- **[v1]** Venue-Seiten: dort getrunkene Biere, Freunde-Aktivität, Fotos.
- **[v2]** **Tap-Listen** für verifizierte Betreiber (was läuft gerade vom Fass) + „Bier X ist in deiner Nähe verfügbar"-Benachrichtigung.

## 7. Feed & Interaktion *(aus Untappd + Beer with Me)*

- **[MVP]** Aktivitäts-Feed der Freunde: Check-ins, gestartete Sessions, neue Abzeichen.
- **[MVP]** Reaktionen: **Toast 🍻** (Like) und Kommentare.
- **[v1]** Crew-Feed (nur Crew-Mitglieder).
- **[v2]** Teilen nach außen (Bild-Export „Mein Abend" für Messenger/Social).

## 8. Abzeichen & Statistiken *(aus Untappd)*

- **[v1]** **Abzeichen** – belohnt werden Vielfalt & Gemeinsamkeit, nie Menge:
  - Stil-Entdecker (5 verschiedene Stile), Weltenbummler (Biere aus N Ländern),
  - Local Hero (5 Venues der Heimatstadt), Session-Stammtisch (10 gemeinsame Sessions),
  - Prost-Meister (100 vergebene Toasts), Nüchtern dabei (alkoholfreie Check-ins zählen voll!).
- **[v1]** Statistiken: einzigartige Biere, Stile, Brauereien, Länder; Lieblingsstil; Verlauf pro Monat; gemeinsame Abende pro Freund.
- **[v2]** Jahresrückblick („Dein Bierjahr 2027").

## 9. Benachrichtigungen

- **[MVP]** Push: Beacon von Freunden, „Bin dabei!"-Antworten, Freundschaftsanfragen, Toasts/Kommentare.
- **[MVP]** Fein granulare Einstellungen (pro Typ; Ruhezeiten).
- **[v1]** Windows: native Toast-Notifications; Badge-Zähler auf allen Plattformen.

## 10. Privatsphäre & Sicherheit

- **[MVP]** Standort-Sharing **nur** während aktiver Session, nur an gewählte Zielgruppe, mit sichtbarem Indikator und Auto-Ende.
- **[MVP]** Stealth-Modus: Check-ins ohne Beacon/Standort.
- **[MVP]** Blockieren & Melden; DSGVO: Datenexport und Konto-Löschung in-App.
- **[v1]** Feed-Sichtbarkeit pro Check-in (Freunde / Crew / nur ich).
- Grundsatz: **Kein öffentlicher Standort. Niemals.** Karte zeigt ausschließlich bestätigte Freunde.

## 11. Verantwortungsvoller Konsum

- **[MVP]** Alkoholfreie Biere als vollwertige Kategorie (eigene Abzeichen, Filter).
- **[v1]** Private Wochenübersicht des eigenen Konsums (nur für den Nutzer sichtbar, opt-out).
- **[v1]** Kein Ranking nach Konsummenge; keine Streak-Mechanik auf Alkohol.
- **[v1]** Taxi/ÖPNV-Schnellzugriff am Session-Ende.

## 12. Plattform-Besonderheiten

| Plattform | Besonderheiten |
|---|---|
| **Android** | Widgets (Session-Schnellstart), Quick-Settings-Tile, Material You |
| **iOS** | Live Activity (aktive Session auf dem Lock-Screen), Widgets, Sign in with Apple |
| **Windows** | Zwei-Spalten-Layout (Liste + Detail), Tastatur-Navigation, Toast-Notifications, große Statistik-/Tagebuch-Ansichten |

## 13. Offline-Verhalten

- **[MVP]** Check-ins offline erfassen (Biergarten ohne Empfang!) → Sync bei Verbindung.
- **[MVP]** Eigenes Tagebuch, Wunschliste und zuletzt geladene Daten offline lesbar.
- Beacons/Live-Karte erfordern naturgemäß eine Verbindung (klare UI-Kommunikation).
