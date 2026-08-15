# 25 Brauerei-Besitz

> **Status:** 🔴 geplant — Brauereidaten pflegen heute ausschließlich
> Vertrauensstufe 3+ und Admins.
> **Geplant für:** nach 1.0 · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Niemand kennt eine Brauerei besser als die Brauerei. Wenn echte Betreiber
ihre eigenen Angaben pflegen — Öffnungszeiten des Brauereigasthofs,
aktuelles Sortiment, saisonale Biere —, gewinnt die Datenbank an Qualität,
ohne dass die Community jede Änderung nachrecherchieren muss.

Das ist zugleich die Voraussetzung für alles Wirtschaftliche: Ohne
verifizierte Inhaber gibt es keine [Bier-Angebote](26-bier-angebote.md).

**Das Risiko ist der Kern der Funktion.** Wer die Brauereidaten kontrolliert,
kontrolliert, was tausende Nutzer über sie lesen. Eine
Besitz-Beanspruchung, die zu leicht durchgeht, ist eine offene Tür für
Werbung und Falschangaben. Deshalb: Verifizierung durch Menschen, nicht
durch einen Automatismus.

## Funktion (Nutzersicht)

**Für Brauereien:**
1. Auf der Brauereiseite: „Gehört dir diese Brauerei?"
2. Antrag mit Kontaktangaben und Nachweis — Firmen-E-Mail unter der Domain
   der Brauerei, Handelsregister- oder Gewerbeeintrag, Website mit Impressum
3. Warten auf die Prüfung, Rückmeldung in der App
4. Nach Freigabe: Bearbeiten der eigenen Brauerei, erkennbar an einem
   Abzeichen „✓ verifizierter Betrieb" auf der Seite

**Für Admins:** Ein Bereich mit offenen Anträgen samt Nachweisen,
Freigeben oder Ablehnen mit Begründung, jederzeitiger Entzug.

**Was verifizierte Inhaber dürfen:** Beschreibung, Hintergrundgeschichte,
Öffnungszeiten, Website, Sortiment ihrer eigenen Brauerei.
**Was sie nicht dürfen:** Bewertungen ändern oder löschen, fremde
Check-ins beeinflussen, Community-Bewertungen berühren. Die Trennung
zwischen Selbstdarstellung und Nutzerurteil ist nicht verhandelbar — sonst
verliert die App ihre Glaubwürdigkeit.

## Technische Umsetzung

- **Server:** neue Tabelle `brewery_claims` (Brauerei, antragstellendes
  Profil, Nachweistext, Status, Prüfer, Zeitstempel, Begründung); neue
  Spalte `breweries.owner_id`
- **RLS:** Brauereien dürfen bearbeiten — Vertrauensstufe 3+ **oder**
  `owner_id = auth.uid()`. Die bestehende Regel bleibt also, sie bekommt
  einen zweiten Zweig. Jede Änderung landet wie gehabt im
  Änderungsprotokoll (`edit_log`), mit sichtbarer Kennzeichnung, dass sie
  vom Betrieb kam.
- **App:** `features/beers/brewery_claim_screen.dart`,
  Erweiterung des Admin-Bereichs, Abzeichen auf der Brauereiseite

**Nur Supabase-Brauereien.** Kuratierte Einträge aus den JSON-Dateien sind
in der App unveränderlich (der GitHub-Abgleich überschreibt sie
vollständig). Eine beanspruchte Brauerei muss deshalb zuerst in die
Datenbank überführt werden — dieser Übergang ist der heikelste Teil und
gehört als eigener Schritt geplant.

## Modularität

- **Hängt ab von:** Bier- & Brauerei-DB (04), Vertrauensstufen (15),
  Hintergrundgeschichten (21)
- **Wird gebraucht von:** Bier-Angebote (26)
- **Ausbauen:** Antragsbildschirm und Admin-Bereich entfernen, RLS-Zweig
  `owner_id` streichen. Die Tabelle kann als Protokoll stehen bleiben.

## Plattformen

Alle. Der Antrag ist ein Formular.

## Skalierung

Wenige Anträge, manuelle Prüfung — das ist die Grenze und zugleich
gewollt. Wenn es je hunderte Anträge gibt, braucht es Prüf-Moderatoren
(Vertrauensstufe 4) statt eines automatischen Verfahrens.

## Umsetzungsplan

1. **Datenmodell** (`brewery_claims`, `breweries.owner_id`) samt Policies
   und gezielten Rechten.
2. **Antragsformular** mit Nachweisfeldern.
3. **Admin-Prüfung:** Liste, Freigabe, Ablehnung mit Begründung, Entzug.
4. **Bearbeitungsrecht** für verifizierte Inhaber, Kennzeichnung im
   Änderungsprotokoll.
5. **Abzeichen** auf der Brauereiseite.
6. **Übernahme kuratierter Brauereien** in die Datenbank beim ersten
   erfolgreichen Antrag — inklusive Schutz davor, dass der nächste
   GitHub-Abgleich die gepflegten Daten wieder überschreibt.

## Offene Punkte / Ideen

- Rechtliches vor dem Start klären: Was sagen wir zu, wenn wir jemanden
  als „verifiziert" ausweisen?
- Dasselbe Verfahren später für Gasthäuser — dort ist der Bedarf
  vermutlich größer als bei Brauereien
