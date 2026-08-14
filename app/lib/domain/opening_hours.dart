import 'dart:convert';

/// Strukturierte Öffnungszeiten (Migration 0015): pure Logik, testbar.
///
/// JSON-Format (Supabase `venues.opening_hours_json`):
/// `[{"d": 1, "von": "11:00", "bis": "24:00"}, …]` — d = Wochentag 1–7
/// (Mo–So), mehrere Intervalle pro Tag erlaubt, `bis <= von` bedeutet:
/// bis in den Folgetag (über Mitternacht).
class OpeningInterval {
  const OpeningInterval({
    required this.weekday,
    required this.from,
    required this.to,
  });

  /// 1 = Montag … 7 = Sonntag (wie `DateTime.weekday`).
  final int weekday;

  /// Minuten seit Mitternacht (0–1439).
  final int from;

  /// Minuten seit Mitternacht; 1440 = „24:00", `to <= from` = Folgetag.
  final int to;

  /// Endet das Intervall erst am Folgetag?
  bool get overMidnight => to <= from;

  Map<String, dynamic> toJson() =>
      {'d': weekday, 'von': _clock(from), 'bis': _clock(to)};

  @override
  bool operator ==(Object other) =>
      other is OpeningInterval &&
      other.weekday == weekday &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(weekday, from, to);
}

const weekdayShortNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

/// „HH:MM" → Minuten seit Mitternacht (24:00 → 1440); null bei Murks.
int? parseClock(String raw) {
  final parts = raw.trim().split(':');
  if (parts.isEmpty || parts.length > 2) return null;
  final h = int.tryParse(parts[0]);
  final m = parts.length == 2 ? int.tryParse(parts[1]) : 0;
  if (h == null || m == null || h < 0 || h > 24 || m < 0 || m > 59) {
    return null;
  }
  final minutes = h * 60 + m;
  return minutes > 1440 ? null : minutes;
}

String _clock(int minutes) =>
    '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Anzeige-Uhrzeit, z. B. „11:00", „24:00".
String formatClock(int minutes) => _clock(minutes);

/// JSON (String oder bereits dekodierte Liste) → Intervalle.
/// Fehlerhafte Einträge werden still übersprungen; null/kaputt → leer.
List<OpeningInterval> parseOpeningHours(Object? json) {
  Object? decoded = json;
  if (json is String) {
    if (json.trim().isEmpty) return const [];
    try {
      decoded = jsonDecode(json);
    } catch (_) {
      return const [];
    }
  }
  if (decoded is! List) return const [];
  final result = <OpeningInterval>[];
  for (final entry in decoded) {
    if (entry is! Map) continue;
    final d = entry['d'];
    final from = entry['von'] is String ? parseClock(entry['von'] as String) : null;
    final to = entry['bis'] is String ? parseClock(entry['bis'] as String) : null;
    if (d is! int || d < 1 || d > 7 || from == null || to == null) continue;
    result.add(OpeningInterval(weekday: d, from: from, to: to));
  }
  result.sort((a, b) => a.weekday != b.weekday
      ? a.weekday.compareTo(b.weekday)
      : a.from.compareTo(b.from));
  return result;
}

/// Intervalle → JSON-Liste (für Supabase jsonb bzw. `jsonEncode`).
List<Map<String, dynamic>> encodeOpeningHours(
        List<OpeningInterval> intervals) =>
    [for (final i in intervals) i.toJson()];

String _rangeClock(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h' : _clock(minutes);
}

/// Erzeugt den Freitext automatisch, z. B.
/// „Mo–Fr 11–24, Sa 10–2, So Ruhetag". Tage ohne Intervall = Ruhetag;
/// ganz ohne Intervalle → leerer String.
String formatOpeningHours(List<OpeningInterval> intervals) {
  if (intervals.isEmpty) return '';
  // Pro Wochentag die Intervall-Signatur (z. B. "11–24" oder "10–2, 17–23").
  final byDay = <int, String>{};
  for (var d = 1; d <= 7; d++) {
    final spans = intervals.where((i) => i.weekday == d).toList();
    byDay[d] = spans.isEmpty
        ? 'Ruhetag'
        : spans
            .map((i) => '${_rangeClock(i.from)}–${_rangeClock(i.to)}')
            .join(', ');
  }
  // Aufeinanderfolgende Tage mit gleicher Signatur zusammenfassen.
  final parts = <String>[];
  var start = 1;
  for (var d = 2; d <= 8; d++) {
    if (d == 8 || byDay[d] != byDay[start]) {
      final label = start == d - 1
          ? weekdayShortNames[start - 1]
          : '${weekdayShortNames[start - 1]}–${weekdayShortNames[d - 2]}';
      parts.add('$label ${byDay[start]}');
      start = d;
    }
  }
  return parts.join(', ');
}

/// Ist zu [now] geöffnet? Berücksichtigt Intervalle über Mitternacht.
bool isOpenAt(List<OpeningInterval> intervals, DateTime now) =>
    _activeInterval(intervals, now) != null;

OpeningInterval? _activeInterval(
    List<OpeningInterval> intervals, DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  for (final i in intervals) {
    if (!i.overMidnight) {
      if (now.weekday == i.weekday && minutes >= i.from && minutes < i.to) {
        return i;
      }
    } else {
      // Über Mitternacht: heute ab `von` ODER am Folgetag bis `bis`.
      final nextDay = i.weekday % 7 + 1;
      if ((now.weekday == i.weekday && minutes >= i.from) ||
          (now.weekday == nextDay && minutes < i.to)) {
        return i;
      }
    }
  }
  return null;
}

/// Nächster Öffnungsbeginn nach [now]; null ohne Intervalle.
DateTime? nextOpening(List<OpeningInterval> intervals, DateTime now) {
  if (intervals.isEmpty) return null;
  final today = DateTime(now.year, now.month, now.day);
  for (var add = 0; add <= 7; add++) {
    final day = today.add(Duration(days: add));
    DateTime? best;
    for (final i in intervals) {
      if (i.weekday != day.weekday) continue;
      final candidate = day.add(Duration(minutes: i.from));
      if (!candidate.isAfter(now)) continue;
      if (best == null || candidate.isBefore(best)) best = candidate;
    }
    if (best != null) return best;
  }
  return null;
}

/// Status-Zeile für die UI: „● Jetzt geöffnet · bis 24:00" bzw.
/// „○ Geschlossen · öffnet Mo 11:00". null ohne strukturierte Zeiten.
({bool open, String label})? openingStatus(
    List<OpeningInterval> intervals, DateTime now) {
  if (intervals.isEmpty) return null;
  final active = _activeInterval(intervals, now);
  if (active != null) {
    return (open: true, label: '● Jetzt geöffnet · bis ${_clock(active.to)}');
  }
  final next = nextOpening(intervals, now);
  if (next == null) return (open: false, label: '○ Geschlossen');
  final sameDay =
      next.year == now.year && next.month == now.month && next.day == now.day;
  final day = sameDay ? 'heute' : weekdayShortNames[next.weekday - 1];
  return (
    open: false,
    label: '○ Geschlossen · öffnet $day '
        '${_clock(next.hour * 60 + next.minute)}',
  );
}
