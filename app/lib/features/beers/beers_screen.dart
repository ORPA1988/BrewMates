import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/demo_data.dart';

/// Entdecken: Bier-Datenbank durchsuchen, Wunschliste, Empfehlungen.
class BeersScreen extends StatelessWidget {
  const BeersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const beers = [DemoData.hopfengold, DemoData.nebelwerfer];

    return Scaffold(
      appBar: AppBar(title: const Text('Entdecken')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Bier, Brauerei oder Stil suchen …',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          for (final b in beers)
            Card(
              child: ListTile(
                leading: const Text('🍺', style: TextStyle(fontSize: 28)),
                title: Text(b.name),
                subtitle: Text('${b.style} · ${b.brewery.name}, '
                    '${b.brewery.city} · ${b.abv} %'),
                trailing: IconButton(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  tooltip: 'Auf die Wunschliste',
                  onPressed: () {}, // TODO: Wunschliste
                ),
                onTap: () => context.push('/checkin'),
              ),
            ),
        ],
      ),
    );
  }
}
