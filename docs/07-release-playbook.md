# 07 — Release-Playbook: BrewMates 1.0 in die Stores

Vollständiger Freigabeprozess für Google Play (Android), Microsoft Store
(Windows) und App Store (iOS). Schritte, die **nur ein Mensch** erledigen
kann (Konten, Zahlungen, Formulare, Uploads über Web-Oberflächen), sind als
Checkboxen ☐ markiert.

## Überblick: erledigt vs. offen

| Bereich | Was Claude schon erledigt hat | Was du tun musst |
|---|---|---|
| App-Icon | `app/assets/icon/icon.png` + `icon_foreground.png` generiert (Skript: `tools/generate_icon.py`); Plattform-Icons für Android/iOS/Windows bereits via `flutter_launcher_icons` erzeugt und eingecheckt | — nichts |
| Android | `applicationId de.brewmates.app`, key.properties-Signiermechanismus in `build.gradle`, `key.properties.example`, App-Label „BrewMates", INTERNET-Permission | ☐ Keystore erzeugen, `key.properties` füllen, Play-Console-Konto + kompletter Store-Prozess |
| Windows | Fenstertitel und Versionsinfos (`main.cpp`, `Runner.rc`) auf BrewMates; `msix_config` in `pubspec.yaml` vorhanden | ☐ Partner-Center-Konto, Identity-Werte in `msix_config` eintragen, Upload |
| iOS | Bundle-ID-Konvention und Playbook | ☐ Alles Weitere — Build erfordert einen Mac (oder macOS-CI), Apple-Konto |
| CI | `.github/workflows/release.yml`: Tag `v*` baut APK, AAB, MSIX + Windows-ZIP als Actions-Artefakte | ☐ Tag pushen, Artefakte herunterladen, in die Stores hochladen |
| Datenschutz | `PRIVACY.md` (DSGVO, lokal-only, OSM-Hinweis) | ☐ Kontaktdaten/Verantwortlichen eintragen und unter einer öffentlichen URL veröffentlichen (z. B. GitHub Pages) |
| Store-Texte | `store/listing-de.md` (Name, Beschreibungen, Keywords, Alterseinstufung, Screenshot-Anforderungen) | ☐ Screenshots und Feature-Grafik erstellen, Texte in die Konsolen kopieren |

---

## 1. Voraussetzungen (einmalig)

1. ☐ **Google Play Console**-Konto anlegen: <https://play.google.com/console>
   — 25 $ einmalig. Identitätsprüfung (Ausweis) erforderlich; kann einige
   Tage dauern. Firmenkonten benötigen zusätzlich eine **D-U-N-S-Nummer**.
2. ☐ **Apple Developer Program** beitreten: <https://developer.apple.com>
   — 99 $/Jahr. Für den Vertrieb in der EU ggf. Angaben zum
   DSGVO-Verantwortlichen/„Händlerstatus" (DSA) hinterlegen.
3. ☐ **Microsoft Partner Center** registrieren:
   <https://partner.microsoft.com/dashboard> — 19 $ einmalig (Einzelperson)
   bzw. 99 $ (Firma).
4. ☐ `PRIVACY.md` ausfüllen (Verantwortlicher, Kontakt-E-Mail) und unter
   einer öffentlichen URL bereitstellen — am einfachsten GitHub Pages:
   Repo-Einstellungen → Pages → Branch `main` aktivieren; alle drei Stores
   verlangen eine Datenschutzerklärungs-URL.

---

## 2. Android → Google Play

### 2.1 Signierung einrichten (einmalig)

