import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/checkin_facts_mapping.dart';
import '../../data/providers.dart';
import '../../domain/challenges.dart';
import '../../domain/statistics.dart';

/// Provider der Profil-Übersicht (Funktion 47) — eigene Datei statt Anbau
/// an die Sammelstelle `data/providers.dart` (siehe docs/11).

/// Die Aufschlüsselung hinter den Zahlen-Kacheln: alle eigenen Check-ins,
/// über die ganze Zeit, in alle verfügbaren Aufteilungen zerlegt.
///
/// **Warum „Alles" und kein Zeitraum:** Die Kachel sagt „12 Stile" ohne
/// Einschränkung. Ein Blatt, das darunter nur das laufende Jahr
/// aufschlüsselt, widerspricht der Zahl, auf die man getippt hat.
///
/// **Warum das nicht teuer ist:** Riverpod rechnet einen `Provider` erst,
/// wenn ihn jemand liest. Gelesen wird er nur vom geöffneten Blatt — der
/// Reiter selbst baut sich auf, ohne neun Aufschlüsselungen zu erzeugen,
/// von denen acht niemand ansieht.
final profilAufschluesselungProvider = Provider<CheckinStats>((ref) {
  final alle = ref.watch(alleEigenenCheckinsProvider).valueOrNull ?? const [];
  return computeStats(
    alle.facts,
    now: ref.watch(clockProvider).valueOrNull ?? DateTime.now(),
    period: const StatsPeriod.preset(StatsRange.all),
  );
});

/// Die Challenge, die gerade läuft — für die Zweitzeile im Schnellzugriff.
///
/// Läuft mehr als eine, gewinnt die **am weitesten fortgeschrittene**:
/// Sie ist die, bei der sich das Hinsehen am ehesten lohnt. Gleichstand
/// entscheidet die Reihenfolge, in der die Liste kommt — eine zweite
/// Sortierregel wäre Genauigkeit, die niemand bemerkt.
///
/// `null` heißt: nichts läuft, oder die Liste ist noch nicht geladen.
/// Beides sagt die Kachel mit demselben Satz, weil beides für den
/// Menschen dasselbe bedeutet: hier gibt es gerade nichts zu tun.
final laufendeChallengeProvider = Provider<ChallengeProgress?>((ref) {
  final alle = ref.watch(challengeProgressProvider).valueOrNull;
  if (alle == null || alle.isEmpty) return null;

  final jetzt = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
  final offen = [
    for (final p in alle)
      if (!p.completed && p.def.isActiveAt(jetzt)) p,
  ];
  if (offen.isEmpty) return null;

  return offen.reduce((a, b) => b.fraction > a.fraction ? b : a);
});

/// Wann war der letzte eigene Check-in? `null` = noch keiner.
///
/// Gelesen aus [alleEigenenCheckinsProvider] und nicht aus dem Tagebuch:
/// Das Tagebuch ist durchsuchbar, und während einer Suche wäre sein
/// erster Eintrag nicht der neueste, sondern der erste Treffer.
final letzterCheckinProvider = Provider<DateTime?>((ref) {
  final alle = ref.watch(alleEigenenCheckinsProvider).valueOrNull;
  if (alle == null || alle.isEmpty) return null;
  return alle
      .map((d) => d.checkin.createdAt)
      .reduce((a, b) => b.isAfter(a) ? b : a);
});
