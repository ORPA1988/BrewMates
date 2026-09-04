import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import '../../core/app_update.dart';
import '../../core/config.dart';
import '../../data/online/online_service.dart';
import '../../data/providers.dart';
import '../../widgets/update_dialog.dart';

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
  bool _usernamePromptShown = false;

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
          content: Text(
              _mode == _AuthMode.signUp ? 'Willkommen! 🍻' : 'Angemeldet 🍻'),
        ),
      );
      // Kommt man über das Anmelde-Gate, gibt es nichts zu poppen.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
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
    // Zuerst das Geraetetoken loeschen, dann abmelden — in dieser
    // Reihenfolge. Nach dem Abmelden greift RLS nicht mehr fuer die eigene
    // Zeile, und das Telefon klingelte weiter fuer ein fremdes Konto.
    final token = ref.read(registeredPushTokenProvider);
    if (token != null) {
      await online.devices.unregister(token);
      ref.read(registeredPushTokenProvider.notifier).state = null;
    }
    await online.signOut();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Abgemeldet. Bis bald! 👋')));
  }

  /// Konto löschen (Play-Store-Pflicht): doppelte Bestätigung, dann
  /// serverseitige Löschung über die delete_my_account-RPC.
  Future<void> _deleteAccount(OnlineService online) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konto wirklich löschen?'),
        content: const Text(
            'Dein Profil, deine Check-ins, Erfolge, Wunschliste und '
            'Freundschaften werden auf dem Server unwiderruflich '
            'gelöscht; Beiträge zur gemeinsamen Bier- und Gasthaus-'
            'Datenbank bleiben anonymisiert erhalten. Die lokalen Daten '
            'auf diesem Gerät bleiben bestehen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Endgültig löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final error = await online.deleteMyAccount();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ?? 'Konto gelöscht. Danke, dass du dabei '
            'warst! 🍻')));
  }

  @override
  Widget build(BuildContext context) {
    final onlineAsync = ref.watch(onlineServiceProvider);
    final user = ref.watch(onlineUserProvider).valueOrNull;

    // Frisch per Google angemeldet? Dann hat das Konto noch einen
    // Platzhalter-Nutzernamen — einmalig direkt zur Namenswahl einladen,
    // statt zu warten, bis jemand die Hinweis-Karte entdeckt.
    ref.listen(myRemoteProfileProvider, (_, next) {
      final profile = next.valueOrNull;
      final online = ref.read(onlineServiceProvider).valueOrNull;
      if (profile != null &&
          profile.hasPlaceholderUsername &&
          !_usernamePromptShown &&
          online != null) {
        _usernamePromptShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _changeUsername(online);
        });
      }
    });

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
        // Beta-Gate: die App gehört eindeutig zu einem Konto.
        Card(
          color: scheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('🍻', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Willkommen bei BrewMates! Für die Beta brauchst du ein '
                    'Konto – einmal anmelden genügt, du bleibst dauerhaft '
                    'eingeloggt.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
          obscureText: !_passwortSichtbar,
          decoration: InputDecoration(
            labelText: 'Passwort',
            helperText: 'Mindestens 6 Zeichen',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _passwortSichtbar ? 'Verbergen' : 'Anzeigen',
              icon: Icon(_passwortSichtbar
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: () =>
                  setState(() => _passwortSichtbar = !_passwortSichtbar),
            ),
          ),
        ),
        if (!isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // Gab es bis 2026-09-02 nicht. Mit dem Beta-Gate hiess ein
              // vergessenes Passwort: ausgesperrt, neues Konto, alle
              // Freundschaften weg.
              onPressed: _busy ? null : () async => _passwortVergessen(online),
              child: const Text('Passwort vergessen?'),
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
        // Nur, was der Server auch eingerichtet hat (0046). Solange die
        // Liste lädt, steht Google da — der Weg, den es seit 0.9.2 gibt.
        for (final verfahren in ref.watch(anmeldeverfahrenProvider).valueOrNull ??
            const [Anmeldeverfahren.google]) ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () async => _oauthAnmeldung(online, verfahren),
            icon: _verfahrensZeichen(verfahren),
            label: Text(verfahren.knopfText),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        Text(
          '🔒 Deine Check-ins sind nur für bestätigte Freunde sichtbar.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// Sync-Status: Check-ins, die offline entstanden sind, überträgt die App
  /// automatisch (Anmeldung, neuer Check-in, 5-Minuten-Retry). Die Karte
  /// zeigt den Stand und bietet einen manuellen Anstoß als Fallback.
  Widget _buildSyncStatus(OnlineService online) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pending = ref.watch(pendingCheckinUploadProvider).valueOrNull;
    if (pending == null || pending.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '🔄 Deine Check-ins werden automatisch mit deinem Konto '
            'abgeglichen – auch wenn sie unterwegs ohne Internet entstehen.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🔄 Abgleich ausstehend', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${pending.length} '
              '${pending.length == 1 ? 'Check-in wartet' : 'Check-ins warten'} '
              'auf die Übertragung ins Konto. Das passiert automatisch, '
              'sobald wieder Verbindung besteht.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () async => _syncNow(online),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Jetzt synchronisieren'),
            ),
          ],
        ),
      ),
    );
  }

  bool _passwortSichtbar = false;

  Future<void> _passwortVergessen(OnlineService online) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final fehler = await online.resetPassword(_emailController.text);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(SnackBar(
      content: Text(fehler ??
          'Wenn es ein Konto mit dieser Adresse gibt, ist eine E-Mail zum '
              'Zurücksetzen unterwegs. Schau auch im Spam-Ordner nach.'),
      duration: const Duration(seconds: 7),
    ));
  }

  Future<void> _syncNow(OnlineService online) async {
    setState(() => _busy = true);
    try {
      final pending =
          await ref.read(pendingCheckinUploadProvider.future) ?? const [];
      if (pending.isEmpty) return;
      final uploaded = await online.checkins.uploadLocalCheckins(pending);
      if (!mounted) return;
      ref.invalidate(pendingCheckinUploadProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(uploaded == null
            ? 'Gerade keine Verbindung – die App überträgt automatisch, '
                'sobald es wieder klappt.'
            : '$uploaded Check-in${uploaded == 1 ? '' : 's'} übertragen 🍻'),
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Manueller Update-Check (der automatische läuft beim App-Start).
  Future<void> _checkForUpdates() async {
    setState(() => _busy = true);
    try {
      final client = http.Client();
      UpdateInfo? update;
      try {
        update = await checkForUpdate(client,
            currentVersion: AppConfig.appVersion);
      } finally {
        client.close();
      }
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Du bist aktuell ✓ (${AppConfig.appVersion})')));
      } else {
        await showUpdateDialog(context, update);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Das Zeichen auf dem Knopf.
  ///
  /// Apple und Facebook haben ein Material-Symbol, die übrigen nicht —
  /// für die steht der Anfangsbuchstabe. **Kein Logo aus dem Netz:** Die
  /// App lädt zur Laufzeit nichts von fremden Servern (Leitplanke aus
  /// `docs/11`), und ein Markenlogo mitzuliefern brauchte die Erlaubnis
  /// des Markeninhabers. Ein Buchstabe braucht sie nicht.
  Widget _verfahrensZeichen(Anmeldeverfahren verfahren) => switch (verfahren) {
        Anmeldeverfahren.apple => const Icon(Icons.apple),
        Anmeldeverfahren.facebook => const Icon(Icons.facebook),
        _ => Text(
            verfahren.name.substring(0, 1),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
      };

  Future<void> _oauthAnmeldung(
      OnlineService online, Anmeldeverfahren verfahren) async {
    setState(() => _busy = true);
    try {
      final err = await online.signInWithProvider(verfahren);
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
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
        content: Text(err ??
            'Nutzername geändert – Prost, @'
                '${newName.trim().toLowerCase()}! 🍻')));
    ref.invalidate(myRemoteProfileProvider);
  }

  // --------------------------------------------------------------------------
  // Fall C: angemeldet – Konto-Ansicht
  // --------------------------------------------------------------------------

  /// Systemmeldungen im Browser — nur dort, wo es sie gibt.
  ///
  /// **Warum ein Knopf und nicht automatisch beim Anmelden:** Die Frage
  /// muss aus einer echten Geste kommen. Firefox verlangt das seit
  /// Version 72, Chrome ignoriert ungefragte Anfragen zunehmend. Eine
  /// automatische Anfrage beim Start würde also oft still abgelehnt — und
  /// verbraucht dabei den einen Versuch, den man hat.
  ///
  /// Auf Android, Windows und in Tests gibt die stumme Fassung
  /// `nicht-verfuegbar` zurück, und hier steht schlicht nichts.
  Widget _browserBenachrichtigungen(ThemeData theme, ColorScheme scheme) {
    final fenster = ref.watch(browserfensterProvider);
    final stand = fenster.erlaubnis;
    if (stand == Browserfenster.nichtVerfuegbar) return const SizedBox.shrink();

    Widget hinweis(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            text,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        );

    return switch (stand) {
      'granted' => hinweis(
          'Benachrichtigungen sind erlaubt. Du bekommst sie, solange '
          'BrewMates in einem Tab offen ist — auch wenn du gerade woanders '
          'bist.'),
      // Zurücknehmen kann die App das nicht: Eine abgelehnte Erlaubnis
      // erneut zu erfragen, verweigert der Browser. Also den Weg nennen.
      'denied' => hinweis(
          'Dein Browser lässt BrewMates keine Benachrichtigungen zeigen. '
          'Du kannst das über das Schloss-Symbol links neben der Adresse '
          'ändern.'),
      _ => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        await fenster.erlaubnisAnfragen();
                        // Der Stand steckt im Browser, nicht in einem
                        // Provider — also neu bauen lassen.
                        if (mounted) setState(() {});
                      },
                icon: const Icon(Icons.notifications_none, size: 18),
                label: const Text('Benachrichtigungen erlauben'),
              ),
              const SizedBox(height: 4),
              Text(
                'Zeigt dir neue Anfragen und Beacons, solange BrewMates in '
                'einem Tab offen ist. Ist der Tab zu, kommt nichts — dafür '
                'gibt es die Android-App.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildAccount(OnlineService online, String? email) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = ref.watch(myRemoteProfileProvider).valueOrNull;
    final myFeatures =
        ref.watch(myFeaturesProvider).valueOrNull ?? const <String, bool>{};
    final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;

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
        const SizedBox(height: 8),
        _buildSyncStatus(online),
        const SizedBox(height: 16),
        if (myFeatures['premium'] == true) ...[
          Card(
            color: scheme.tertiaryContainer,
            child: ListTile(
              leading: const Text('⭐', style: TextStyle(fontSize: 24)),
              title: Text(
                'Premium aktiv',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: scheme.onTertiaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/admin'),
            icon: const Text('🛡', style: TextStyle(fontSize: 18)),
            label: const Text('Admin-Bereich'),
          ),
          const SizedBox(height: 8),
        ],
        // Moderatoren (Stufe 4) sind keine Admins: Sie sollen Meldungen
        // bearbeiten, ohne den Bereich zu betreten, in dem Rollen und
        // Funktionen anderer Leute hängen. Für Admins steht der Weg
        // zusätzlich im Admin-Bereich.
        if (ref.watch(canModerateProvider) && !isAdmin) ...[
          FilledButton.tonalIcon(
            onPressed: () => context.push('/moderation'),
            icon: const Text('🛡', style: TextStyle(fontSize: 18)),
            label: const Text('Meldungen bearbeiten'),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: () => context.push('/friends'),
          icon: const Icon(Icons.group_outlined),
          label: const Text('Freunde verwalten'),
        ),
        const SizedBox(height: 8),
        _browserBenachrichtigungen(theme, scheme),
        OutlinedButton.icon(
          onPressed: _busy ? null : () async => _checkForUpdates(),
          icon: const Icon(Icons.system_update_alt, size: 18),
          label: const Text('Nach Updates suchen'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : () async => _signOut(online),
          icon: const Icon(Icons.logout),
          label: const Text('Abmelden'),
        ),
        const SizedBox(height: 8),
        Text(
          'Du bleibst angemeldet, bis du dich abmeldest – auch nach '
          'App-Updates.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: _busy ? null : () async => _deleteAccount(online),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          icon: const Icon(Icons.delete_forever_outlined, size: 18),
          label: const Text('Konto löschen'),
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
