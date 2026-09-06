import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/export/bild_ausgeben.dart';
import '../../data/checkin_facts_mapping.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../domain/jahresrueckblick.dart';
import '../../widgets/wochen_heatmap.dart';

/// Dein Bierjahr auf einer Seite (#167).
///
/// **Warum eine eigene Seite und nicht ein Abschnitt in der Statistik:**
/// Die Statistik ist ein Werkzeug — Zeitraum wählen, filtern, exportieren.
/// Der Rückblick ist ein Bild, das man einmal ansieht und weitergibt. Ein
/// Filterbalken darüber würde ihn zu einem Werkzeug machen, das er nicht
/// ist.
class RueckblickScreen extends ConsumerStatefulWidget {
  const RueckblickScreen({super.key});

  @override
  ConsumerState<RueckblickScreen> createState() => _RueckblickScreenState();
}

class _RueckblickScreenState extends ConsumerState<RueckblickScreen> {
  /// Umschließt genau das, was ins Bild kommt — nicht den ganzen
  /// Bildschirm: Die Leiste oben und der Knopf gehören nicht auf ein
  /// Bild, das jemand weitergibt.
  final _bildbereich = GlobalKey();

  /// Vom Menschen gewählt — `null` heißt „das neueste Jahr".
  int? _jahr;

  /// Das Jahr, das gerade wirklich auf dem Bildschirm steht. Der
  /// Dateiname braucht es, und dort ist [_jahr] noch `null`, solange
  /// niemand ausgewählt hat.
  int _angezeigt = 0;

  bool _laeuft = false;

  Future<void> _alsBild() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _laeuft = true);
    try {
      final grenze =
          _bildbereich.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (grenze == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Das Bild ließ sich nicht erzeugen.'),
        ));
        return;
      }
      // Dreifache Auflösung: Ein Bild, das später in einem Chat landet,
      // wird dort noch einmal skaliert — bei 1:1 sieht die Schrift
      // danach ausgefranst aus.
      final bild = await grenze.toImage(pixelRatio: 3);
      final daten = await bild.toByteData(format: ui.ImageByteFormat.png);
      bild.dispose();
      if (daten == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Das Bild ließ sich nicht erzeugen.'),
        ));
        return;
      }
      final gespeichert = await bildAusgeben(
        daten.buffer.asUint8List(),
        'brewmates-bierjahr-$_angezeigt.png',
      );
      messenger.showSnackBar(SnackBar(
        content: Text(gespeichert
            ? 'Bild heruntergeladen — jetzt kannst du es weitergeben.'
            : 'Auf diesem Gerät gibt es keinen Download. Ein '
                'Bildschirmfoto von dieser Seite bringt dasselbe Bild.'),
      ));
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagebuch =
        ref.watch(myDiaryProvider).valueOrNull ?? const <CheckinDetails>[];
    final fakten = [for (final d in tagebuch) d.facts];
    final jahre = rueckblickJahre(fakten);
    final jahr = _jahr ?? (jahre.isNotEmpty ? jahre.first : DateTime.now().year);
    final rueckblick = jahresrueckblick(fakten, jahr);
    _angezeigt = jahr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dein Bierjahr'),
        actions: [
          // Mehrere Jahre gibt es erst ab dem zweiten — vorher wäre die
          // Auswahl ein Menü mit einem Eintrag.
          if (jahre.length > 1)
            PopupMenuButton<int>(
              tooltip: 'Jahr wählen',
              initialValue: jahr,
              onSelected: (j) => setState(() => _jahr = j),
              itemBuilder: (_) => [
                for (final j in jahre)
                  PopupMenuItem<int>(value: j, child: Text('$j')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Text('$jahr', style: theme.textTheme.titleMedium),
                  const Icon(Icons.arrow_drop_down),
                ]),
              ),
            ),
        ],
      ),
      body: rueckblick.istLeer
          ? _Leer(jahr: jahr)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RepaintBoundary(
                  key: _bildbereich,
                  child: _Bild(rueckblick: rueckblick),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _laeuft ? null : _alsBild,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Als Bild speichern'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Das Bild zeigt nur, was hier steht — keinen Namen, '
                  'keine Orte, keine Uhrzeiten.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}

/// Was tatsächlich ins Bild kommt.
class _Bild extends StatelessWidget {
  const _Bild({required this.rueckblick});

  final Jahresrueckblick rueckblick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Eigener Grund statt durchsichtig: Ein PNG ohne Hintergrund wird
        // in jedem zweiten Chat schwarz auf schwarz dargestellt.
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mein Bierjahr ${rueckblick.jahr}',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          for (final z in rueckblick.zeilen) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(z.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurface),
                      children: [
                        TextSpan(
                          text: z.wert,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '  ${z.beschriftung}'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          WochenHeatmap(wochen: rueckblick.wochen),
          const SizedBox(height: 12),
          Text(
            'BrewMates 🍻',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Leer extends StatelessWidget {
  const _Leer({required this.jahr});

  final int jahr;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍺', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Für $jahr gibt es noch nichts zurückzublicken.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ein Check-in genügt, dann steht hier etwas.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
