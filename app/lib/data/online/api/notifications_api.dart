import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'online_api.dart';

/// Die Glocke: Benachrichtigungen aus `notifications`.
///
/// Die Tabelle gibt es seit 0001, beschrieben wurde sie erstmals mit
/// 0031 — per Trigger, in der Datenbank. Der Client **liest** hier nur.
/// Er legt nie selbst eine Benachrichtigung an: Ein Client kann vergessen,
/// abstuerzen oder alt sein; die Datenbank sieht jede Anfrage.
///
/// Zwei Wege zum selben Inhalt: [incoming] liefert neue Zeilen live ueber
/// Realtime, [unread] holt den Bestand. Der Live-Weg ist ein Zusatz — faellt
/// er aus, laedt der 30-Sekunden-Takt weiter. Nichts haengt daran, dass
/// Realtime verbunden ist.
class NotificationsApi extends OnlineApi {
  const NotificationsApi(super.client, super.nutzer);

  /// Ungelesene Benachrichtigungen, neueste zuerst.
  Future<List<RemoteNotification>> unread() async {
    final me = currentUser;
    if (me == null) return const [];
    try {
      final rows = await client
          .from('notifications')
          .select('id, type, actor_id, subject_type, subject_id, created_at, '
              'actor:profiles!notifications_actor_id_fkey('
              '${OnlineApi.profileCols})')
          .eq('recipient_id', me.id)
          .isFilter('read_at', null)
          .order('created_at', ascending: false)
          .limit(50);
      return [for (final r in rows) RemoteNotification.fromRow(r)];
    } catch (_) {
      return const [];
    }
  }

  /// Als gelesen markieren. Best effort: Ein Fehlschlag hier ist kein
  /// Grund, den Menschen zu behelligen — die Zeile bleibt dann ungelesen.
  Future<void> markRead(Iterable<String> ids) async {
    final me = currentUser;
    if (me == null || ids.isEmpty) return;
    try {
      await client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('recipient_id', me.id)
          .inFilter('id', ids.toList());
    } catch (_) {}
  }

  /// Neue Benachrichtigungen fuer den angemeldeten Nutzer, live.
  ///
  /// Realtime respektiert RLS: Es kommen nur eigene Zeilen an. Der Filter
  /// auf `recipient_id` steht trotzdem da — er spart dem Server das
  /// Ausprobieren jeder fremden Zeile gegen die Policy.
  ///
  /// Ohne Anmeldung ein leerer Stream, der sofort schliesst.
  Stream<RemoteNotification> incoming() {
    final me = currentUser;
    if (me == null) return const Stream.empty();

    final controller = StreamController<RemoteNotification>();
    final channel = client
        .channel('notifications:${me.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: me.id,
          ),
          callback: (payload) {
            // Die Realtime-Zeile traegt keinen Join. Der Akteur wird
            // nachgeladen — best effort, die Meldung kommt auch ohne Namen.
            unawaited(_mitAkteur(payload.newRecord).then((n) {
              if (!controller.isClosed) controller.add(n);
            }));
          },
        );
    channel.subscribe();
    controller.onCancel = () => client.removeChannel(channel);
    return controller.stream;
  }

  Future<RemoteNotification> _mitAkteur(Map<String, dynamic> row) async {
    final actorId = row['actor_id'] as String?;
    RemoteProfile? actor;
    if (actorId != null) {
      try {
        final p = await client
            .from('profiles')
            .select(OnlineApi.profileCols)
            .eq('id', actorId)
            .maybeSingle();
        if (p != null) actor = RemoteProfile.fromRow(p);
      } catch (_) {}
    }
    return RemoteNotification.fromRow({...row, 'actor': null}, actor: actor);
  }
}
