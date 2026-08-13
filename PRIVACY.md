# Datenschutzerklärung für BrewMates

**Stand: 13. August 2026 — gilt für BrewMates ab Version 1.2 bzw. Online-Beta 0.9**

## 1. Kurzfassung

BrewMates speichert alle Nutzerdaten ausschließlich lokal auf Ihrem Gerät.
Es gibt keine Benutzerkonten, keine Server des Anbieters, keine Analyse-
oder Werbe-SDKs und keine Übertragung personenbezogener Daten an uns. Die
App stellt genau drei rein lesende Netzwerkverbindungen her: Kartenkacheln
von der OpenStreetMap Foundation, die redaktionelle Bier-/Brauerei-
Datenbank von GitHub und – beim Scannen unbekannter Barcodes sowie zum
Anzeigen von Etikett-Fotos – Abfragen bei Open Food Facts. Kamera und GPS arbeiten rein lokal
(Abschnitte 4b und 4c). Beta: Die Nutzung setzt ein Benutzerkonto voraus;
Check-ins und aktive Sessions werden ausschließlich mit bestätigten
Freunden über den Auftragsverarbeiter Supabase (EU) geteilt – Details in
Abschnitt 4d.

## 2. Verantwortlicher

Verantwortlicher im Sinne der Datenschutz-Grundverordnung (DSGVO):

> [Name/Firma einsetzen]
> [Anschrift einsetzen]
> E-Mail: [Kontakt-E-Mail einsetzen]

## 3. Lokale Datenspeicherung

Alle in der App erfassten Inhalte — Profil, Sessions, Check-ins, Bewertungen,
Geschmacksnotizen, Biere, Abzeichen, Statistiken, Tagebucheinträge und
Wunschliste — werden ausschließlich in einer lokalen SQLite-Datenbank auf
Ihrem Gerät gespeichert.

- Diese Daten verlassen Ihr Gerät nicht.
- Wir haben keinen Zugriff auf diese Daten.
- Es findet keine Synchronisation mit Servern des Anbieters statt.

Rechtsgrundlage für die lokale Verarbeitung ist die Bereitstellung der von
Ihnen gewünschten App-Funktionen (Art. 6 Abs. 1 lit. b DSGVO). Da die Daten
Ihr Gerät nicht verlassen, findet keine Verarbeitung durch uns statt.

## 4. Kartenkacheln von OpenStreetMap

Für die Kartenansicht lädt die App Kartenkacheln von Servern der
OpenStreetMap Foundation (OSMF), erreichbar unter `tile.openstreetmap.org`.
Beim Abruf einer Kachel werden technisch bedingt an die OSMF übertragen:

- Ihre IP-Adresse,
- die angeforderten Kachelkoordinaten (d. h. der betrachtete Kartenausschnitt),
- technische Anfragedaten (z. B. User-Agent).

Diese Übertragung ist für das Anzeigen der Karte technisch erforderlich
(Art. 6 Abs. 1 lit. b und f DSGVO). Wir erhalten dabei keine Daten. Für die
Verarbeitung durch die OSMF gilt deren Datenschutzerklärung:
<https://osmfoundation.org/wiki/Privacy_Policy>

Wenn Sie die Kartenansicht nicht öffnen, findet dafür keine
Netzwerkverbindung statt.

## 4a. Community-Datenbank von GitHub

Die App lädt beim Start und auf Wunsch („Aktualisieren"-Knopf im
Entdecken-Bereich) die redaktionelle Bier- und Brauerei-Datenbank als
JSON-Dateien von `raw.githubusercontent.com` (ein Dienst von GitHub Inc.,
Teil von Microsoft). Dabei werden technisch bedingt Ihre IP-Adresse und
technische Anfragedaten an GitHub übertragen; es werden **keine** Inhalte
von Ihrem Gerät gesendet — der Abruf ist rein lesend. Schlägt der Abruf
fehl (z. B. offline), verwendet die App die mitgelieferte lokale Kopie.
Für die Verarbeitung durch GitHub gilt deren Datenschutzerklärung:
<https://docs.github.com/privacy>

