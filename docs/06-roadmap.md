# 06 – Roadmap

Drei Phasen, jede endet mit einem auslieferbaren Produkt. Grobe Schätzung für ein
Team von 2–3 Entwicklern.

## Phase 0 – Fundament *(ca. 2–3 Wochen)*

- [ ] Flutter-Projekt mit Android/iOS/Windows-Targets, CI (Lint, Tests, Build-Matrix)
- [ ] Supabase-Projekt: Auth (E-Mail/Google/Apple), Basis-Schema + RLS-Policies, Migrations-Workflow
- [ ] Design-System: Farben, Typografie, Kernkomponenten (Karte/Card, Buttons, Bewertungs-Slider)
- [ ] App-Gerüst: Router, Tab-Navigation, Theming (hell/dunkel), Windows-Zweispalter

## Phase 1 – MVP: „Der eine Tap" *(ca. 6–8 Wochen)*

Ziel: Der magische Moment funktioniert Ende-zu-Ende auf allen drei Plattformen.

- [ ] Profil & Freunde (QR, Anfragen)
- [ ] **Session starten** mit Sichtbarkeit, Auto-Ende, Stealth
- [ ] Push-Pipeline FCM + APNs + WNS (Edge Function `notify`)
- [ ] „Prost!" & „Bin dabei!", Live-Karte der Freunde-Sessions
- [ ] Check-in: Suche, Bewertung, Foto, Notiz; offline-fähig (Drift + Sync)
- [ ] Bier-Datenbank: Erst-Import (Open Data) + Einreichung unverifizierter Biere
- [ ] Feed (Sessions + Check-ins), Toasts, Kommentare
- [ ] Privatsphäre-Grundausstattung: Blockieren, Melden, Konto-Löschung, Datenexport
- [ ] Beta: TestFlight + Play-Beta + MSIX-Sideload

**Exit-Kriterium:** 20 Beta-Tester; ≥ 25 % der Beacons erhalten binnen 30 min eine Reaktion.

## Phase 2 – v1.0: „Das Tagebuch" *(ca. 6–8 Wochen)*

Ziel: Untappd-Tiefe – Gründe, täglich zurückzukommen.

- [ ] Abzeichen-Engine + Start-Set (~20 Badges, inkl. alkoholfrei)
- [ ] Statistiken & Tagebuch (Windows: große Auswertungsansichten)
- [ ] Wunschliste & Sammlung, Barcode-Scanner
- [ ] Crews (Gruppen) + Crew-Feed & Crew-Beacons
- [ ] Gemeinsame Session-Timeline („der Abend als Album")
- [ ] Venue-Seiten, Entdecken-Feed (beliebt bei Freunden / in der Nähe)
- [ ] Geschmacks-Tags & Serving-Styles; Wochenübersicht Eigenkonsum
- [ ] iOS Live Activities, Android-Widget, Windows-Toasts poliert
- [ ] **Store-Launch:** Play Store, App Store, Microsoft Store

## Phase 3 – v2.0: „Die Welt draußen" *(fortlaufend)*

- [ ] Geplante Sessions (Einladungen, Erinnerungen, Kalender-Export)
- [ ] Tap-Listen für verifizierte Venues + „Wunschbier in der Nähe"-Alarm
- [ ] Personalisierte Empfehlungen; Etiketten-Erkennung per Foto
- [ ] Jahresrückblick, Teilen nach außen (Bild-Export)
- [ ] Events (Verkostungen, Brauereiführungen)
- [ ] Web-App (Flutter Web) für Tagebuch & Statistiken

## Risiken & Gegenmaßnahmen

| Risiko | Gegenmaßnahme |
|---|---|
| **Kaltstart-Problem** (ohne Freunde kein Nutzen) | Onboarding fokussiert auf Freunde-Einladung; App ist auch solo als Bier-Tagebuch wertvoll (Untappd-Hälfte trägt allein) |
| Bier-Datenbank anfangs dünn | Open-Data-Import + einfachste Community-Einreichung („Bier fehlt? 30 Sekunden.") mit Moderation |
| Store-Richtlinien (Alkohol) | Altersfreigabe 17+/18+, keine Konsum-Gamification, alkoholfreie Kategorie, Verantwortungs-Features ab MVP |
| Standort-Datenschutz (DSGVO) | Sharing nur in aktiver Session, serverseitig erzwungen (RLS + Auto-Ende), Datenminimierung: keine Standort-Historie |
| Windows-Push (WNS)-Aufwand | Fallback: In-App-Realtime-Glocke reicht für MVP auf Windows; WNS in Phase 2 polieren |
