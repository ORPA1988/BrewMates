# Play-Console: Datensicherheits-Formular (Entwurf)

Vorbereitete Antworten für den Abschnitt **App-Inhalte → Datensicherheit**
in der Play Console. Grundlage: tatsächliche Datenflüsse der App
(Stand v0.9.9, Migrationen 0001–0016). Bitte beim Ausfüllen gegenprüfen.

## Übersicht

| Frage | Antwort |
|---|---|
| Erhebt oder teilt die App Nutzerdaten? | **Ja** (nur mit Konto; ohne Konto bleibt alles lokal) |
| Werden alle Daten bei der Übertragung verschlüsselt? | **Ja** (durchgehend HTTPS/TLS) |
| Können Nutzer die Löschung ihrer Daten beantragen? | **Ja** — per E-Mail an den Entwickler (In-App-Kontolöschung: siehe Offene Punkte) |

## Erhobene Datentypen (mit Konto)

| Datentyp | Zweck | Geteilt? | Optional? |
|---|---|---|---|
| **E-Mail-Adresse** | Konto/Anmeldung (Supabase Auth, EU) | Nein | Konto ist für die Online-Beta Pflicht |
| **Nutzername + Avatar-Emoji** | App-Funktion (Profil, für Freunde sichtbar) | Nein | frei wählbar |
| **Standort (ungefähr/genau)** | App-Funktion: nur während einer aktiven Session, nur für bestätigte Freunde sichtbar; keine Historie | Nein | **Ja** — ohne Freigabe manuelle Ortswahl |
| **Fotos** | App-Funktion: Check-in-/Bier-Fotos, vom Nutzer ausgewählt; liegen in einem öffentlichen Storage-Bucket | Nein | Ja |
| **Nutzerinhalte** (Check-ins, Bewertungen, Notizen, Kommentare, Toasts, Erfolge, Wunschliste) | App-Funktion; Sichtbarkeit: bestätigte Freunde (Check-ins/Sessions) bzw. Community (Bier-/Gasthaus-Datenpflege) | Nein | Ja |

**Nicht erhoben:** Werbe-IDs, Kontakte, SMS/Anrufe, Gesundheitsdaten,
Finanzdaten, Browserverlauf. Keine Werbung, kein Tracking, keine
Analyse-SDKs.

## Drittanbieter (technisch bedingt, keine Datenweitergabe zu Werbezwecken)

- **Supabase (EU-Region)** — Backend/Auth/Datenbank/Storage
- **OpenStreetMap-Kacheln** (tile.openstreetmap.org) — beim Öffnen der
  Karte wird technisch bedingt die IP-Adresse übertragen
- **Open Food Facts** — nur die Ziffernfolge unbekannter Barcodes
- **GitHub** — Community-Datenbank (nur lesend) und Update-Check
  (Releases-API)

## Offene Punkte vor dem Einreichen

- [ ] **In-App-Kontolöschung**: Play verlangt für Apps mit
      Konto-Registrierung einen In-App-Weg zur Kontolöschung (oder eine
      Web-URL). Vor dem Store-Release einbauen (Konto-Screen →
      „Konto löschen") oder Lösch-URL angeben.
- [ ] Datenschutz-URL im Store-Eintrag: GitHub-Pages-Seite aus PRIVACY.md
      (siehe docs/07-release-playbook.md, Abschnitt 2).