1. ☐ Upload-Keystore erzeugen (Passwörter sicher ablegen, z. B.
   Passwort-Manager — bei Verlust ist kein App-Update mehr möglich, sofern
   nicht Play App Signing greift):

   ```bash
   cd app/android
   keytool -genkey -v -keystore upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. ☐ `app/android/key.properties.example` nach `app/android/key.properties`
   kopieren und Passwörter/Pfad eintragen. Die Datei ist per `.gitignore`
   vom Commit ausgeschlossen — **niemals einchecken**.

### 2.2 Build

3. Lokal bauen:

   ```bash
   cd app
   flutter build appbundle --release
   # Ergebnis: build/app/outputs/bundle/release/app-release.aab
   ```

   Alternativ: `git tag v1.0.0 && git push origin v1.0.0` — die Release-CI
   baut APK und AAB als Actions-Artefakte (ohne key.properties allerdings
   debug-signiert; für den Play-Upload daher lokal mit Keystore bauen oder
   den Keystore später als CI-Secret einrichten).

### 2.3 Play Console

4. ☐ App anlegen: „App erstellen" → Name **BrewMates – Bier & Freunde**,
   Standardsprache Deutsch, Typ **App** (kein Spiel), **kostenlos**.
5. ☐ Store-Eintrag füllen (Texte aus `store/listing-de.md`): Kurz- und
   Langbeschreibung, App-Icon 512×512, **Feature-Grafik 1024×500**,
   mind. 2 Screenshots (16:9 oder 9:16).
6. ☐ **Inhaltsfragebogen (IARC)** ausfüllen: Frage zu Alkohol-Referenzen
   mit **JA** beantworten → ergibt automatisch die USK/PEGI-Einstufung
   (erwartet ~„Teens").
7. ☐ **Datenschutzerklärungs-URL** eintragen (die veröffentlichte
   PRIVACY.md, siehe Abschnitt 1).
8. ☐ **Data-Safety-Formular**: „Erhebt oder teilt deine App
   Nutzerdaten?" → **Nein**. Begründung: Data Safety fragt nach
   *erhobenen* Daten; die beim OSM-Kachelabruf übertragene IP-Adresse ist
   flüchtig (ephemeral), wird von uns weder erhoben noch gespeichert und
   muss daher nicht deklariert werden. Alle App-Daten liegen ausschließlich
   lokal (SQLite).
9. ☐ **Zielgruppe**: 18+ auswählen (Alkohol-Bezug; vermeidet zusätzliche
   Kinder-/Familien-Anforderungen).
10. ☐ AAB in die **interne Testschiene** hochladen und selbst testen.
11. ☐ **Geschlossener Test**: Achtung — neue *private* Entwicklerkonten
    (nach Nov. 2023) müssen vor dem Produktions-Release einen
    geschlossenen Test mit **mind. 12 Testern über 14 Tage**
    durchlaufen. Tester rechtzeitig einladen!
12. ☐ **Produktion**: Release anlegen, AAB übernehmen, Ländervorauswahl
    (mind. Deutschland/Österreich/Schweiz), einreichen.
13. Review-Dauer: von wenigen Stunden bis ~7 Tage (Erstveröffentlichungen
    eher länger).

---

## 3. Windows → Microsoft Store

### 3.1 Partner Center vorbereiten

1. ☐ Im Partner Center: „Neue App" → App-Namen **BrewMates – Bier &
   Freunde** (oder **BrewMates**) reservieren.
2. ☐ Unter *Produktverwaltung → Produktidentität* die Werte ablesen:
   `Package/Identity/Name`, `Package/Identity/Publisher` (Form
   `CN=XXXXXXXX-…`), `Publisher display name`.
3. ☐ Diese Werte in `app/pubspec.yaml` unter `msix_config` übernehmen:
   `identity_name` = Package/Identity/Name, `publisher` =
   `CN=…`-Wert, `publisher_display_name` = Anzeigename. (Die dort
   voreingetragene `identity_name: de.brewmates.app` ist ein Platzhalter —
   maßgeblich ist der Wert aus dem Partner Center!)

### 3.2 Build & Paket

4. Bauen und paketieren (auf einem Windows-Rechner oder via Release-CI):

   ```powershell
   cd app
   flutter build windows --release
   dart run msix:create --store
   # Ergebnis: build/windows/x64/runner/Release/brewmates.msix
   ```

   (`--store` bzw. `store: true` in der Config: Paket bleibt unsigniert —
   die Signatur übernimmt der Store.)

### 3.3 Einreichen

5. ☐ Im Partner Center eine neue Übermittlung anlegen und die `.msix`
   unter *Pakete* hochladen.
6. ☐ Store-Eintrag füllen (Texte aus `store/listing-de.md`, mind. 1
   Screenshot 1366×768+), Datenschutzerklärungs-URL eintragen.
7. ☐ **Alterseinstufung**: IARC-Fragebogen (Alkohol-Referenzen → JA).
8. ☐ Übermitteln. Zertifizierung dauert üblicherweise **24–72 h**.

### Alternative: sofort testen ohne Store

- `dart run msix:create` mit Testzertifikat (msix erzeugt/nutzt ein
  Self-Signed-Zertifikat, wenn `store: false`); Zertifikat auf dem
  Zielrechner installieren, dann `.msix` per Doppelklick sideloaden. Oder
- schlicht den kompletten Ordner `app/build/windows/x64/runner/Release/`
  als ZIP weitergeben (die Release-CI erzeugt dieses ZIP bereits als
  Artefakt) — entpacken, `brewmates.exe` starten, fertig.

---

## 4. iOS → App Store

> **Ehrlicher Hinweis:** Der iOS-Build erfordert zwingend einen Mac mit
> Xcode (oder eine CI mit macOS-Runnern, z. B. GitHub Actions
> `macos-latest` oder Codemagic). Ohne Mac-Zugang endet dieser Abschnitt
> bei Schritt 1.

1. ☐ Mac mit aktuellem Xcode besorgen; Apple-Developer-Konto (Abschnitt 1)
   in Xcode hinterlegen.
2. ☐ Bundle-ID **de.brewmates.app** registrieren (macht Xcode bei
   *Automatically manage signing* automatisch; alternativ manuell unter
   developer.apple.com → Identifiers). In
   `app/ios/Runner.xcodeproj` das Team auswählen und die Bundle-ID auf
   `de.brewmates.app` setzen.
3. ☐ Zertifikate/Provisioning: in Xcode *Signing & Capabilities* →
   *Automatically manage signing* aktivieren — Xcode erzeugt
   Distribution-Zertifikat und Provisioning-Profil selbst.
4. ☐ Bauen und hochladen:

   ```bash
   cd app
   flutter build ipa
   # Ergebnis: build/ios/ipa/*.ipa
   ```

   Upload der `.ipa` über die **Transporter**-App (Mac App Store) oder
   `xcrun altool --upload-app` / `xcrun notarytool` (moderner:
   `xcrun altool` ist deprecated, Transporter ist der einfachste Weg).
5. ☐ **App Store Connect**: App anlegen (Name **BrewMates – Bier &
   Freunde**, Bundle-ID auswählen, SKU frei wählbar).
6. ☐ **Alterseinstufung**: Fragebogen — Alkohol-Referenzen → ergibt
   **17+**.
7. **Sign in with Apple ist NICHT nötig** — die App hat keinerlei Logins
   oder Drittanbieter-Anmeldung.
8. ☐ Store-Eintrag: Texte aus `store/listing-de.md`, Screenshots 6,7" und
   6,5" (+ optional iPad), Datenschutzerklärungs-URL,
   App-Privacy-Angaben („Daten werden nicht erhoben" — Begründung analog
   zu Play Data Safety, Abschnitt 2.3 Schritt 8).
9. ☐ **Review-Hinweise** ausfüllen: kurz erklären, dass die App rein lokal
   arbeitet, kein Konto nötig ist (kein Demo-Login erforderlich) und die
   einzige Netzwerkverbindung OSM-Kartenkacheln sind.
10. ☐ Build zuerst über **TestFlight** an interne Tester verteilen und
    testen.
11. ☐ Zur Prüfung einreichen. Review-Dauer: typischerweise **1–3 Tage**.

---

## 5. Versionierung & Release-Auslösung

1. Version steht in `app/pubspec.yaml`: `version: 1.0.0+1`
   (Format `versionName+buildNumber`). **Immer zusammen mit
   `AppConfig.appVersion` in `app/lib/core/config.dart` anheben** — die
   automatische Update-Funktion vergleicht diese Konstante mit dem
   jüngsten GitHub-Release; ein Test erzwingt den Gleichstand mit
   `pubspec.yaml`.
2. Für jedes Update: mindestens die **buildNumber** erhöhen
   (`1.0.1+2`, `1.1.0+3`, …) — Play und App Store lehnen Uploads mit
   bereits verwendeter buildNumber ab. Windows: `msix_version` in der
   `msix_config` analog anheben (`1.0.1.0`).
3. Release bauen lassen:

   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```

   Der Tag-Push löst `.github/workflows/release.yml` aus; die Artefakte
   (APK, AAB, MSIX, Windows-ZIP) liegen danach im **Actions-Tab** des
   Repos beim jeweiligen Workflow-Lauf zum Download bereit.
4. ☐ Artefakte herunterladen und wie in den Abschnitten 2–4 beschrieben in
   die Stores hochladen (kein automatischer Store-Upload konfiguriert —
   dafür fehlen bewusst die Secrets; für v1 reichen die Artefakte).
