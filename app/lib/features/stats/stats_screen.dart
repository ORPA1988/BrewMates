import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/statistics.dart';
import 'stats_providers.dart';

/// Auswertung der eigenen Check-ins.
///
/// Bewusst ein Rückblick, kein Wettbewerb — keine Rangliste gegen andere,
/// keine Zielvorgabe. Die Balken entstehen aus `Container`-Breiten statt
/// aus einer Diagramm-Bibliothek: Das spart ein Paket, das auf einer der
/// fünf Zielplattformen erfahrungsgemäß klemmt.
///
/// **Eine Aufteilung zur Zeit, per Chip gewählt.** Bis 0.10.13 standen
/// vier Balkenblöcke untereinander; mit acht Aufteilungen wäre daraus
/// eine Rolle geworden, durch die niemand scrollt. So bleibt der
/// Bildschirm gleich lang, egal wie viele dazukommen — und dieselbe
/// Fläche anders geschnitten zu sehen, vergleicht sich leichter.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(statsProvider);
    final period = ref.watch(statsPeriodProvider);
    final options = ref.watch(statsFilterOptionsProvider);
    final country = ref.watch(statsCountryProvider);
    final style = ref.watch(statsStyleProvider);
    final dimensionKey = ref.watch(statsDimensionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodChooser(period: period),
          const SizedBox(height: 12),

          // Filter
          if (options.countries.length > 1 || options.styles.length > 1)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (options.countries.length > 1)
                  _FilterMenu(
                    label: 'Land',
                    value: country,
                    options: options.countries,
                    onChanged: (v) =>
                        ref.read(statsCountryProvider.notifier).state = v,
                  ),
                if (options.styles.length > 1)
                  _FilterMenu(
                    label: 'Stil',
                    value: style,
                    options: options.styles,
                    onChanged: (v) =>
                        ref.read(statsStyleProvider.notifier).state = v,
                  ),
              ],
            ),
          const SizedBox(height: 16),

          if (stats.isEmpty)
            _EmptyStats(
              hasFilter: country != null || style != null,
              stats: stats,
              period: period,
            )
          else ...[
            _Totals(stats: stats, period: period),
            const SizedBox(height: 24),
            _DimensionChips(selected: dimensionKey),
            const SizedBox(height: 12),
            _BarSection(
              title: dimensionFor(dimensionKey).name,
              slices: stats.slices(dimensionKey),
            ),
            _BarSection(title: 'Check-ins je Monat', slices: stats.byMonth),
            if (stats.alcohol.hasValue) _AlcoholCard(alcohol: stats.alcohol),
          ],
          const SizedBox(height: 24),
          Text(
            'Ausgewertet werden deine eigenen Check-ins. Die Zahlen sind '
            'ein Rückblick — kein Wettbewerb.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Zeitraum: die drei Vorgaben, dazu ein freier von–bis.
class _PeriodChooser extends ConsumerWidget {
  const _PeriodChooser({required this.period});

  final StatsPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<StatsRange?>(
          segments: [
            for (final r in StatsRange.values)
              ButtonSegment(value: r, label: Text(r.label)),
          ],
          selected: {period.preset},
          // Ein freier Zeitraum wählt keine der drei Vorgaben — dann ist
          // die Auswahl leer, statt eine falsche zu behaupten.
          emptySelectionAllowed: true,
          onSelectionChanged: (s) => ref
              .read(statsPeriodProvider.notifier)
              .state = StatsPeriod.preset(s.first!),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _chooseCustom(context, ref),
              icon: const Icon(Icons.date_range, size: 18),
              label: const Text('Von–Bis'),
            ),
            if (period.isCustom) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  period.label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Future<void> _chooseCustom(BuildContext context, WidgetRef ref) async {
    final heute = DateTime.now();
    final gewaehlt = await showDateRangePicker(
      context: context,
      // Kein Check-in liegt vor der App; ein Zeitraum in der Zukunft
      // wertet nichts aus.
      firstDate: DateTime(2024),
      lastDate: heute,
      locale: const Locale('de'),
      helpText: 'Zeitraum wählen',
      saveText: 'Übernehmen',
    );
    if (gewaehlt == null) return;
    ref.read(statsPeriodProvider.notifier).state =
        StatsPeriod.custom(gewaehlt.start, gewaehlt.end);
  }
}

/// Auswahl „alle / einzelner Wert" für Land bzw. Stil.
class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      tooltip: 'Nach $label filtern',
      itemBuilder: (_) => [
        PopupMenuItem<String?>(value: null, child: Text('Alle ($label)')),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(value ?? 'Alle ($label)'),
        avatar: const Icon(Icons.filter_list, size: 18),
      ),
    );
  }
}

/// Die Chip-Reihe, mit der die Aufteilung gewählt wird.
class _DimensionChips extends ConsumerWidget {
  const _DimensionChips({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final d in dimensions)
          ChoiceChip(
            label: Text(d.name),
            selected: d.key == selected,
            onSelected: (_) =>
                ref.read(statsDimensionProvider.notifier).state = d.key,
          ),
      ],
    );
  }
}

/// Die Kopfzahlen — je Kennzahl eine Kachel, aus der Registry.
class _Totals extends StatelessWidget {
  const _Totals({required this.stats, required this.period});

