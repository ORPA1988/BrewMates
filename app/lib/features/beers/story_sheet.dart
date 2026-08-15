import 'package:flutter/material.dart';

/// Anzeige einer Hintergrundgeschichte.
///
/// Bewusst schlicht: Die Geschichte selbst soll wirken, nicht ihre
/// Verpackung.
class StorySection extends StatelessWidget {
  const StorySection({super.key, required this.story, required this.title});

  /// Die Geschichte. Fehlt sie, entsteht **kein** leerer Bereich — eine
  /// Überschrift ohne Inhalt sieht nach Fehler aus.
  final String? story;

  final String title;

  @override
  Widget build(BuildContext context) {
    final text = story?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📖', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Zeigt eine Geschichte als Blatt von unten — für den Hinweis beim
/// ersten Scan, wo kein Platz für einen ganzen Abschnitt ist.
Future<void> showStorySheet(
  BuildContext context, {
  required String title,
  required String story,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📖 $title', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(story, style: theme.textTheme.bodyLarge),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Schließen'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
