import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/emoji_font.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'widgets/update_required_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  runApp(const ProviderScope(child: BrewMatesApp()));
  // Web: Farb-Emoji-Font nachladen (blockiert den Start nicht).
  unawaited(loadColorEmojiFont());
}

class BrewMatesApp extends ConsumerWidget {
  const BrewMatesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Einmalig: Community-Datenbank importieren und still aktualisieren.
    ref.watch(communityBootstrapProvider);
    // Push-Token beim Server halten, solange jemand angemeldet ist.
    ref.watch(pushRegistrationProvider);

    // Riegel für zu alte Versionen (Migration 0029). `valueOrNull ?? false`
    // ist die entscheidende Zeile: Solange die Antwort aussteht oder
    // ausbleibt — offline, abgemeldet, Server weg — läuft die App normal
    // weiter. Gesperrt wird nur bei einer klaren Ansage des Servers.
    if (ref.watch(updatePflichtProvider).valueOrNull ?? false) {
      return MaterialApp(
        title: 'BrewMates',
        theme: BrewTheme.light,
        darkTheme: BrewTheme.dark,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        home: const UpdateRequiredScreen(),
      );
    }

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'BrewMates',
      theme: BrewTheme.light,
      darkTheme: BrewTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
