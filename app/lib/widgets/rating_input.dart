import 'package:flutter/material.dart';

/// Bewertung vergeben — **oder eben nicht**.
///
/// **Der Fehler, den das ablöst:** Der Check-in-Bildschirm startete mit
/// `_rating = 3.5` und schrieb diesen Wert immer mit. Wer ein Bier nur
/// eintrug, ohne es bewerten zu wollen, hat es damit bewertet — mit 3,5.
/// Das verzerrt alles, was auf Bewertungen aufbaut: den eigenen
/// Durchschnitt, die Bestenlisten und über `beer_rating_stats` auch die
/// Community-Bewertung, die anderen angezeigt wird. Und zwar systematisch
/// in eine Richtung, was schlimmer ist als Rauschen: Ein Bier mit fünf
/// beiläufigen Check-ins sah aus wie ein solide mittelmäßiges Bier,
/// obwohl niemand es je beurteilt hat.
///
/// Deshalb ist „keine Bewertung" hier der Anfangszustand und ein
/// gültiges Ergebnis, kein Sonderfall. Vergeben wird nur, was jemand
/// antippt.
///
/// **Halbe Sterne über die Tippstelle:** linke Hälfte eines Sterns =
/// „einhalb", rechte Hälfte = „ganz". Das ist die Genauigkeit, die man
/// mit dem Daumen trifft; der Schieberegler davor bot Viertelsterne, die
/// niemand bewusst gesetzt hat.
class RatingInput extends StatelessWidget {
  const RatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 36,
  });

  /// `null` = noch nicht bewertet.
  final double? rating;

  /// Bekommt `null`, wenn die Bewertung zurückgenommen wird.
  final ValueChanged<double?> onChanged;

  final double size;

  static String beschriftung(double? rating) {
    if (rating == null) return 'Noch nicht bewertet';
    final ganz = rating == rating.roundToDouble();
    final text = ganz
        ? rating.toStringAsFixed(0)
        : rating.toStringAsFixed(1).replaceAll('.', ',');
    return '$text von 5';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wert = rating ?? 0;

    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Semantics(
            button: true,
            label: '${i + 1} von 5 Sternen geben',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) {
                // Linke Hälfte des Sterns = halber Punkt.
                final halb = details.localPosition.dx < size / 2;
                onChanged(i + (halb ? 0.5 : 1.0));
              },
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  wert >= i + 0.75
                      ? Icons.star
                      : wert >= i + 0.25
                          ? Icons.star_half
                          : Icons.star_border,
                  size: size,
                  color: rating == null
                      // Ungesetzt bleibt blass: Der Unterschied zwischen
                      // „null Sterne vergeben" und „noch nicht bewertet"
                      // muss man sehen können, sonst ist die Trennung
                      // nur im Datensatz vorhanden.
                      ? theme.colorScheme.outlineVariant
                      : theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            beschriftung(rating),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: rating == null ? theme.colorScheme.outline : null,
              fontWeight: rating == null ? null : FontWeight.bold,
            ),
          ),
        ),
        if (rating != null)
          IconButton(
            tooltip: 'Bewertung zurücknehmen',
            icon: const Icon(Icons.backspace_outlined, size: 18),
            onPressed: () => onChanged(null),
          ),
      ],
    );
  }
}
