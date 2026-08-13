import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/online/online_service.dart';
import '../../data/providers.dart';

const List<String> _avatarEmojis = [
  '🍺',
  '🍻',
  '🥨',
  '🧔',
  '👩',
  '🍀',
  '🔥',
  '🌊',
  '🦊',
  '🐻',
];

enum _AuthMode { signIn, signUp }

/// Konto-Screen (Online-Beta): Anmelden/Registrieren bzw. Konto-Übersicht.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  String _selectedEmoji = '🍺';
  bool _busy = false;
  String? _error;
  bool _needsConfirmation = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit(OnlineService online) async {
    setState(() {
      _busy = true;
      _error = null;
      _needsConfirmation = false;
    });

    final String? err;
    if (_mode == _AuthMode.signUp) {
      err = await online.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text,
        displayName: _displayNameController.text.trim().isEmpty
            ? _usernameController.text.trim()
            : _displayNameController.text.trim(),
        avatarEmoji: _selectedEmoji,
      );
    } else {
      err = await online.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;

    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mode == _AuthMode.signUp
              ? 'Willkommen! 🍻'
              : 'Angemeldet 🍻'),
        ),
      );
      context.pop();
      return;
    }
    setState(() {
      _busy = false;
      if (err == 'confirm') {
        _needsConfirmation = true;
        _mode = _AuthMode.signIn;
      } else {
        _error = err;
      }
    });
  }

  Future<void> _signOut(OnlineService online) async {
    setState(() => _busy = true);
    await online.signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Abgemeldet. Bis bald! 👋')));
  }

  @override
  Widget build(BuildContext context) {
    final onlineAsync = ref.watch(onlineServiceProvider);
    final user = ref.watch(onlineUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: onlineAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _OfflineInfo(),
        data: (online) {
          if (online == null) return const _OfflineInfo();
          if (user != null) return _buildAccount(online, user.email);
          return _buildAuthForm(online);
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Fall B: abgemeldet – Anmelden / Registrieren
  // --------------------------------------------------------------------------

  Widget _buildAuthForm(OnlineService online) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSignUp = _mode == _AuthMode.signUp;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_AuthMode>(
          segments: const [
            ButtonSegment(
              value: _AuthMode.signIn,
              label: Text('Anmelden'),
              icon: Icon(Icons.login),
            ),
            ButtonSegment(
              value: _AuthMode.signUp,
              label: Text('Registrieren'),
              icon: Icon(Icons.person_add_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (selection) => setState(() {
                    _mode = selection.first;
                    _error = null;
                  }),
        ),
        const SizedBox(height: 16),
        if (_needsConfirmation) ...[
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text('📬', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fast geschafft! Bestätige deine E-Mail und melde '
                      'dich dann an.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-Mail',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          enabled: !_busy,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Passwort',
            helperText: 'Mindestens 6 Zeichen',
            border: OutlineInputBorder(),
          ),
        ),
        if (isSignUp) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            enabled: !_busy,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Nutzername',
              helperText: '3–30 Zeichen: Kleinbuchstaben, Ziffern oder _',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayNameController,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Anzeigename',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Dein Avatar', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in _avatarEmojis)
                ChoiceChip(
                  label: Text(emoji),
                  selected: _selectedEmoji == emoji,
                  onSelected: _busy
                      ? null
                      : (_) => setState(() => _selectedEmoji = emoji),
                ),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () async => _submit(online),
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isSignUp ? 'Konto erstellen' : 'Anmelden'),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('oder', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () async => _googleSignIn(online),
          icon: const Text('G',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          label: const Text('Mit Google anmelden'),
        ),
        const SizedBox(height: 12),
        Text(
          '🔒 Deine Check-ins sind nur für bestätigte Freunde sichtbar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _googleSignIn(OnlineService online) async {
    setState(() => _busy = true);
    try {
      final err = await online.signInWithGoogle();
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
      // Bei Erfolg kehrt die App über den Deep-Link zurück; der
      // Auth-Stream schaltet die Ansicht dann automatisch um.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeUsername(OnlineService online) async {
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nutzername ändern'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            prefixText: '@',
            hintText: '3–30 Zeichen: a–z, 0–9, _',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    final err = await online.updateUsername(newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Nutzername geändert – Prost, @'
            '${newName.trim().toLowerCase()}! 🍻')));
    ref.invalidate(myRemoteProfileProvider);
  }

  // --------------------------------------------------------------------------
  // Fall C: angemeldet – Konto-Ansicht
  // --------------------------------------------------------------------------

  Widget _buildAccount(OnlineService online, String? email) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(myRemoteProfileProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            child: Text(
              profile?.avatarEmoji ?? '🍺',
              style: const TextStyle(fontSize: 40),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            profile?.displayName ?? 'BrewMate',
            style: theme.textTheme.headlineSmall,
          ),
        ),
        if (profile != null)
          Center(
            child: TextButton.icon(
              onPressed: () async => _changeUsername(online),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(
                '@${profile.username}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        if (profile?.accountNo != null)
          Center(
            child: Text(
              'Kontonummer #${profile!.accountNo} (unveränderlich)',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (profile != null && profile.hasPlaceholderUsername) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.primaryContainer,
            child: ListTile(
              leading: const Text('✏️', style: TextStyle(fontSize: 24)),
              title: const Text('Wähle deinen Nutzernamen'),
              subtitle: const Text(
                  'Dein Konto hat noch einen Platzhalter-Namen – so finden '
                  'dich Freunde schwer.'),
              onTap: () async => _changeUsername(online),
            ),
          ),
        ],
        if (email != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              email,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '🔒 Deine Check-ins sind nur für bestätigte Freunde sichtbar.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/friends'),
          icon: const Icon(Icons.group_outlined),
          label: const Text('Freunde verwalten'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () async => _signOut(online),
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------------
// Fall A: keine Supabase-Konfiguration
// ----------------------------------------------------------------------------

class _OfflineInfo extends StatelessWidget {
  const _OfflineInfo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🚧', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Online-Modus noch nicht aktiviert',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Der Online-Modus ist Teil der Beta – unser Server wird '
              'gerade eingerichtet. Sobald er bereit ist, kannst du dich '
              'hier registrieren und echte Freunde hinzufügen. Bis dahin '
              'läuft BrewMates komplett lokal auf deinem Gerät weiter.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
