/// 🔥 Wochen-Serie (pur, testbar): Anzahl aufeinanderfolgender Wochen
/// (Mo–So) mit mindestens einem Check-in. Bewusst WOCHEN statt Tage —
/// „Streaks mit Augenmaß" (Wettbewerbsanalyse): kein täglicher
/// Trinkanreiz. Die laufende Woche ohne Check-in bricht die Serie noch
/// nicht (Kulanz bis Sonntag).
library;

/// Wochenindex relativ zu Montag, 3.1.2000 (einem Montag).
int _weekKey(DateTime d) {
  final monday = DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: d.weekday - DateTime.monday));
  return monday.difference(DateTime(2000, 1, 3)).inDays ~/ 7;
}

int weeklyStreak(Iterable<DateTime> checkinDates, DateTime now) {
  final weeks = checkinDates.map(_weekKey).toSet();
  if (weeks.isEmpty) return 0;
  var week = _weekKey(now);
  if (!weeks.contains(week)) {
    // Diese Woche noch nichts? Serie zählt ab letzter Woche weiter.
    week -= 1;
    if (!weeks.contains(week)) return 0;
  }
  var streak = 0;
  while (weeks.contains(week)) {
    streak++;
    week--;
  }
  return streak;
}
