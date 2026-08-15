import 'package:flutter/material.dart';

/// Ein anklickbarer Vorschlag unterhalb einer Eingabezeile.
class SuggestEntry {
  const SuggestEntry({
    required this.titel,
    required this.onTap,
    this.untertitel,
    this.fuehrend,
    this.vomServer = false,
  });

  final String titel;
  final String? untertitel;

  /// Emoji oder Symbol links — rein zur Orientierung.
  final String? fuehrend;

  /// Kommt der Vorschlag aus der Nachladung vom Server?
  ///
  /// Wird sichtbar markiert. Wer gerade offline ein Bier anlegt, soll
  /// nicht rätseln, warum die Liste beim Kollegen länger war.
  final bool vomServer;

  final VoidCallback onTap;
}

/// Live-Vorschläge direkt unter der Eingabezeile.
///
/// Der Zweck ist nicht Tipparbeit, sondern **Duplikatvermeidung**. Zwei
/// Einträge für dasselbe Bier trennen Bewertungen, Abzeichen und
/// Statistik dauerhaft, und niemand merkt es im Moment des Anlegens —
/// deshalb muss der vorhandene Eintrag auftauchen, bevor jemand den
/// Namen zu Ende getippt hat.
///
/// Anklickbar, nicht nur lesbar: Eine Liste, die „gibt es schon" sagt
/// und den Menschen dann trotzdem selbst suchen lässt, verhindert das
/// Duplikat nicht — sie erklärt es nur hinterher.
///
/// Liegt in `widgets/`, weil Bier- und Gasthaus-Formular sie beide
/// brauchen und Features einander nicht importieren dürfen.
class SuggestList extends StatelessWidget {
  const SuggestList({
    super.key,
    required this.eintraege,
    this.titel = 'Gibt es das schon?',
    this.maximal = 5,
  });

  final List<SuggestEntry> eintraege;
  final String titel;
  final int maximal;

  @override
  Widget build(BuildContext context) {
    if (eintraege.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final sichtbar = eintraege.take(maximal).toList();

    return Card(
      margin: const EdgeInsets.only(top: 4),
      color: theme.colorScheme.secondaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Text(titel, style: theme.textTheme.labelLarge),
          ),
          for (final e in sichtbar)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: e.fuehrend == null
                  ? null
                  : Text(e.fuehrend!, style: const TextStyle(fontSize: 20)),
              title: Text(e.titel),
              subtitle: e.untertitel == null ? null : Text(e.untertitel!),
              trailing: e.vomServer
                  ? Icon(Icons.cloud_outlined,
                      size: 18, color: theme.colorScheme.outline)
                  : null,
              onTap: e.onTap,
            ),
          if (eintraege.length > sichtbar.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'und ${eintraege.length - sichtbar.length} weitere — '
                'tippe weiter, um einzugrenzen.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
