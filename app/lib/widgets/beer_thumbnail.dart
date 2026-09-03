import 'package:flutter/material.dart';

/// Vorschaubild eines Biers — das Etikett statt eines Emojis.
///
/// **Warum das mehr ist als Schmuck.** In jeder Liste stand bisher
/// dasselbe 🍺 vor jedem Namen. Ein Zeichen, das bei allen gleich ist,
/// trägt keine Information; es kostet nur Platz und lässt die Liste
/// gleichförmig aussehen. Ein Etikett dagegen erkennt man schneller als
/// man einen Namen liest — das ist der ganze Sinn eines Etiketts.
///
/// **Geladen wird erst, wenn es gebraucht wird.** Im Bündel der App
/// stecken keine Produktbilder; die Datensätze führen nur URLs. Dieses
/// Widget lädt genau dann, wenn es gebaut wird — in einer
/// `ListView.builder` also für die sichtbaren Zeilen und nicht für die
/// 659 Biere der Datenbank. Zusätzlich wird über [cacheWidth] in
/// Vorschaugröße **entschlüsselt** statt in voller Auflösung: Ein
/// 1000×1000-Etikett belegt sonst 4 MB im Speicher, für 40 Bildpunkte
/// auf dem Schirm.
///
/// **Ohne Bild kein Loch.** 80 % der Biere haben eine Bildadresse, der
/// Rest nicht — und ein Bild kann jederzeit verschwinden, weil es fremden
/// Servern gehört. Beide Fälle enden beim vertrauten Emoji, nicht bei
/// einem grauen Kasten.
///
/// **Das Seitenverhältnis bleibt.** Die erste Fassung setzte `cacheWidth`
/// UND `cacheHeight` auf denselben Wert — das entschlüsselt auf ein
/// Quadrat und staucht jedes Etikett, das keins ist. Flaschen sind hoch,
/// also praktisch alle. Vorgegeben wird jetzt nur die Breite; die Höhe
/// ergibt sich. Angezeigt wird mit `BoxFit.contain`: lieber das ganze
/// Etikett etwas kleiner als ein zurechtgeschnittener Ausschnitt, bei
/// dem der Namenszug fehlt.
///
/// **Zur Herkunft:** Die Bilder stammen von Open Food Facts (CC-BY-SA)
/// und von den Brauereien selbst. Die Angabe dazu steht bei jedem Bier
/// auf der Detailseite — ein Klick von jeder Liste entfernt. In der
/// Vorschau selbst wäre sie unlesbar klein und damit auch keine Angabe.
class BeerThumbnail extends StatelessWidget {
  const BeerThumbnail({
    super.key,
    required this.imageUrl,
    required this.isAlcoholFree,
    this.size = 40,
  });

  final String? imageUrl;
  final bool isAlcoholFree;

  /// Kantenlänge in logischen Bildpunkten.
  final double size;

  String get _emoji => isAlcoholFree ? '💧' : '🍺';

  @override
  Widget build(BuildContext context) {
    final ersatz = Center(
      child: Text(_emoji, style: TextStyle(fontSize: size * 0.6)),
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return SizedBox(width: size, height: size, child: ersatz);
    }

    // In Gerätepunkten rechnen: Auf einem Telefon mit dreifacher Dichte
    // sind 40 logische Punkte 120 echte.
    final dichte = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    final kante = (size * dichte).round();
    final theme = Theme.of(context);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: ColoredBox(
          // Ein Etikett ist selten quadratisch; `contain` lässt oben und
          // unten Luft. Ein ruhiger Grund lässt sie beabsichtigt
          // aussehen statt nach einem Loch.
          color: theme.colorScheme.surfaceContainerHighest,
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.contain,
            // NUR die Breite vorgeben — sonst wird auf ein Quadrat
            // entschlüsselt und das Bild gestaucht.
            cacheWidth: kante,
            // Während des Ladens steht das Emoji da — kein Springen, kein
            // grauer Kasten, und bei langsamem Netz sieht die Liste
            // trotzdem fertig aus.
            frameBuilder: (_, kind, frame, warSofortDa) =>
                frame == null && !warSofortDa ? ersatz : kind,
            errorBuilder: (_, __, ___) => ersatz,
          ),
        ),
      ),
    );
  }
}
