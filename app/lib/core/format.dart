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

/// Dauer als Auswahl-Beschriftung, z. B. „30 min", „1 Stunde", „5 Stunden".
String formatDuration(Duration d) {
  if (d.inMinutes < 60) return '${d.inMinutes} min';
  final hours = d.inHours;
  final rest = d.inMinutes % 60;
  final base = hours == 1 ? '1 Stunde' : '$hours Stunden';
  return rest == 0 ? base : '$base $rest min';
}

/// Zur Auswahl stehende Füllmengen in Millilitern.
const volumeChoicesMl = <int>[200, 250, 330, 400, 500, 1000];

/// Füllmenge als Beschriftung, z. B. „0,33 l" oder „1 l".
String formatVolume(int ml) {
  if (ml % 1000 == 0) return '${ml ~/ 1000} l';
  final litres = (ml / 1000).toStringAsFixed(2);
  // Deutsche Schreibweise, ohne nachlaufende Null: 0,33 l bzw. 0,5 l.
  return '${litres.replaceAll('.', ',').replaceFirst(RegExp(r'0$'), '')} l';
}

/// Litermenge für Statistiken, z. B. „12,4 l".
String formatLitres(double litres) =>
    '${litres.toStringAsFixed(1).replaceAll('.', ',')} l';

/// UUID-Erkennung: nutzererstellte Datensätze tragen UUIDs, redaktionelle
/// Community-Daten sprechende IDs (z. B. `at-stiegl`). Entscheidet u. a.,
/// ob ein Datensatz in-app bearbeitbar ist.
final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

bool isUuid(String value) => _uuidPattern.hasMatch(value);