Ihre persönlichen Bewertungen, Check-ins und sonstigen Nutzerdaten werden
dabei **nicht** übertragen. Wenn Sie freiwillig ein Bier für die
gemeinsame Datenbank vorschlagen, öffnet die App lediglich die
GitHub-Webseite mit einem vorausgefüllten Formular in Ihrem Browser; das
Absenden erfolgt dort mit Ihrem eigenen GitHub-Konto.

## 4b. Kamera (Barcode-Scanner)

Die Funktion „Bier scannen" nutzt die Kamera Ihres Geräts ausschließlich,
um den Strichcode (EAN) einer Flasche oder Dose zu erkennen. Die
Verarbeitung der Kamerabilder erfolgt vollständig **lokal auf dem Gerät**;
es werden keine Fotos gespeichert und keine Bilder übertragen. Die
Kamera-Berechtigung ist optional — Sie können den Barcode jederzeit auch
von Hand eintippen.

Ist ein gescannter Barcode in der lokalen Datenbank nicht bekannt, fragt
die App den Barcode (nur die Ziffernfolge, keine weiteren Daten) bei der
freien Produktdatenbank **Open Food Facts** an
(`world.openfoodfacts.org`); dabei werden technisch bedingt Ihre
IP-Adresse und technische Anfragedaten an deren Server übertragen.

Zusätzlich zeigt die App bei Bieren aus der redaktionellen Datenbank
Etikett-Fotos an, die als Links auf die Bildserver von Open Food Facts
(`images.openfoodfacts.org`) hinterlegt sind. Beim Anzeigen eines solchen
Fotos werden — wie bei jedem Bildabruf im Internet — Ihre IP-Adresse und
technische Anfragedaten an Open Food Facts übertragen; es werden keine
Daten von Ihrem Gerät gesendet. Die Fotos stehen unter der Lizenz
CC-BY-SA und werden nur verlinkt, nicht in der App gespeichert. Es
gilt die Datenschutzerklärung von Open Food Facts:
<https://world.openfoodfacts.org/privacy>

## 4c. Standort (Beacon & Sessions)

Die Funktion „Zusammenkommen!" verwendet den GPS-Standort Ihres Geräts,
um Ihre Session auf der Karte anzuzeigen. In Version 1.x wird der
Standort dabei ausschließlich **lokal auf dem Gerät** gespeichert und
verlässt es nicht. Grundsätze: Der Standort wird nur während einer
aktiven Session verwendet, jede Session endet automatisch, es wird keine
Standort-Historie angelegt. Die Standort-Berechtigung ist optional — ohne
sie wählen Sie den Ort einfach von Hand. Zum optionalen Teilen von Sessions
mit bestätigten Freunden im Online-Modus siehe Abschnitt 4d.

## 4d. Online-Modus (optional, Beta)

Seit der Online-Beta (v0.9) ist die App eindeutig einem Benutzerkonto
zugeordnet: Für die Nutzung der Beta ist ein Konto erforderlich (ab
v0.9.2 führt der erste App-Start zur Anmeldung). Die lokalen
Speichergrundsätze der Abschnitte 3 bis 4c gelten unverändert.

Bei der Registrierung werden folgende Daten bei unserem
Auftragsverarbeiter **Supabase** (Server-Region EU) gespeichert:
E-Mail-Adresse, Passwort (gehasht durch Supabase Auth), Nutzername,
Anzeigename und Avatar-Emoji.

Bei aktivem Online-Modus überträgt die App zusätzlich an Supabase:

- Ihre eigenen **Check-ins** (Biername, Brauerei, Stil, Bewertung, Notiz,
  Ortsname),