  final CheckinStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // Eine Kennzahl ohne Wert erscheint gar nicht: Wer nichts
            // bewertet hat, braucht keine leere Ø-Kachel.
            for (final m in measures)
              if (stats.value(m.key) != null)
                _StatTile(
                  value: m.format(stats.value(m.key)!),
                  label: m.name,
                  emoji: m.emoji,
                ),
          ],
        ),
        if (stats.previous != null) ...[
          const SizedBox(height: 12),
          _Comparison(stats: stats, period: period),
        ],
        if (stats.volumeIsRough) ...[
          const SizedBox(height: 8),
          Text(
            // Eine Literzahl, die so tut, als wäre sie gemessen, wäre eine
            // Lüge — deshalb steht hier, wie viel geschätzt ist.
            'Bei ${stats.estimatedCount} von ${stats.checkins} Check-ins '
            'fehlt die Füllmenge — dort ist nach Gebinde geschätzt.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// „42 gegenüber 37 im Vormonat" — der Maßstab, der einer nackten Zahl
/// fehlt.
///
/// Bewusst **ohne** Wertung: keine Farbe, kein Pfeil nach oben, kein
/// „besser". Mehr Check-ins sind nicht besser als weniger; die Zahl sagt
/// nur, wie dieser Zeitraum zum vorigen steht.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.stats, required this.period});

  final CheckinStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jetzt = stats.checkins;
    final vorher = stats.previous!.checkins;
    final differenz = jetzt - vorher;
    final vorzeichen = differenz > 0 ? '+' : '';

    return Text(
      vorher == 0
          ? 'Im ${period.previousLabel} gab es hier noch nichts.'
          : '$jetzt Check-ins, im ${period.previousLabel} waren es '
              '$vorher ($vorzeichen$differenz).',
      style: theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(
      {required this.value, required this.label, required this.emoji});

  final String value;
  final String label;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // Ohne das liest eine Vorlesehilfe „🍺", „18,5 l", „Menge" als drei
      // Bruchstücke. Als Satz ist es eine Aussage.
      label: '$label: $value',
      excludeSemantics: true,
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Eine Aufteilung als Balkenreihe. Ohne Diagramm-Bibliothek — die
/// Balkenbreite ist ein Anteil der verfügbaren Breite.
class _BarSection extends StatelessWidget {
  const _BarSection({required this.title, required this.slices});

  final String title;
  final List<StatSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final max = slices.map((s) => s.count).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final s in slices)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                // Ein Balken ohne Zahl ist für eine Vorlesehilfe nichts.
                label: '${s.label}: ${s.count}',
                excludeSemantics: true,
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        s.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 16,
                            // Mindestbreite, damit auch der kleinste Wert
                            // sichtbar bleibt.
                            width: (constraints.maxWidth * s.count / max)
                                .clamp(4.0, constraints.maxWidth),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 32,
                      child: Text('${s.count}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reinalkohol — die eine Zahl hier, die einen Menschen unangenehm
/// treffen kann.
///
/// Deshalb steht sie unten statt oben, sachlich statt hervorgehoben, und
/// ohne jede Wertung: keine Farbe, kein Vergleich mit dem Vormonat, keine
/// Einordnung, keine Warnung. Die App ist kein Gesundheitsdienst und soll
/// auch nicht so tun.
///
/// Bewusst **keine** „Standardgläser": Diese Normierung stammt aus der
/// Suchtprävention und macht aus einer Angabe eine Bewertung. Milliliter
/// und Gramm sind nachvollziehbar und sagen nichts über den Menschen.
class _AlcoholCard extends StatelessWidget {
  const _AlcoholCard({required this.alcohol});

  final AlcoholSummary alcohol;

  static String _ganz(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leise = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reinalkohol im Zeitraum', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            '${_ganz(alcohol.pureMl)} ml · ${_ganz(alcohol.pureGrams)} g',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Füllmenge mal Alkoholgehalt, aufsummiert über deine '
            'Check-ins.',
            style: leise,
          ),
          if (alcohol.estimatedVolume > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Bei ${alcohol.estimatedVolume} davon ist die Füllmenge '
              'geschätzt — dann ist auch diese Zahl geschätzt.',
              style: leise,
            ),
          ],
          if (alcohol.withoutAbv > 0) ...[
            const SizedBox(height: 4),
            Text(
              alcohol.isPatchy
                  ? 'Bei ${alcohol.withoutAbv} Check-ins ist beim Bier kein '
                      'Alkoholgehalt hinterlegt. Das ist ein großer Teil — '
                      'die Zahl oben ist deshalb eher eine Untergrenze als '
                      'eine Summe.'
                  : '${alcohol.withoutAbv} Check-ins fehlen hier, weil beim '
                      'Bier kein Alkoholgehalt hinterlegt ist.',
              style: leise,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats({
    required this.hasFilter,
    required this.stats,
    required this.period,
  });

  final bool hasFilter;
  final CheckinStats stats;
  final StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vorher = stats.previous?.checkins ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            hasFilter
                ? 'Für diese Auswahl gibt es noch nichts. Nimm einen Filter '
                    'heraus oder wähle einen größeren Zeitraum.'
                : 'Noch nichts auszuwerten — dein erster Check-in fehlt.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          // „Hier nichts" ist wenig; „hier nichts, davor zwölf" sagt, dass
          // es an der Auswahl liegt und nicht an leeren Daten.
          if (vorher > 0) ...[
            const SizedBox(height: 8),
            Text(
              'Im ${period.previousLabel} waren es $vorher.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (!hasFilter) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push('/scan'),
              child: const Text('🍺 Bier scannen'),
            ),
          ],
        ],
      ),
    );
  }
}
