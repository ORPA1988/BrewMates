import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart' show volumeChoicesMl, formatVolume;
import '../data/db/database.dart';
import '../data/providers.dart';
import 'rating_input.dart';

/// Einen eigenen Check-in korrigieren (Funktion 27).
///
/// Liegt in `widgets/` und nicht in `features/checkin/`, weil die
/// Check-in-Karte (`widgets/checkin_card.dart`) es öffnet. Ein Import aus
/// `features/` würde die Schichtrichtung umdrehen — Vorbild ist
/// `widgets/venue_picker.dart`.
///
/// Bewusst ein schmales Blatt statt des vollen Check-in-Bildschirms: Wer
/// hier landet, will eine Kleinigkeit richtigstellen — verrutschte Sterne,
/// einen Tippfehler, ein vergessenes Gebinde. Das Bier fehlt in dieser
/// Liste mit Absicht; ein anderes Bier wäre ein anderer Check-in.
Future<bool> showCheckinEditSheet(
  BuildContext context,
  CheckinDetails details,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _CheckinEditSheet(details: details),
    ),
  );
  return result ?? false;
}

class _CheckinEditSheet extends ConsumerStatefulWidget {
  const _CheckinEditSheet({required this.details});

  final CheckinDetails details;

  @override
  ConsumerState<_CheckinEditSheet> createState() => _CheckinEditSheetState();
}

class _CheckinEditSheetState extends ConsumerState<_CheckinEditSheet> {
  /// Unbewertet bleibt unbewertet — vorher machte das `?? 3.5` aus jeder
  /// Korrektur eine nachträgliche Bewertung.
  late double? _rating = widget.details.checkin.rating;
  late final _noteController =
      TextEditingController(text: widget.details.checkin.note ?? '');
  late ServingStyle? _serving = widget.details.checkin.servingStyle;
  late int? _volumeMl = widget.details.checkin.volumeMl;
  bool _speichert = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _speichern() async {
    setState(() => _speichert = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notiz = _noteController.text.trim();

    final ok = await ref.read(actionsProvider).editCheckin(
          widget.details.checkin.id,
          rating: _rating,
          clearRating: _rating == null,
          note: notiz.isEmpty ? null : notiz,
          clearNote: notiz.isEmpty,
          servingStyle: _serving,
          clearServingStyle: _serving == null,
          volumeMl: _volumeMl,
          clearVolume: _volumeMl == null,
        );

    if (!mounted) return;
    if (!ok) {
      // Kann nur bei einem fremden Check-in passieren — dann hat die
      // Oberfläche ihn fälschlich als eigenen angeboten.
      messenger.showSnackBar(const SnackBar(
          content: Text('Das ist nicht dein Check-in.')));
      navigator.pop(false);
      return;
    }
    messenger.showSnackBar(
        const SnackBar(content: Text('Check-in geändert 🍺')));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final beer = widget.details.beer;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(beer.name, style: theme.textTheme.titleMedium),
          Text(widget.details.brewery.name,
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),

          Text('Bewertung', style: theme.textTheme.titleSmall),
          RatingInput(
            rating: _rating,
            onChanged: (wert) => setState(() => _rating = wert),
          ),
          const SizedBox(height: 16),

          Text('Notiz', style: theme.textTheme.titleSmall),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Wie war es?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),

          Text('Gebinde', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final s in ServingStyle.values)
                ChoiceChip(
                  label: Text(_servingLabel(s)),
                  selected: _serving == s,
                  // Nochmal tippen hebt die Auswahl auf — sonst ließe sich
                  // ein versehentlich gesetztes Gebinde nie mehr entfernen.
                  onSelected: (an) =>
                      setState(() => _serving = an ? s : null),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Text('Menge', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: [
              for (final ml in volumeChoicesMl)
                ChoiceChip(
                  label: Text(formatVolume(ml)),
                  selected: _volumeMl == ml,
                  onSelected: (an) =>
                      setState(() => _volumeMl = an ? ml : null),
                ),
            ],
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: _speichert ? null : _speichern,
            child: Text(_speichert ? 'Speichert …' : 'Änderung speichern'),
          ),
        ],
      ),
    );
  }
}

String _servingLabel(ServingStyle s) => switch (s) {
      ServingStyle.draft => 'vom Fass',
      ServingStyle.bottle => 'Flasche',
      ServingStyle.can => 'Dose',
      ServingStyle.growler => 'Growler',
    };
