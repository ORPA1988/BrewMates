import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/providers.dart';
import 'checkin_card.dart';

/// Check-in-Liste, die nur baut, was zu sehen ist, und beim Erreichen des
/// Endes die nächste Seite nachlädt.
///
/// Der Vorgänger war `ListView(children: [...])` — der baut jede Karte
/// sofort, auch die achthundert, die niemand ansieht. Bei den Datenmengen
/// der Beta fiel das nicht auf; ein Tagebuch wächst aber ein Leben lang.
///
/// Nachgeladen wird ohne ScrollController: Sobald der Fußbereich gebaut
/// wird, ist das Ende in Sichtweite — genau dann wächst das Fenster.
class PagedCheckinList extends ConsumerWidget {
  const PagedCheckinList({
    super.key,
    required this.items,
    required this.limitProvider,
    this.showAuthor = true,
    this.header,
  });

  final List<CheckinDetails> items;
  final StateProvider<int> limitProvider;
  final bool showAuthor;
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limit = ref.watch(limitProvider);
    // Eine volle Seite bedeutet: Es könnte mehr geben.
    final maybeMore = items.length >= limit;
    final headerCount = header != null ? 1 : 0;

    return ListView.builder(
      // Immer ziehbar, auch wenn die Liste kürzer als der Bildschirm ist:
      // Sonst nimmt ein Feed mit drei Einträgen die Auffrisch-Geste nicht
      // an, und das sieht aus, als täte die App nichts.
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: headerCount + items.length + 1,
      itemBuilder: (context, index) {
        if (headerCount == 1 && index == 0) return header!;
        final itemIndex = index - headerCount;
        if (itemIndex < items.length) {
          return CheckinCard(
            details: items[itemIndex],
            showAuthor: showAuthor,
          );
        }
        // Fußbereich: nachladen oder Ruhe geben.
        if (!maybeMore) return const SizedBox(height: 24);
        // Zustand nie während des Baus ändern.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final current = ref.read(limitProvider);
          if (current == limit) {
            ref.read(limitProvider.notifier).state = current + feedPageSize;
          }
        });
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
