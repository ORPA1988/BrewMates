# 08 – So funktioniert BrewMates (für alle verständlich)

Dieses Dokument erklärt ohne Fachchinesisch, was die App macht, wo Ihre Daten
liegen und wie das Projekt weiterentwickelt wird. Es richtet sich bewusst an
Menschen, die **nicht** programmieren.

## Was die App kann – in drei Sätzen

BrewMates ist ein persönliches Bier-Tagebuch mit sozialem Dreh: Sie checken
Biere ein, bewerten sie, sammeln Abzeichen und führen Wunschliste und
Statistiken. Mit einer „Session" sagen Sie (in Version 1: Demo-)Freunden „Ich
trinke gerade ein Bier – komm vorbei!" und sehen sie auf einer Karte. Die App
läuft auf Android (die iOS-Variante bleibt technisch offen) und funktioniert
komplett ohne Konto und ohne Anmeldung.

## Wo welche Daten liegen – das Herzstück

Die wichtigste Eigenschaft von BrewMates: **Ihre Daten gehören Ihnen und
bleiben auf Ihrem Gerät.** Die folgende Tabelle zeigt für jeden Datentyp, wo
er gespeichert ist und ob dafür eine Internetverbindung nötig ist.

| Was | Wo gespeichert | Geht online? |
|---|---|---|
| **Ihre Nutzerdaten**: Profil, Check-ins, Bewertungen, Sessions, Abzeichen, Wunschliste, Tagebuch, Statistiken | Nur in einer lokalen Datenbank (SQLite) auf Ihrem Gerät | **Nein.** Verlässt das Gerät nie. Kein Konto, keine Server des Anbieters, keine Analyse- oder Werbe-Software |
| **Die Karte** | Wird nicht gespeichert, sondern bei Bedarf Stück für Stück angezeigt | **Ja**, nur beim Öffnen der Karte: Kartenkacheln kommen von OpenStreetMap (tile.openstreetmap.org). Dabei wird technisch bedingt Ihre IP-Adresse übertragen – so wie bei jedem Webseiten-Aufruf |
| **Die Bier- und Brauerei-Datenbank** (österreichische Biere und Brauereien) | Als Kopie fest in der App eingebaut **und** als gemeinsame „Stammliste" im GitHub-Repository (Ordner `app/assets/data/`) | **Ja, aber nur lesend**: Beim App-Start und auf Knopfdruck holt sich die App die aktuelle Liste von GitHub und frischt die lokale Kopie auf. Ohne Internet nutzt sie einfach die eingebaute Kopie |
| **Die „Freunde"** in Version 1 | Demo-Daten auf Ihrem Gerät | **Nein.** Es sind Beispielpersonen, keine echten Menschen |

### „Offline-first" – die Notizbuch-Metapher

Stellen Sie sich BrewMates wie ein **privates Notizbuch** vor, das Sie immer
dabeihaben. Alles, was Sie hineinschreiben – jedes Bier, jede Bewertung, jeder
Abend – steht nur in diesem Notizbuch. Niemand sonst kann hineinschauen.

Zusätzlich hängt im Ort ein **schwarzes Brett** (das GitHub-Repository), auf
dem eine gemeinsam gepflegte Liste aller österreichischen Biere und Brauereien
aushängt. Wenn Sie daran vorbeikommen (sprich: Internet haben), wirft die App
kurz einen Blick darauf und schreibt Neuigkeiten in Ihr Notizbuch ab. Kommen
Sie nicht vorbei, ist das kein Problem – eine Abschrift der Liste klebt
ohnehin hinten im Notizbuch. Wichtig: Die App **liest nur** vom schwarzen
Brett. Sie hängt dort nie etwas über Sie auf.

## Was genau beim App-Start passiert

1. **Die App öffnet Ihr Notizbuch**: Sie liest die lokale Datenbank auf dem
   Gerät. Beim allerersten Start wird diese Datenbank angelegt und mit der
   eingebauten Bier-Liste sowie den drei Demo-Freunden gefüllt.
2. **Alles ist sofort da**: Feed, Tagebuch, Statistiken und Abzeichen kommen
   vollständig aus dieser lokalen Datenbank – dafür ist kein Internet nötig.
3. **Kurzer Blick aufs schwarze Brett**: Im Hintergrund versucht die App, die
   aktuellen Bier- und Brauerei-Dateien (JSON-Dateien) von GitHub
   (raw.githubusercontent.com) zu laden. Klappt das, aktualisiert sie die
   lokale Bier-/Brauerei-Liste – neue Biere aus der Community erscheinen dann
   automatisch. Klappt es nicht (kein Netz, GitHub nicht erreichbar), passiert
   einfach nichts weiter; die App läuft mit dem letzten Stand normal weiter.
   Denselben Abgleich können Sie jederzeit auch von Hand per Knopfdruck
   anstoßen.
4. **Karte nur auf Wunsch**: Erst wenn Sie die Kartenansicht öffnen, lädt die
   App Kartenbilder von OpenStreetMap. Öffnen Sie die Karte nicht, findet
   dieser Abruf nicht statt.

```mermaid
flowchart LR
    A[App-Start] --> B[Lokale Datenbank<br>auf dem Gerät öffnen]
    B --> C[App ist voll nutzbar –<br>auch ohne Internet]
    B --> D{Internet<br>vorhanden?}
    D -- ja --> E[Bier-Liste von GitHub<br>laden und lokale<br>Kopie auffrischen]
    D -- nein --> F[Eingebaute Kopie<br>weiter verwenden]
```

## Wie ein neues Bier in die gemeinsame Datenbank kommt

Sie entdecken ein Bier, das in BrewMates noch fehlt? So läuft es ab:

