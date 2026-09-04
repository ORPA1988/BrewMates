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

✅ **CI-Signierung über GitHub-Secrets** (seit v0.9.8 eingerichtet):
   `release.yml` signiert mit dem Upload-Keystore, wenn diese
   Action-Secrets existieren (Repo → Settings → Secrets and variables →
   Actions):
   - `KEYSTORE_BASE64` — der Keystore als Base64
     (`base64 -w0 upload-keystore.jks`)
   - `KEYSTORE_PASSWORD` — Store-Passwort
   - `KEY_PASSWORD` — Key-Passwort (optional; fehlt es, wird das
     Store-Passwort verwendet). Key-Alias ist fest `brewmates`.

   Fehlen die Secrets, ist der Build wie früher debug-signiert und der
   Workflow warnt. **Wichtig:** Eine stabile Signatur ist Voraussetzung
   dafür, dass Updates über eine bestehende Installation installierbar
   sind (sonst `INSTALL_FAILED_UPDATE_INCOMPATIBLE` → Deinstallation →
   lokale Daten weg). Beim einmaligen Wechsel von Debug- auf
   Keystore-Signatur (≤ v0.9.7 → v0.9.8) müssen Tester die App einmal
   deinstallieren; nach Anmeldung stellt der Cloud-Sync Check-ins,
   Erfolge und Wunschliste wieder her.

### 2.2 Build

3. Lokal bauen:

   ```bash
   cd app
   flutter build appbundle --release
   # Ergebnis: build/app/outputs/bundle/release/app-release.aab
   ```

   Alternativ: Release-Workflow (workflow_dispatch) — die CI baut APK und
   AAB und signiert mit dem Upload-Keystore aus den Secrets (siehe 2.1
   Punkt 3); ohne Secrets debug-signiert mit Warnung.

### 2.3 Play Console

4. ☐ App anlegen: „App erstellen" → Name **BrewMates – Bier & Freunde**,
   Standardsprache Deutsch, Typ **App** (kein Spiel), **kostenlos**.
5. ☐ Store-Eintrag füllen (Texte aus `store/listing-de.md`): Kurz- und
   Langbeschreibung, App-Icon 512×512, **Feature-Grafik 1024×500**,
   mind. 2 Screenshots (16:9 oder 9:16).