- Ihre **aktiven Sessions** (Ortsname, Nachricht, Koordinaten, Ablaufzeit),
- von Ihnen **eingetragene Community-Biere** (Bierdaten, Barcode und —
  falls Sie eines aufnehmen — ein Produktfoto; das Foto ist als Teil der
  gemeinsamen Bierdatenbank **öffentlich** abrufbar, bitte fotografieren
  Sie nur die Flasche bzw. das Etikett),
- Ihre **Blockierungen** (sichtbar nur für Sie selbst), **Meldungen** von
  Profilen (einsehbar durch die Moderation) und „Kein Bier"-Meldungen zu
  Community-Einträgen.

Check-ins und Sessions sind **ausschließlich für von Ihnen bestätigte
Freunde sichtbar**; das wird serverseitig durch Row Level Security
erzwungen. Sessions sind dabei nur sichtbar, solange sie aktiv sind —
nach dem automatischen Ende verschwindet der Standort. Blockieren Sie
jemanden, sehen Sie beide gegenseitig keine Inhalte mehr — auch das
setzt der Server durch. In Bewertungs-Durchschnitte zu einem Bier fließt
Ihre Bewertung nur als anonymes Aggregat (Schnitt und Anzahl) ein.

Zusätzlich werden für die Funktionssteuerung eine etwaige Rolle
(z. B. Administrator/Moderation) und freigeschaltete Zusatzfunktionen
(z. B. Premium) Ihrem Konto zugeordnet gespeichert. Ihre Anmeldung bleibt
auf dem Gerät bestehen („eingeloggt bleiben"), bis Sie sich aktiv
abmelden.

Wenn Sie sich abmelden, endet die Übertragung. Die Löschung des Kontos ist
in der Beta auf Anfrage möglich (Kontakt siehe Ziffer 9), ab Version 1.0
direkt in der App. Rechtsgrundlage ist die Bereitstellung der von Ihnen
gewünschten Funktionen (Art. 6 Abs. 1 lit. b DSGVO). Für die Verarbeitung
durch Supabase gilt deren Datenschutzerklärung:
<https://supabase.com/privacy>

## 5. Was BrewMates NICHT tut

- kein Konto ohne Ihr Zutun — das Konto legen Sie selbst an; in der Beta
  ist es Voraussetzung für die Nutzung (Abschnitt 4d),
- keine Analyse-, Tracking- oder Werbe-SDKs,
- keine Übertragung von Standort-, Nutzungs- oder Profildaten an uns oder
  Dritte (mit Ausnahme des unter Ziffer 4 beschriebenen Kachelabrufs und —
  nur mit Konto — des unter Ziffer 4d beschriebenen Online-Modus),
- kein Auslesen von Kontakten, Fotos oder anderen Gerätedaten über den
  Funktionsumfang der App hinaus.

## 6. Löschung Ihrer Daten

Da alle Daten lokal gespeichert sind, löschen Sie sämtliche Daten, indem Sie
die App deinstallieren (bzw. unter Android zusätzlich über
„App-Info → Speicher → Daten löschen"). Für das optionale Konto im
Online-Modus gilt zusätzlich die Konto-Löschung nach Abschnitt 4d.

## 7. Ihre Rechte

Ihnen stehen die Rechte aus Art. 15–21 DSGVO zu (Auskunft, Berichtigung,
Löschung, Einschränkung, Datenübertragbarkeit, Widerspruch) sowie das
Beschwerderecht bei einer Datenschutzaufsichtsbehörde (Art. 77 DSGVO). Da wir
keine personenbezogenen Daten von Ihnen verarbeiten, können wir Anfragen zu
konkreten Daten in der Regel nicht zuordnen — die Kontrolle über Ihre Daten
liegt vollständig bei Ihnen auf Ihrem Gerät.

## 8. Änderungen

Diese Datenschutzerklärung wird bei funktionalen Änderungen der App
aktualisiert. Die jeweils aktuelle Fassung wird an derselben Stelle
veröffentlicht wie diese.

## 9. Kontakt

Fragen zum Datenschutz: [Kontakt-E-Mail einsetzen]
