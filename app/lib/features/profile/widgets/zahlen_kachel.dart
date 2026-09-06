import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/statistics.dart';
import '../profile_providers.dart';

/// Was hinter einer Zahl auf dem Profil steckt (Funktion 47).
///
/// **Warum jede Kachel eins bekommt und nicht nur die, die springen
/// können:** Der naheliegende Weg wäre gewesen, jede Kachel in den
/// passenden Bildschirm zu führen. Er scheitert an „Venues", „Sessions"
/// und „Wochen-Serie" — dort gibt es kein sinnvolles Ziel. Ein Raster, in
/// dem sechs von neun Kacheln reagieren und drei nicht, sieht aus wie ein
/// Fehler und ist schlechter als das tote Raster von vorher.
///
/// Ein Blatt kann dagegen immer etwas sagen: die Aufschlüsselung, wo es
/// eine gibt, und sonst wenigstens, was die Zahl bedeutet.
class ZahlenKachelInfo {
  const ZahlenKachelInfo({
    required this.titel,
    required this.erklaerung,
    this.dimension,
    this.ziel,
    this.zielName,
  });

  /// Überschrift im Blatt — ausgeschrieben, nicht die knappe
  /// Kachel-Beschriftung: „Deine Bierstile" statt „Stile".
  final String titel;

  /// Ein Satz, der die Zahl erklärt. Er steht **immer** da, auch wenn es
  /// eine Aufschlüsselung gibt — sie beantwortet „woraus", er „was".
  final String erklaerung;

  /// Schlüssel der Aufteilung aus `domain/statistics/dimensions.dart`.
  /// `null` heißt: für diese Zahl gibt es keine sinnvolle Zerlegung.
  final String? dimension;

  /// Route für den Knopf am Fuß, falls es ein passendes Vollbild gibt.
  final String? ziel;
  final String? zielName;
}

/// Eine Zahl auf dem Profil, die beim Antippen erzählt, woraus sie besteht.
class ZahlenKachel extends ConsumerWidget {
  const ZahlenKachel({
    super.key,
    required this.label,
    required this.value,
    required this.info,
  });

  final String label;
  final int? value;
  final ZahlenKachelInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _zeigeBlatt(context, ref),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value?.toString() ?? '–',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _zeigeBlatt(BuildContext context, WidgetRef ref) {
    // Erst hier wird gerechnet: Der Reiter selbst baut sich auf, ohne
    // neun Aufschlüsselungen zu erzeugen, von denen acht niemand ansieht.
    final balken = info.dimension == null
        ? const <StatSlice>[]
        : ref.read(profilAufschluesselungProvider).slices(info.dimension!);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (blattContext) =>
          _Blatt(info: info, wert: value, balken: balken),
    );
  }
}

class _Blatt extends StatelessWidget {
  const _Blatt({
    required this.info,
    required this.wert,
    required this.balken,
  });

  final ZahlenKachelInfo info;
  final int? wert;
  final List<StatSlice> balken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Der größte Balken gibt den Maßstab. Ohne ihn wäre ein Feld mit
    // dreimal „1×" drei volle Balken — technisch richtig, aber es
    // behauptet einen Unterschied, den es nicht gibt.
    final groesster = balken.isEmpty
        ? 1
        : balken.map((b) => b.count).reduce((a, b) => a > b ? a : b);

    return SafeArea(
      // Gedeckelt und scrollbar: Zehn Balken plus Erklärung passen auf
      // einem quer gehaltenen Telefon nicht mehr, und ein Blatt, das über
      // den Rand läuft, verliert seinen Knopf.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(info.titel, style: theme.textTheme.titleLarge),
                  ),
                  Text(
                    wert?.toString() ?? '–',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                info.erklaerung,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (info.dimension != null) ...[
                const SizedBox(height: 16),
                if (balken.isEmpty)
                  // Kein leerer Kasten: Wer noch nichts eingetragen hat,
                  // braucht den nächsten Schritt, nicht die Feststellung,
                  // dass nichts da ist.
                  Text(
                    'Noch keine Check-ins — dein erster wartet. 🍻',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (final b in balken)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _Balken(slice: b, anteil: b.count / groesster),
                    ),
              ],
              if (info.ziel != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      // Erst schließen, dann navigieren — sonst liegt das
                      // Blatt über dem Ziel, in das es geführt hat.
                      Navigator.of(context).pop();
                      context.push(info.ziel!);
                    },
                    child: Text(info.zielName ?? 'Mehr ansehen'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Balken extends StatelessWidget {
  const _Balken({required this.slice, required this.anteil});

  final StatSlice slice;
  final double anteil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                slice.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${slice.count}×',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: anteil,
            minHeight: 6,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}
