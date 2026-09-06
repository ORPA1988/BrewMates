import 'package:flutter/material.dart';

import '../domain/wochen_verlauf.dart';

/// Ein Jahr Check-ins als Bild: ein Feld je Woche, je mehr desto kräftiger.
///
/// **Warum ein Bild und nicht nur die Zahl (#166):** „🔥 7 Wochen-Serie"
/// sagt, wie es gerade läuft, und sonst nichts. Erst die Fläche zeigt den
/// Sommer, in dem jede Woche etwas war, und die drei Wochen im November,
/// in denen gar nichts war — und das ist der Teil, über den man redet.
///
/// **Wochen, keine Tage.** Dieselbe Entscheidung wie bei der Serie
/// (`domain/streak.dart`): Ein Kalender mit 365 Feldern, von denen jedes
/// leere ins Auge sticht, ist ein täglicher Trinkanreiz. Ein Feld je
/// Woche ist ein Rückblick.
class WochenHeatmap extends StatelessWidget {
  const WochenHeatmap({super.key, required this.wochen});

  /// Älteste Woche zuerst, laufende zuletzt — so, wie [wochenVerlauf]
  /// sie liefert.
  final List<Wochenwert> wochen;

  /// Felder je Zeile. 13 ist ein Quartal, vier Zeilen sind ein Jahr.
  static const _proZeile = 13;
  static const _abstand = 4.0;

  static const _monate = [
    'Jänner', 'Februar', 'März', 'April', 'Mai', 'Juni', //
    'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (wochen.isEmpty) return const SizedBox.shrink();

    final hoechster =
        wochen.fold<int>(0, (m, w) => w.anzahl > m ? w.anzahl : m);
    final aktive = wochen.where((w) => w.anzahl > 0).length;

    Color farbe(int anzahl) {
      if (anzahl == 0) return scheme.surfaceContainerHighest;
      // Vier Stufen relativ zur besten Woche. Relativ und nicht absolut,
      // weil „viel" für jeden etwas anderes ist: Wer im Schnitt zwei
      // Check-ins hat, soll seine Fünf-Wochen sehen, nicht ein blasses
      // Feld neben einer fremden Messlatte.
      final stufe = hoechster <= 1 ? 4 : ((anzahl * 4 + hoechster - 1) ~/ hoechster);
      const deckkraft = [0.25, 0.45, 0.7, 1.0];
      return scheme.primary.withOpacity(deckkraft[stufe.clamp(1, 4) - 1]);
    }

    String beschriftung(Wochenwert w) {
      final datum = '${w.montag.day}. ${_monate[w.montag.month - 1]}';
      return switch (w.anzahl) {
        0 => 'Woche ab $datum: nichts',
        1 => 'Woche ab $datum: 1 Check-in',
        _ => 'Woche ab $datum: ${w.anzahl} Check-ins',
      };
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final breite = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _proZeile * 24.0;
        final kante =
            ((breite - (_proZeile - 1) * _abstand) / _proZeile).clamp(8.0, 32.0);

        final zeilen = <Widget>[];
        for (var i = 0; i < wochen.length; i += _proZeile) {
          final teil = wochen.sublist(
              i, (i + _proZeile).clamp(0, wochen.length));
          zeilen.add(Row(
            children: [
              for (final w in teil) ...[
                // Tooltip statt eines Tipps: Am Rechner reicht Zeigen,
                // am Telefon langes Drücken — beides ohne einen Dialog,
                // der die Fläche verdeckt, um die es geht.
                Tooltip(
                  message: beschriftung(w),
                  child: Semantics(
                    label: beschriftung(w),
                    child: Container(
                      width: kante,
                      height: kante,
                      decoration: BoxDecoration(
                        color: farbe(w.anzahl),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                if (w != teil.last) const SizedBox(width: _abstand),
              ],
            ],
          ));
          if (i + _proZeile < wochen.length) {
            zeilen.add(const SizedBox(height: _abstand));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...zeilen,
            const SizedBox(height: 8),
            // Der Satz steht nicht zur Zierde da: Er sagt dasselbe wie
            // das Bild, nur vorlesbar — und er nennt die Bezugsgröße,
            // ohne die die Farbstufen nichts bedeuten.
            Text(
              '$aktive von ${wochen.length} Wochen mit Check-in · '
              'kräftigstes Feld = beste Woche ($hoechster)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        );
      },
    );
  }
}
