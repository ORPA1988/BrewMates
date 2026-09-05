import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Die Fläche, in der ein Check-in-Foto steckt.
///
/// **Warum es das gibt (Meldung #171):** Vorher stand an drei Stellen
/// dasselbe `height: 200, width: double.infinity, fit: cover`. Auf dem
/// Telefon sieht das gut aus — auf einem breiten Browserfenster wird die
/// Karte 900 Punkte breit, das Foto bleibt 200 hoch, und übrig bleibt ein
/// Streifen, auf dem fast nichts mehr zu erkennen ist. Eine feste Höhe
/// neben einer freien Breite ist kein Format, sondern ein Zufall.
///
/// Hier wird stattdessen **die Breite gedeckelt und die Höhe daraus
/// gerechnet**. Damit bleibt das Seitenverhältnis überall gleich, und ein
/// Foto wird auf dem großen Bildschirm nicht breiter als ein Foto sein
/// muss — es wird nur nicht mehr flacher.
///
/// Auf Telefonbreite (rund 350 Punkte) kommt dabei fast genau die alte
/// Höhe heraus; die Ansicht im Feed ändert sich dort also nicht spürbar.
class FotoFlaeche extends StatelessWidget {
  const FotoFlaeche({
    super.key,
    required this.child,
    this.maxBreite = 480,
    this.verhaeltnis = 1.6,
    this.onTap,
    this.ecke,
  });

  /// Das Bild. Es bekommt **keine** eigene Größe mit — es füllt die
  /// Fläche, üblicherweise mit `BoxFit.cover`.
  final Widget child;

  /// Breiter wird das Foto nicht, egal wie breit das Fenster ist.
  final double maxBreite;

  /// Breite geteilt durch Höhe. 1,6 ist die alte Feed-Optik (350 × 219
  /// statt bisher 350 × 200), ohne dass es auf dem Telefon auffällt.
  final double verhaeltnis;

  /// Optionaler Tipp — im Feed öffnet er das Foto groß.
  final VoidCallback? onTap;

  /// Etwas, das oben rechts **auf** dem Foto sitzt — in den beiden
  /// Vorschauen der Knopf „Foto entfernen".
  ///
  /// Warum das hier hineingehört und nicht in einen Stack beim Aufrufer:
  /// Der Knopf soll an der Ecke des Fotos kleben, nicht an der Ecke der
  /// Spalte. Sobald das Foto schmaler ist als die Spalte — und genau das
  /// ist der Zweck dieses Widgets —, sind das zwei verschiedene Orte.
  final Widget? ecke;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(12));
    return LayoutBuilder(
      builder: (context, constraints) {
        // Unbeschränkte Breite gibt es in einer Zeile oder einem
        // waagrechten Scroller; dort gilt schlicht der Deckel.
        final verfuegbar =
            constraints.maxWidth.isFinite ? constraints.maxWidth : maxBreite;
        final breite = math.min(verfuegbar, maxBreite);
        final flaeche = ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            width: breite,
            height: breite / verhaeltnis,
            child: child,
          ),
        );
        final tippbar = onTap == null
            ? flaeche
            : InkWell(onTap: onTap, borderRadius: radius, child: flaeche);
        return Align(
          // Linksbündig wie der übrige Karteninhalt: Ein zentriertes Foto
          // über linksbündigem Text sieht aus wie ein Fehler.
          alignment: AlignmentDirectional.centerStart,
          child: ecke == null
              ? tippbar
              : Stack(
                  children: [
                    tippbar,
                    Positioned(top: 4, right: 4, child: ecke!),
                  ],
                ),
        );
      },
    );
  }
}
