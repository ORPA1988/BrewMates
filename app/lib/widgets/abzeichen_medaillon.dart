import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/badges.dart';

/// Ein Abzeichen als geprägtes Medaillon: Metallrand nach Rang,
/// Fortschritt als Ring, Symbol in der Mitte.
///
/// **Warum das Symbol ein Emoji bleibt.** Der Entwurf sah gezeichnete
/// Zeichen vor. Bei 55 Abzeichen wären das 55 Pfadsätze, die niemand
/// pflegt — und die Emoji-Kette in `core/theme.dart` ist für genau diesen
/// Zweck bereits sorgfältig gebaut (farbig auf Android und iOS, nachgeladen
/// im Browser). Gezeichnet ist deshalb das *Medaillon*; das Symbol darin
/// bleibt das Emoji. Das ist der Teil der Wirkung, der nichts kostet.
///
/// **Nicht verdient heißt ohne Farbe, nicht ohne Kontrast.** Bis 0.10.27
/// lag `Opacity(0.35)` über der ganzen Kachel — auch über der Schrift, die
/// damit unter 4,5:1 fiel. Hier verliert nur das Medaillon seine Farbe;
/// die Beschriftung daneben bleibt voll lesbar (docs/14).
class AbzeichenMedaillon extends StatelessWidget {
  const AbzeichenMedaillon({
    super.key,
    required this.emoji,
    required this.tier,
    required this.anteil,
    required this.verdient,
    this.groesse = 72,
  });

  final String emoji;
  final BadgeTier tier;

  /// Fortschritt von 0 bis 1. Bei [verdient] immer voll.
  final double anteil;
  final bool verdient;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: groesse,
      height: groesse,
      child: CustomPaint(
        painter: _MedaillonMaler(
          tier: tier,
          anteil: verdient ? 1 : anteil.clamp(0.0, 1.0),
          verdient: verdient,
          spur: scheme.surfaceContainerHighest,
          feld: verdient ? scheme.surface : scheme.surfaceContainerHighest,
          stumpf: scheme.outline,
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: groesse * 0.40),
            // Das Emoji trägt keine eigene Bedeutung — die steht als Text
            // daneben. Ohne diesen Ausschluss liest TalkBack den
            // Unicode-Namen vor, auf Deutsch und meist englisch.
            semanticsLabel: '',
          ),
        ),
      ),
    );
  }
}

class _MedaillonMaler extends CustomPainter {
  const _MedaillonMaler({
    required this.tier,
    required this.anteil,
    required this.verdient,
    required this.spur,
    required this.feld,
    required this.stumpf,
  });

  final BadgeTier tier;
  final double anteil;
  final bool verdient;
  final Color spur;
  final Color feld;
  final Color stumpf;

  @override
  void paint(Canvas canvas, Size size) {
    final mitte = Offset(size.width / 2, size.height / 2);
    final aussen = size.width / 2;
    final ringBreite = size.width * 0.07;
    final ringRadius = aussen - ringBreite / 2;
    final feldRadius = aussen - ringBreite * 1.75;

    // Die Spur, auf der der Fortschritt läuft — sie ist immer ganz da,
    // damit sichtbar bleibt, wie weit der Weg noch ist.
    canvas.drawCircle(
      mitte,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringBreite
        ..color = spur,
    );

    final farben = tier.farbverlauf.map(Color.new).toList();
    final metall = verdient
        ? (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringBreite
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: farben,
          ).createShader(Rect.fromCircle(center: mitte, radius: aussen)))
        : (Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringBreite
          ..strokeCap = StrokeCap.round
          ..color = stumpf);

    if (anteil > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: mitte, radius: ringRadius),
        -math.pi / 2,
        2 * math.pi * anteil,
        false,
        metall,
      );
    }

    canvas.drawCircle(mitte, feldRadius, Paint()..color = feld);
    canvas.drawCircle(
      mitte,
      feldRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringBreite * 0.5
        ..shader = metall.shader
        ..color = metall.color,
    );

    // Platin bekommt einen zweiten, dünnen Reif. Es ist der einzige Rang,
    // der sich sonst nur über die Helligkeit von Silber unterschiede —
    // und in Graustufen wären beide gleich.
    if (verdient && tier == BadgeTier.platin) {
      canvas.drawCircle(
        mitte,
        (ringRadius + feldRadius) / 2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = farben.last.withOpacity(0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_MedaillonMaler alt) =>
      alt.tier != tier ||
      alt.anteil != anteil ||
      alt.verdient != verdient ||
      alt.spur != spur ||
      alt.feld != feld ||
      alt.stumpf != stumpf;
}
