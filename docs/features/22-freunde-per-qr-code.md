# 22 Freunde per QR-Code

> **Status:** 🔴 geplant — Freundschaften entstehen heute nur über die
> Namenssuche.
> **Geplant für:** 0.9.14-beta · **Zuletzt geprüft:** 2026-08-15

## Zielsetzung

Der Moment, in dem man sich vernetzt, ist fast immer derselbe: Zwei
Menschen sitzen am selben Tisch. Genau dort ist Tippen der falsche Weg —
Namen werden buchstabiert, falsch verstanden, und am Ende schickt jemand
eine Anfrage an den falschen Mate.

Ein QR-Code macht daraus zwei Sekunden. Nebenbei löst er das Problem, dass
man den Nutzernamen des anderen kennen muss.

## Funktion (Nutzersicht)

- Im Freundesbereich: **„Mein Code"** zeigt den eigenen QR-Code
  bildschirmfüllend, mit Nutzername darunter. Die Bildschirmhelligkeit
  geht hoch, damit er auch im dunklen Wirtshaus gelesen wird.
- Daneben **„Code scannen"** öffnet die Kamera.
- Erkannter Code → Profilkarte des anderen mit „Freundschaft anfragen".
  **Nie automatisch bestätigen:** Ein Scan ist eine Absicht, keine
  Zustimmung beider Seiten. Der Gegenüber muss annehmen wie sonst auch.
- Unbekannter oder fremder Code: freundlicher Hinweis, kein Fehlerdialog.
- Ohne Kamera (Desktop, Web ohne Freigabe): Der Code lässt sich anzeigen
  und teilen; das Scannen entfällt, die Namenssuche bleibt.

## Technische Umsetzung

- **Neu:** `features/friends/qr_share_screen.dart` (anzeigen),
  `features/friends/qr_scan_screen.dart` (lesen)
- **Geändert:** `features/friends/friends_screen.dart` (zwei Schaltflächen),
  `core/router.dart` (zwei Routen)
- **Paket:** `qr_flutter` zum Erzeugen — reines Dart, damit auf allen fünf
  Plattformen unkritisch
- **Lesen:** `mobile_scanner` ist bereits an Bord; heute auf EAN-8/13
  eingeschränkt, hier zusätzlich `BarcodeFormat.qrCode`

**Nutzlast:** `brewmates:friend:<uuid>` — die Profil-ID, die Freunde
ohnehin sehen. Kein Geheimnis, kein Zeitstempel, keine Signatur: Ein
gestohlener Code erlaubt nur, eine Anfrage zu stellen, die der andere
ablehnen kann. Der Präfix verhindert, dass ein beliebiger fremder QR-Code
als Freundesanfrage missverstanden wird.

**Kein Deep-Link in der ersten Stufe.** Ein `https://`-Link, der die App
öffnet, ist bequemer, verlangt aber Universal Links bzw. App Links samt
Server-Datei — das lohnt erst, wenn Codes auch außerhalb der App geteilt
werden.

## Modularität

- **Hängt ab von:** Freunde (08), Scanner-Infrastruktur (03)
- **Wird gebraucht von:** nichts
- **Ausbauen:** zwei Bildschirme und zwei Routen löschen, Schaltflächen
  entfernen, `qr_flutter` aus `pubspec.yaml`. Die Freundessuche bleibt
  unberührt.

## Plattformen

| Plattform | Anzeigen | Scannen |
|---|---|---|
| Android | ✅ | ✅ |
| Web | ✅ | ✅ (Kamerafreigabe nötig) |
| iOS | ✅ | ✅ (ungetestet) |
| Windows/macOS | ✅ | ❌ — `mobile_scanner` hat keine Desktop-Kamera |

Nach Regel 3 der Portierbarkeit: Wo nicht gescannt werden kann,
verschwindet die Schaltfläche, statt einen Fehler zu zeigen.

## Skalierung

Unkritisch. Ein Code je Profil, keine Serverlast — der Scan endet in
derselben Freundschaftsanfrage wie bisher.

## Umsetzungsplan

1. **Code anzeigen.** `qr_flutter` einbinden, Anzeige-Bildschirm mit
   Helligkeitsanhebung.
   *Prüfkriterium:* Widget-Test — Code enthält die eigene Profil-ID.
2. **Code lesen.** Scanner-Bildschirm mit QR-Format, Nutzlast prüfen.
   *Prüfkriterium:* Unit-Test der Zerlegung, inklusive fremder und
   verstümmelter Codes.
3. **Profilkarte + Anfrage,** Wiederverwendung der bestehenden
   Anfrage-Logik.
   *Prüfkriterium:* eigener Code führt zu „das bist du selbst";
   bestehende Freundschaft wird erkannt.
4. **Plattform-Weiche** für Geräte ohne Kamera.

## Offene Punkte / Ideen

- Später: Code als Bild teilen (Messenger)
- Später: Deep-Links, sobald Codes außerhalb der App zirkulieren
- Denkbar: Ein Gastgeber zeigt einen Session-Code, dem alle am Tisch
  beitreten — dieselbe Technik, anderer Zweck
