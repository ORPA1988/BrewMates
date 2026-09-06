import 'package:flutter/material.dart';

import '../domain/auszeichnung.dart';
import '../domain/badges.dart' show BadgeTier;

/// Eine Challenge-Trophäe: Band, Medaillon, Sockel mit Jahreszahl.
///
/// **Zwei Achsen, die sich nie überschneiden.** Das Band trägt das *Jahr*,
/// das Metall den *Rang*. Deshalb kann dieselbe Weihnachtstrophäe in vier
/// Metallen existieren, ohne dass ihr Jahr unklar wird — und zwei Jahrgänge
/// derselben Challenge unterscheiden sich, ohne dass jemand sie jedes Jahr
/// neu gestalten müsste.
class Trophaee extends StatelessWidget {
  const Trophaee({
    super.key,
    required this.emoji,
    required this.art,
    required this.jahr,
    this.breite = 92,
  });

  final String emoji;
  final Auszeichnungsart art;
  final int jahr;
  final double breite;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hoehe = breite * 1.18;
    return SizedBox(
      width: breite,
      height: hoehe,
      child: CustomPaint(
        painter: _TrophaeenMaler(
          tier: art.tier,
          band: bandFarben(jahr),
          jahr: '$jahr',
          feld: scheme.surface,
          richtung: Directionality.of(context),
        ),
        child: Align(
          alignment: const Alignment(0, -0.06),
          child: Text(
            emoji,
            style: TextStyle(fontSize: breite * 0.30),
            // Das Emoji wiederholt nur, was als Text danebensteht.
            semanticsLabel: '',
          ),
        ),
      ),
    );
  }
}

class _TrophaeenMaler extends CustomPainter {
  _TrophaeenMaler({
    required this.tier,
    required this.band,
    required this.jahr,
    required this.feld,
    required this.richtung,
  });

  final BadgeTier tier;
  final List<int> band;
  final String jahr;
  final Color feld;
  final TextDirection richtung;

  /// Das Namensschild ist ein **eigenes dunkles Feld mit Metallrand**, kein
  /// Metallverlauf mit Schrift darauf.
  ///
  /// Der Grund ist gerechnet, nicht ästhetisch: Über einen Verlauf von
  /// Lichtkante zu Schattenkante trägt **keine** einzelne Tinte durchgehend
  /// 4,5:1 — Stout fällt auf Bronze bis 2,2 und auf Gold bis 3,7, Schaum
  /// fällt überall. Auf ruhigem Stout steht Schaum bei rund 14:1, in beiden
  /// Paletten. So sehen Pokale ohnehin aus.
  static const _schildGrund = Color(0xFF1C140F);
  static const _schildTinte = Color(0xFFFFF3E4);

  @override
  void paint(Canvas canvas, Size size) {
    final b = size.width;
    final metall = tier.farbverlauf.map(Color.new).toList();

    // --- Band: ein Trapez, das hinter dem Medaillon verschwindet --------
    final bandBreite = b * 0.46;
    final bandHoehe = b * 0.30;
    final bandPfad = Path()
      ..moveTo((b - bandBreite) / 2, 0)
      ..lineTo((b + bandBreite) / 2, 0)
      ..lineTo((b + bandBreite) / 2 - b * 0.09, bandHoehe)
      ..lineTo((b - bandBreite) / 2 + b * 0.09, bandHoehe)
      ..close();
    canvas.drawPath(
      bandPfad,
      Paint()
        ..shader = LinearGradient(
          colors: band.map(Color.new).toList(),
        ).createShader(Rect.fromLTWH(0, 0, b, bandHoehe)),
    );

    // --- Medaillon ------------------------------------------------------
    final mitte = Offset(b / 2, b * 0.55);
    final radius = b * 0.34;
    final ringBreite = b * 0.065;
    final metallStrich = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringBreite
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: metall,
      ).createShader(Rect.fromCircle(center: mitte, radius: radius));

    canvas.drawCircle(mitte, radius, metallStrich);
    canvas.drawCircle(
        mitte, radius - ringBreite * 0.75, Paint()..color = feld);
    canvas.drawCircle(
      mitte,
      radius - ringBreite * 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringBreite * 0.35
        ..shader = metallStrich.shader,
    );

    // Platin bekommt einen zweiten dünnen Reif — sonst unterschiede es
    // sich von Silber nur über die Helligkeit, und in Graustufen gar nicht.
    if (tier == BadgeTier.platin) {
      canvas.drawCircle(
        mitte,
        radius + ringBreite * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = metall.last,
      );
    }

    // --- Sockel mit Jahreszahl -----------------------------------------
    final sockel = Rect.fromLTWH(
      b * 0.16,
      size.height - b * 0.22,
      b * 0.68,
      b * 0.20,
    );
    final sockelForm =
        RRect.fromRectAndRadius(sockel, Radius.circular(b * 0.055));
    canvas.drawRRect(sockelForm, Paint()..color = _schildGrund);
    canvas.drawRRect(
      sockelForm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = b * 0.022
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: metall,
        ).createShader(sockel),
    );

    final zahl = TextPainter(
      text: TextSpan(
        text: jahr,
        style: TextStyle(
          fontSize: b * 0.135,
          fontWeight: FontWeight.w800,
          letterSpacing: b * 0.018,
          color: _schildTinte,
        ),
      ),
      textDirection: richtung,
    )..layout();
    zahl.paint(
      canvas,
      Offset(
        sockel.center.dx - zahl.width / 2,
        sockel.center.dy - zahl.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_TrophaeenMaler alt) =>
      alt.tier != tier ||
      alt.jahr != jahr ||
      alt.feld != feld ||
      !identical(alt.band, band);
}