6. ☐ **Inhaltsfragebogen (IARC)** ausfüllen: Frage zu Alkohol-Referenzen
   mit **JA** beantworten → ergibt automatisch die USK/PEGI-Einstufung
   (erwartet ~„Teens").
7. ☐ **Datenschutzerklärungs-URL** eintragen: PRIVACY.md wird per
   GitHub Pages veröffentlicht (`.github/workflows/pages.yml`, kombiniert
   mit der Web-App). Einmalig aktivieren: Repo → Settings → Pages →
   Source = **„GitHub Actions"**; danach liegt die Datenschutzseite unter
   `https://orpa1988.github.io/BrewMates/privacy/` (die Web-App auf der
   Root-URL `https://orpa1988.github.io/BrewMates/`).
8. ☐ **Data-Safety-Formular**: vorbereitete Antworten in
   `store/data-safety.md` (seit der Online-Beta werden mit Konto Daten
   erhoben: E-Mail, Profil, optional Standort während Sessions, Fotos,
   Nutzerinhalte; alles TLS-verschlüsselt, kein Tracking/keine Werbung).
   Voraussetzung: **In-App-Kontolöschung** (Konto-Screen → „Konto
   löschen", `delete_my_account`-RPC) ist eingebaut — im Formular die
   Löschmöglichkeit mit JA beantworten.
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

## Weitere Anmeldeverfahren freischalten (seit 0.10.13)

Die App **kann** Apple, Microsoft, Facebook, Discord und GitHub. Ob ein
Knopf erscheint, entscheidet allein diese Zeile:

```sql
update app_config set value = 'google,apple', updated_at = now()
 where key = 'auth_providers';
```

Die Reihenfolge in der Liste ist die Reihenfolge der Knöpfe. Der Wert
darf **nur** nennen, was wirklich eingerichtet ist — ein Knopf, der
„provider is not enabled" antwortet, ist schlimmer als kein Knopf: Wer
sich nicht anmelden kann, kommt nicht wieder. Kein Release nötig, auch
nicht für Geräte, die nie wieder aktualisiert werden.

Vorher pro Anbieter, im Browser:

### Gemeinsam für alle

1. ☐ Supabase → Authentication → Providers → den Anbieter einschalten,
   **Client ID** und **Secret** eintragen
2. ☐ Die dort angezeigte **Callback-URL**
   (`https://swlqkwlpnxwthbneblww.supabase.co/auth/v1/callback`) beim
   Anbieter als erlaubte Rück-URL hinterlegen
3. ☐ Supabase → Authentication → URL Configuration: die App-Rückwege
   müssen unter *Redirect URLs* stehen —
   `de.brewmates.app://login-callback` und
   `https://orpa1988.github.io/BrewMates/`. Sie stehen dort schon für
   Google; ein neuer Anbieter braucht sie **nicht** erneut

### Apple — kostet Geld, und daran führt kein Weg vorbei

☐ **Apple Developer Program, 99 $/Jahr** (<https://developer.apple.com>).
Ohne Mitgliedschaft gibt es keine Schlüssel, und ohne Schlüssel kein
„Mit Apple anmelden" — auf keiner Plattform, auch nicht auf Android.
Das ist keine technische Hürde, die sich umgehen ließe.

Danach im Apple-Developer-Portal:

1. ☐ **App ID** anlegen (Identifier, z. B. `de.brewmates.app`) und darin
   *Sign in with Apple* aktivieren
2. ☐ **Services ID** anlegen (z. B. `de.brewmates.web`) — **das** ist die
   Client-ID für Supabase, nicht die App ID. Darin *Sign in with Apple*
   konfigurieren, Domain `swlqkwlpnxwthbneblww.supabase.co` und die
   Callback-URL von oben eintragen
3. ☐ **Key** erzeugen (Keys → +, *Sign in with Apple*), die `.p8`-Datei
   herunterladen — **sie ist nur einmal ladbar** — und Key ID sowie
   Team ID notieren
4. ☐ In Supabase beim Apple-Provider Services ID als *Client ID* und den
   aus `.p8` + Key ID + Team ID erzeugten Secret eintragen. Supabase
   nimmt die vier Angaben direkt entgegen; der Secret läuft nach
   **maximal sechs Monaten ab** und muss dann erneuert werden — das ist
   der Teil, den man vergisst und der die Anmeldung stumm bricht

**Pflicht wird Apple erst mit einer iOS-Fassung**, wenn dort ein anderer
Fremdanbieter angeboten wird (App-Store-Regel). Auf Android und im Web
ist es freiwillig.

### Microsoft, Discord, GitHub — kostenlos, Minutensache

- ☐ **Microsoft** (heißt bei Supabase `azure`):
  <https://portal.azure.com> → Entra ID → App registrations → New
  registration; unter *Certificates & secrets* ein Client Secret
- ☐ **Discord**: <https://discord.com/developers/applications> → New
  Application → OAuth2; Client ID und Secret
- ☐ **GitHub**: Settings → Developer settings → OAuth Apps → New

### Facebook — kostenlos, aber mit Prüfung

☐ <https://developers.facebook.com> → App anlegen → *Facebook Login*.
Für die Berechtigung `email` verlangt Meta eine **App-Prüfung** samt
Geschäftsverifizierung; ohne sie funktioniert die Anmeldung nur für die
eingetragenen Testkonten. Das ist der aufwendigste der fünf.

## Riegel anheben (`min_supported_version`)

Nach einem Rollout, sobald die alte Fassung nicht mehr bedient werden
soll — im Supabase-SQL-Editor, ein Einzeiler:

```sql
update app_config set value = '0.10.3', updated_at = now()
 where key = 'min_supported_version';
```

Das sperrt jede Fassung **unter** dem Wert aus, die den Riegel kennt
(ab 0.10.2). Es ist eine Aussperr-Entscheidung, deshalb bewusst kein
Automatismus.

## Vor der ersten öffentlichen Veröffentlichung (Play Store)

Entscheidungen vom 2026-09-02, bewusst **noch nicht** umgesetzt:

- **E-Mail-Bestätigung einschalten** (Supabase → Authentication →
  Providers → Email → „Confirm email"). In der privaten Beta aus, damit
  Testkonten ohne Postfach gehen. Öffentlich muss jede Adresse belegt sein.
- **Leaked-Password-Protection** braucht den Pro-Tarif. Beim Wechsel auf
  Pro einschalten (gleiche Seite, „Prevent use of leaked passwords").

## Branch-Schutz auf `main` (seit 2026-09-02)

Nur noch per PR mit grünen Checks „Analyze & Test (Flutter)" und
„RLS & Migrationen (Supabase)"; kein Force-Push, kein Löschen; gilt auch
für Admins. Praktisch: `git push origin main` wird abgelehnt — Merges
laufen über die GitHub-API (`gh api -X PUT repos/…/pulls/<n>/merge`)
oder den Merge-Knopf im Browser. Der Release-Workflow ist nicht
betroffen (er pusht nicht auf `main`), der Bier-Vorschlag-Workflow
legt ohnehin Branch + PR an.
