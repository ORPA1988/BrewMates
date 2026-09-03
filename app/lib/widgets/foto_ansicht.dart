import 'package:flutter/material.dart';

/// Ein Check-in-Foto groß ansehen — zoombar, mit einem Tipp wieder zu.
///
/// **Warum es das braucht:** Im Feed ist das Foto 200 Punkte hoch und
/// beschnitten (`BoxFit.cover`). Wer wissen will, was auf dem Etikett
/// steht oder wie das Glas aussah, sieht es dort nicht. Ein Bild, das man
/// nicht vergrößern kann, ist ein halbes Bild — und ausgerechnet das
/// Foto ist der Teil eines Check-ins, den man anderen zeigen will.
Future<void> zeigeFotoGross(BuildContext context, String url) =>
    showDialog<void>(
      context: context,
      // Schwarz statt der üblichen Abdunklung: Ein Foto beurteilt man
      // nicht neben einem hellen Rand.
      barrierColor: Colors.black,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              // Tippen schließt — überall, nicht nur auf einem kleinen X.
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, kind, fortschritt) =>
                          fortschritt == null
                              ? kind
                              : const Center(
                                  child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Das Foto lässt sich gerade nicht laden.',
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Der Ausgang muss sichtbar sein, auch wenn Tippen genügt:
            // Wer das Bild gerade herangezoomt hat, tippt sonst nur
            // wieder hinein.
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
