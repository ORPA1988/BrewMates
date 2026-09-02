
import 'online_api.dart';

/// Geraetetoken fuer Push — Tabelle `devices` (seit 0001, erstmals genutzt
/// mit 0.10.4).
///
/// Ein Token bezeichnet **eine Installation auf einem Geraet**, nicht den
/// Menschen. Wer sich auf zwei Telefonen anmeldet, hat zwei Zeilen; wer
/// sich abmeldet, muss seine Zeile loswerden — sonst klingelt das Telefon
/// weiter fuer ein Konto, das dort nicht mehr angemeldet ist. Das ist der
/// Grund, warum [unregister] vor dem Abmelden laeuft und nicht danach:
/// Nach dem Abmelden greift RLS nicht mehr fuer die eigene Zeile.
class DevicesApi extends OnlineApi {
  const DevicesApi(super.client, super.nutzer);

  /// Token hinterlegen oder auffrischen. Idempotent: `(profile_id,
  /// push_token)` ist eindeutig, ein zweiter Aufruf aktualisiert nur
  /// `last_seen_at`.
  Future<bool> register(String token, {String platform = 'android'}) async {
    final me = currentUser;
    if (me == null || token.isEmpty) return false;
    try {
      await client.from('devices').upsert({
        'profile_id': me.id,
        'platform': platform,
        'push_token': token,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'profile_id,push_token');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Token dieses Geraets entfernen — **vor** dem Abmelden aufrufen.
  Future<bool> unregister(String token) async {
    final me = currentUser;
    if (me == null || token.isEmpty) return false;
    try {
      await client
          .from('devices')
          .delete()
          .eq('profile_id', me.id)
          .eq('push_token', token);
      return true;
    } catch (_) {
      return false;
    }
  }
}
