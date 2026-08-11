import 'package:intl/intl.dart';

/// Relative Zeitangabe im Feed-Stil („vor 5 min", „gestern").
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'vor ${diff.inHours} h';
  if (diff.inDays == 1) return 'gestern';
  if (diff.inDays < 7) return 'vor ${diff.inDays} Tagen';
  return DateFormat('d. MMM yyyy', 'de').format(time);
}

String formatDate(DateTime time) =>
    DateFormat('EEEE, d. MMMM yyyy', 'de').format(time);

String formatTime(DateTime time) => DateFormat('HH:mm').format(time);

/// Verbleibende Zeit bis [until], z. B. „2 h 15 min".
String remaining(DateTime until) {
  final diff = until.difference(DateTime.now());
  if (diff.isNegative) return 'abgelaufen';
  if (diff.inHours >= 1) return '${diff.inHours} h ${diff.inMinutes % 60} min';
  return '${diff.inMinutes} min';
}
