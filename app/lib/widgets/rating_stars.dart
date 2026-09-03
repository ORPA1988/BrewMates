import 'package:flutter/material.dart';

/// Fünf Sterne in Bernstein – voll, halb oder leer je nach [rating].
///
/// **Für Vorlesehilfen ist das ein Satz, keine fünf Symbole.** Ohne
/// Angabe liest TalkBack „Stern, Stern, Halber Stern, Rahmen Stern,
/// Rahmen Stern" — technisch richtig und als Bewertung wertlos. Die fünf
/// Symbole werden deshalb ausgeblendet und durch die Zahl ersetzt, die
/// sie darstellen.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  /// „3,5 von 5 Sternen" — mit Komma, weil die App deutsch spricht.
  String get _gesprochen {
    final gerundet = (rating * 10).round() / 10;
    final text = gerundet == gerundet.roundToDouble()
        ? gerundet.toStringAsFixed(0)
        : gerundet.toStringAsFixed(1).replaceAll('.', ',');
    return '$text von 5 Sternen';
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: _gesprochen,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final IconData icon;
          if (rating >= i + 0.75) {
            icon = Icons.star;
          } else if (rating >= i + 0.25) {
            icon = Icons.star_half;
          } else {
            icon = Icons.star_border;
          }
          return Icon(icon, size: size, color: color);
        }),
      ),
    );
  }
}
