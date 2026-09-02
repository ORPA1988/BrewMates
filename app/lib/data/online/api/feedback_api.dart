import 'package:flutter/foundation.dart' show debugPrint;

import '../models.dart';
import 'online_api.dart';

/// Fehler melden, Wünsche äußern, Roadmap lesen — Testphase.
///
/// Der Tester soll mit zwei Tipps loswerden, was ihm auffällt, und
/// **sehen, was daraus wird**: Jede Meldung hat einen Status und
/// optional eine kurze Antwort. Fremde Meldungen sieht niemand (RLS);
/// die Roadmap sehen alle, auch ohne Konto.
class FeedbackApi extends OnlineApi {
  const FeedbackApi(super.client, super.nutzer);

  /// Ist die Testphasen-Funktion eingeschaltet? Ohne Anmeldung lesbar,
  /// ohne Netz `false` — dann verschwinden die Knöpfe einfach.
  Future<bool> enabled() async {
    try {
      final row = await client
          .from('app_config')
          .select('value')
          .eq('key', 'feedback_enabled')
          .maybeSingle();
      return row?['value'] == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Meldung abschicken. null = ok, sonst ein Satz für den Menschen.
  Future<String?> submit({
    required FeedbackKind kind,
    required String body,
    required String appVersion,
    required String platform,
  }) async {
    final me = currentUser;
    if (me == null) return 'Dafür musst du angemeldet sein.';
    final text = body.trim();
    if (text.length < 3) return 'Bitte ein paar Worte mehr.';
    try {
      await client.from('feedback').insert({
        'profile_id': me.id,
        'kind': kind.name,
        'body': text,
        'app_version': appVersion,
        'platform': platform,
      });
      return null;
    } catch (e) {
      debugPrint('feedback.submit: $e');
      return 'Konnte nicht gesendet werden – keine Verbindung?';
    }
  }

  /// Eigene Meldungen, neueste zuerst.
  Future<List<FeedbackItem>> mine() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('feedback')
          .select('id, kind, body, status, reply, created_at, updated_at, '
              'roadmap:roadmap_items(title)')
          .eq('profile_id', me.id)
          .order('created_at', ascending: false);
      return [for (final r in rows) FeedbackItem.fromRow(r)];
    } catch (e) {
      debugPrint('feedback.mine: $e');
      return const [];
    }
  }

  /// Roadmap, nach Reihenfolge. Für alle lesbar.
  Future<List<RoadmapItem>> roadmap() async {
    try {
      final rows = await client
          .from('roadmap_items')
          .select('id, title, summary, status, sort_order, updated_at')
          .order('sort_order');
      return [for (final r in rows) RoadmapItem.fromRow(r)];
    } catch (e) {
      debugPrint('feedback.roadmap: $e');
      return const [];
    }
  }
}