1. **Sofort für Sie selbst**: Sie legen das Bier direkt in der App an. Es
   landet in Ihrer lokalen Datenbank und Sie können es ab sofort einchecken
   und bewerten – ganz ohne Internet und ohne auf irgendjemanden zu warten.
2. **Vorschlag für alle**: Zusätzlich können Sie das Bier der Community
   vorschlagen. Die App öffnet dafür ein vorausgefülltes Formular auf GitHub
   (ein sogenanntes „Issue" – siehe Begriffserklärung unten). Name, Brauerei,
   Stil usw. sind schon eingetragen; Sie müssen nur noch absenden. Dafür
   braucht man ein (kostenloses) GitHub-Konto.
3. **Prüfung**: Ein Automatismus bzw. ein Betreuer des Projekts („Maintainer")
   schaut sich den Vorschlag an – stimmt der Name, gibt es das Bier wirklich,
   ist es ein Duplikat?
4. **Aufnahme in die Stammliste**: Passt alles, wird das Bier in die
   JSON-Dateien im Repository übernommen – also ans schwarze Brett gehängt.
5. **Ankunft bei allen**: Beim nächsten Abgleich (App-Start oder Knopfdruck)
   laden alle Nutzerinnen und Nutzer die aktualisierte Liste – und Ihr
   vorgeschlagenes Bier ist plötzlich überall auswählbar.

```mermaid
flowchart LR
    A[Bier fehlt] --> B[Sofort lokal anlegen<br>und nutzen]
    A --> C[Vorschlag als<br>GitHub-Issue absenden]
    C --> D[Prüfung durch<br>Automatik/Maintainer]
    D --> E[Aufnahme in die<br>JSON-Stammliste]
    E --> F[Nächster Abgleich:<br>alle Nutzer haben es]
```

Zwei Dinge bleiben dabei immer privat bzw. getrennt:

- **Ihre persönlichen Bewertungen** verlassen das Gerät nicht – eingereicht
  werden nur die Fakten zum Bier (Name, Brauerei, Stil …).
- Das Feld **community_rating** in der Datenbank ist keine Sammlung von
  Nutzerbewertungen, sondern eine **redaktionelle Einschätzung** der
  Datenbank-Pflegenden – vergleichbar mit einer Empfehlung im Bierführer.

## Wie die App weiterentwickelt wird

BrewMates wird offen auf GitHub entwickelt. Ein paar Grundbegriffe, damit Sie
mitreden können:

- **Repository (kurz „Repo")**: Der Projektordner im Internet – er enthält den
  gesamten Quellcode, die Dokumentation und die gemeinsame Bier-Datenbank.
  Vergleichbar mit einem öffentlichen Aktenschrank, in dem jede Änderung
  nachvollziehbar abgelegt wird.
- **Issue**: Ein Eintrag im „Kummerkasten" des Projekts – eine Fehlermeldung,
  ein Wunsch oder eben ein Bier-Vorschlag. Jeder mit GitHub-Konto kann Issues
  anlegen und mitdiskutieren.
- **Pull Request**: Ein konkreter Änderungsvorschlag am Projekt („Ich habe das
  hier verbessert – bitte übernehmen"). Er wird geprüft und dann angenommen
  oder abgelehnt.
- **Release**: Eine fertig geschnürte, nummerierte Version der App (z. B.
  v1.0) samt Installationsdatei – wie eine neue Auflage eines Buches.

**Fehler melden oder Wünsche äußern**: Auf der GitHub-Seite des Projekts den
Reiter „Issues" öffnen, „New issue" wählen und beschreiben, was passiert ist
oder was Sie sich wünschen. Je konkreter (Was haben Sie getan? Was ist
passiert? Was hätten Sie erwartet?), desto besser.

**Die neueste App-Version (APK) bekommen**: Auf der GitHub-Seite des Projekts
den Bereich **„Releases"** öffnen (direkt erreichbar unter
`github.com/ORPA1988/BrewMates/releases/latest`). Dort die `.apk`-Datei
herunterladen und auf dem Android-Gerät öffnen – Android führt dann durch die
Installation. Hinter den Kulissen läuft das automatisch: Sobald die Entwickler
eine Version mit einem Etikett wie `v1.0` markieren, baut ein
CI-Automatismus (eine Art Fließband) die APK und veröffentlicht sie auf der
Releases-Seite.

## Grenzen der Version 1 – ehrlich gesagt

- **Die Freunde sind Demo-Daten.** Die drei Freunde samt ihrer Aktivität sind
  Beispielfiguren auf Ihrem Gerät, damit die App von Anfang an lebendig wirkt.
  Es sind keine echten Personen, und Sie können (noch) keine echten Freunde
  hinzufügen.
- **Keine echten Live-Standorte anderer.** Die Karte zeigt Ihre eigene
  Position und die Demo-Sessions – aber niemand sieht Sie, und Sie sehen keine
  echten anderen Menschen. Echter Mehrspieler-Betrieb (echte Freunde,
  Live-Karte über Geräte hinweg, Push-Benachrichtigungen) braucht einen
  Server im Hintergrund („Backend"). Das ist für Version 2 mit Supabase
  bereits vorbereitet (Ordner `supabase/` im Repository), aber noch nicht
  aktiv.
- **Der GitHub-Abgleich ist eine Einbahnstraße.** Die App liest die
  gemeinsame Bier-Liste nur; sie lädt nie etwas über Sie hoch.
  Bier-Vorschläge laufen bewusst über das separate Issue-Formular, das Sie
  selbst aktiv absenden.
- **Kein Gerätewechsel-Komfort.** Weil alles nur lokal liegt, wandern Ihre
  Daten beim Wechsel auf ein neues Handy nicht automatisch mit. Die Kehrseite
  der Privatsphäre – ein Sync kommt mit Version 2.
