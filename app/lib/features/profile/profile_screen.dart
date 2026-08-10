import 'package:flutter/material.dart';

/// Profil: Statistiken, Abzeichen, Tagebuch, Wunschliste, Einstellungen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Column(
              children: [
                CircleAvatar(radius: 40, child: Text('🍻')),
                SizedBox(height: 8),
                Text('Dein Name', style: TextStyle(fontSize: 20)),
                Text('@du', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.8,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: const [
              _StatTile(label: 'Biere', value: '0'),
              _StatTile(label: 'Stile', value: '0'),
              _StatTile(label: 'Brauereien', value: '0'),
              _StatTile(label: 'Länder', value: '0'),
              _StatTile(label: 'Gemeinsame Abende', value: '0'),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Abzeichen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO v1
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: const Text('Tagebuch'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO v1
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Wunschliste'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO v1
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Einstellungen'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: Privatsphäre, Benachrichtigungen, Konto
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
