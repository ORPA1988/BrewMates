import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/online/online_service.dart';
import '../../data/providers.dart';

/// Bekannte Funktions-Vorschläge (Schlüssel → Icon + Anzeigename).
const List<({String key, String icon, String label})> _knownFeatures = [
  // Vertrauensstufen-Overrides (Migration 0013): setzen die automatische
  // Punkte-Stufe außer Kraft.
  (key: 'trust_level_2', icon: '🍺', label: 'Stufe Stammgast (Override)'),
  (key: 'trust_level_3', icon: '🎓', label: 'Stufe Bierkenner (Override)'),
  (key: 'edit_lock', icon: '🔒', label: 'Datenpflege sperren'),
  (key: 'premium', icon: '⭐', label: 'Premium'),
  (key: 'moderation', icon: '🛠', label: 'Moderation'),
  (key: 'beta_features', icon: '🧪', label: 'Beta-Funktionen'),
];

/// Admin-Bereich (Route /admin): Rollen und Funktionen anderer Nutzer
/// verwalten. Serverseitig via RLS abgesichert – die UI ist nur Komfort.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final _searchController = TextEditingController();
  final _customFeatureController = TextEditingController();

  List<RemoteProfile> _results = const [];
  bool _searching = false;

  RemoteProfile? _selected;
  bool _panelLoading = false;
  String? _selectedRole;
  Map<String, bool> _selectedFeatures = const {};

  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    _customFeatureController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Laden
  // --------------------------------------------------------------------------

  Future<void> _search(String query) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    if (query.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await online.friends.searchProfiles(query);
    if (!mounted) return;
    // Nur übernehmen, wenn die Eingabe inzwischen nicht geändert wurde.
    if (_searchController.text.trim() == query.trim()) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  void _select(RemoteProfile profile) {
    setState(() {
      _selected = profile;
      _selectedRole = null;
      _selectedFeatures = const {};
      _panelLoading = true;
    });
    // Panel-Daten asynchron nachladen (mit Stale-Guard).
    unawaited(_loadPanel(profile));
  }

  Future<void> _loadPanel(RemoteProfile profile) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null || !mounted) return;
    final role = await online.roleOf(profile.id);
    final features = await online.featuresOf(profile.id);
    if (!mounted || _selected?.id != profile.id) return;
    setState(() {
      _selectedRole = role;
      _selectedFeatures = features;
      _panelLoading = false;
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(isAdminProvider);
    ref.invalidate(myFeaturesProvider);
    final selected = _selected;
    if (selected != null) {
      setState(() => _panelLoading = true);
      await _loadPanel(selected);
    }
  }

  /// Eigene Provider auffrischen, wenn der Admin an sich selbst schraubt.
  Future<void> _invalidateMineIfSelf(String profileId) async {
    final online = await ref.read(onlineServiceProvider.future);
    if (!mounted || online?.currentUser?.id != profileId) return;
    ref.invalidate(isAdminProvider);
    ref.invalidate(myFeaturesProvider);
  }

  // --------------------------------------------------------------------------
  // Aktionen
  // --------------------------------------------------------------------------

  Future<void> _setRole(String? role) async {
    final profile = _selected;
    if (profile == null || _busy || role == _selectedRole) return;

    // Sicherheitsabfrage nur bei Admin-Vergabe und Admin-Entzug.
    final grantsAdmin = role == 'admin';
    final revokesAdmin = _selectedRole == 'admin' && role != 'admin';
    if (grantsAdmin || revokesAdmin) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bist du sicher?'),
          content: Text(grantsAdmin
              ? 'Wirklich Admin-Rechte vergeben? '
                  '@${profile.username} kann dann selbst Rollen und '
                  'Funktionen aller Nutzer ändern.'
              : 'Wirklich Admin-Rechte entziehen? '
                  '@${profile.username} verliert sofort alle Admin-Rechte.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(grantsAdmin ? 'Vergeben' : 'Entziehen'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    final online = await ref.read(onlineServiceProvider.future);
    final err = online == null
        ? 'Keine Verbindung.'
        : await online.adminSetRole(profile.id, role);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Rolle gespeichert')));
    if (err == null) {
      setState(() => _panelLoading = true);
      await _loadPanel(profile);
      await _invalidateMineIfSelf(profile.id);
    }
  }

  Future<void> _setFeature(String feature, bool enabled) async {
    final profile = _selected;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    final online = await ref.read(onlineServiceProvider.future);
    final err = online == null
        ? 'Keine Verbindung.'
        : await online.adminSetFeature(profile.id, feature, enabled);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ??
            (enabled
                ? 'Funktion „$feature" aktiviert'
                : 'Funktion „$feature" deaktiviert'))));
    if (err == null) {
      _customFeatureController.clear();
      setState(() => _panelLoading = true);
      await _loadPanel(profile);
      await _invalidateMineIfSelf(profile.id);
    }
  }

  // --------------------------------------------------------------------------
  // UI
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);

    // Guard: nur für Admins – Laden/Fehler dürfen nicht crashen.
    if (isAdminAsync.isLoading && !isAdminAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('🛡 Admin-Bereich')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (isAdminAsync.valueOrNull != true) return _buildNotAdmin(context);

    return _buildAdmin(context);
  }

  Widget _buildNotAdmin(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('🛡 Admin-Bereich')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⛔', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                'Nur für Admins',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Dieser Bereich ist Administratoren vorbehalten. '
                'Geh einfach zurück – alles andere in BrewMates steht dir '
                'weiter offen.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdmin(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('🛡 Admin-Bereich')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Rollen und Funktionen wirken serverseitig (RLS) – '
              'Änderungen gelten sofort.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Text('🏆', style: TextStyle(fontSize: 24)),
                title: const Text('Challenges verwalten'),
                subtitle: const Text(
                    'Herausforderungen mit Belohnungs-Abzeichen anlegen'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/admin/challenges'),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Text('🛡', style: TextStyle(fontSize: 24)),
                title: const Text('Meldungen bearbeiten'),
                subtitle: Text(switch (ref.watch(offeneMeldungenProvider)) {
                  AsyncData(value: final n) when n > 0 =>
                    n == 1 ? '1 offene Meldung' : '$n offene Meldungen',
                  AsyncData() => 'Nichts offen',
                  _ => 'Gemeldete Profile ansehen und abschließen',
                }),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/moderation'),
              ),
            ),
            const SizedBox(height: 16),

            // ------------------------------------------------------------------
            // Nutzer verwalten
            // ------------------------------------------------------------------
            Text('Nutzer verwalten', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Nutzername suchen (min. 3 Zeichen)',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (value) async => _search(value),
            ),
            const SizedBox(height: 4),
            for (final profile in _results)
              Card(
                color: _selected?.id == profile.id
                    ? scheme.secondaryContainer
                    : null,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(profile.avatarEmoji,
                        style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(profile.displayName),
                  subtitle: Text('@${profile.username}'),
                  trailing: _selected?.id == profile.id
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  onTap: () => _select(profile),
                ),
              ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              _buildSelectedPanel(theme, scheme, _selected!),
            ],
            const SizedBox(height: 24),

            // ------------------------------------------------------------------
            // Dein Konto
            // ------------------------------------------------------------------
            Text('Dein Konto', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildMyAccount(theme, scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPanel(
      ThemeData theme, ColorScheme scheme, RemoteProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(profile.avatarEmoji,
                      style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.displayName,
                          style: theme.textTheme.titleMedium),
                      Text(
                        '@${profile.username}'
                        '${profile.accountNo != null ? '  ·  Konto #${profile.accountNo}' : ''}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_panelLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Rolle -------------------------------------------------------
              Text('Rolle', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Keine'),
                    selected: _selectedRole == null,
                    onSelected:
                        _busy ? null : (_) async => _setRole(null),
                  ),
                  ChoiceChip(
                    label: const Text('Moderator'),
                    selected: _selectedRole == 'moderator',
                    onSelected:
                        _busy ? null : (_) async => _setRole('moderator'),
                  ),
                  ChoiceChip(
                    label: const Text('Admin'),
                    selected: _selectedRole == 'admin',
                    onSelected:
                        _busy ? null : (_) async => _setRole('admin'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Funktionen --------------------------------------------------
              Text('Funktionen', style: theme.textTheme.titleSmall),
              for (final known in _knownFeatures)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Text(known.icon,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(known.label),
                  subtitle: Text(known.key),
                  value: _selectedFeatures[known.key] ?? false,
                  onChanged: _busy
                      ? null
                      : (enabled) async => _setFeature(known.key, enabled),
                ),
              // Weitere bereits geschaltete Funktionen des Nutzers, damit
              // alles sichtbar bleibt.
              for (final entry in _selectedFeatures.entries)
                if (!_knownFeatures.any((k) => k.key == entry.key))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.extension_outlined),
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: _busy
                        ? null
                        : (enabled) async =>
                            _setFeature(entry.key, enabled),
                  ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customFeatureController,
                      enabled: !_busy,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'weitere Funktion (a–z, 0–9, _)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _busy
                        ? null
                        : () async => _setFeature(
                            _customFeatureController.text, true),
                    child: const Text('Aktivieren'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMyAccount(ThemeData theme, ColorScheme scheme) {
    final myFeatures =
        ref.watch(myFeaturesProvider).valueOrNull ?? const <String, bool>{};
    final enabled = [
      for (final entry in myFeatures.entries)
        if (entry.value) entry.key,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛡 Du bist Admin.'),
            const SizedBox(height: 8),
            if (enabled.isEmpty)
              Text(
                'Keine Funktionen freigeschaltet.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final feature in enabled)
                    Chip(label: Text(_featureChipLabel(feature))),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _featureChipLabel(String feature) {
    for (final known in _knownFeatures) {
      if (known.key == feature) return '${known.icon} $feature';
    }
    return '🔧 $feature';
  }
}
