part of '../providers.dart';

/// Der Push-Zugang des Geraets. Auf Web, Windows und in Tests die stumme
/// Fassung — Tests ueberschreiben den Provider mit einem Doppel.
final pushServiceProvider =
    FutureProvider<PushService>((ref) => FirebasePushService.initialize());

/// Das zuletzt beim Server hinterlegte Token dieses Geraets.
///
/// Gebraucht beim Abmelden: Die Zeile in `devices` muss **vor** dem
/// Abmelden weg, danach laesst RLS sie nicht mehr anfassen — und das
/// Telefon klingelte weiter fuer ein Konto, das dort nicht mehr ist.
final registeredPushTokenProvider = StateProvider<String?>((ref) => null);

/// Haelt das Geraetetoken beim Server aktuell, solange jemand angemeldet
/// ist.
///
/// Drei Ausloeser, ein Ziel (`devices.register`):
///   1. Anmeldung — Erlaubnis einholen, Token holen, hinterlegen.
///   2. Token-Wechsel durch FCM — neue Fassung hinterlegen, sonst geht der
///      naechste Push ins Leere.
///   3. (Vordergrund-Nachricht: kein Register, nur Listen entwerten —
///      Realtime hat das meist schon erledigt, doppelt schadet nicht.)
///
/// Alles best effort. Ein Fehlschlag hier kostet Push, nie die App.
final pushRegistrationProvider = Provider<void>((ref) {
  final user = ref.watch(onlineUserProvider).valueOrNull;
  if (user == null) return;

  final subs = <StreamSubscription<dynamic>>[];
  ref.onDispose(() {
    for (final s in subs) {
      unawaited(s.cancel());
    }
  });

  unawaited(() async {
    final push = await ref.read(pushServiceProvider.future);
    final online = await ref.read(onlineServiceProvider.future);
    if (online == null) return;

    Future<void> hinterlegen(String token) async {
      final ok = await online.devices.register(token);
      if (ok) ref.read(registeredPushTokenProvider.notifier).state = token;
    }

    await push.requestPermission();
    final token = await push.token();
    if (token != null) await hinterlegen(token);

    subs.add(push.tokenRefreshed.listen(hinterlegen));
    subs.add(push.foregroundMessages.listen((_) {
      ref.invalidate(friendRequestsProvider);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(unreadNotificationsProvider);
    }));
  }());
});
