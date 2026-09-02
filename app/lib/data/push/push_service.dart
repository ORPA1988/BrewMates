import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;

/// Push-Zugang des Geraets (Firebase Cloud Messaging), plattformbewusst.
///
/// **Was Push hier ist — und was nicht.** FCM weckt das Geraet. Mehr
/// nicht. Die Nachricht selbst ist inhaltsleer („Du hast eine neue
/// Benachrichtigung"), Namen und Anfragen bleiben in Supabase, RLS gilt.
/// Google erfaehrt, *dass* ein Geraet geweckt wurde, nicht *warum*.
///
/// **Nur Android.** Web, Windows und Tests kommen ohne Firebase aus; dort
/// liefert [token] null und alles Weitere bleibt still. Kein Konfigurations-
/// fehler darf den App-Start verhindern: BrewMates funktioniert ohne Konto
/// und ohne Netz vollstaendig, Push ist ein Zusatz.
///
/// Abstrakt, damit Tests ein Doppel unterschieben koennen — die echte
/// Klasse braucht ein Geraet mit Play-Diensten.
abstract class PushService {
  /// Aktuelles Geraetetoken, oder null wenn Push hier nicht geht.
  Future<String?> token();

  /// Feuert, wenn FCM das Token austauscht — dann muss die neue Fassung
  /// zum Server, sonst geht der naechste Push ins Leere.
  Stream<String> get tokenRefreshed;

  /// Erlaubnis einholen (Android 13+). Ergebnis nur informativ; ohne
  /// Erlaubnis kommt kein Token, und das ist die ehrliche Antwort.
  Future<bool> requestPermission();

  /// Nachrichten, die ankommen, waehrend die App im Vordergrund ist. Dann
  /// zeigt Android nichts von selbst — die App hat aber ohnehin Realtime,
  /// also reicht es, die Listen zu entwerten.
  Stream<void> get foregroundMessages;
}

class FirebasePushService implements PushService {
  FirebasePushService._();

  static bool get _unterstuetzt =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initialisiert Firebase — oder auch nicht. Gibt eine stumme Fassung
  /// zurueck, wo Push nicht geht. Wirft nie: Ein fehlendes
  /// google-services.json auf einem Entwicklerrechner darf den Start nicht
  /// verhindern, es darf nur Push kosten. Der Fehler wird geloggt, damit
  /// er nicht *still* ist.
  static Future<PushService> initialize() async {
    if (!_unterstuetzt) return const NoPush();
    try {
      await Firebase.initializeApp();
      return FirebasePushService._();
    } catch (e) {
      debugPrint('Push nicht verfuegbar: $e');
      return const NoPush();
    }
  }

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  @override
  Future<String?> token() async {
    try {
      return await _fm.getToken();
    } catch (e) {
      debugPrint('Push-Token nicht erhalten: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefreshed => _fm.onTokenRefresh;

  @override
  Future<bool> requestPermission() async {
    try {
      final s = await _fm.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<void> get foregroundMessages =>
      FirebaseMessaging.onMessage.map((_) {});
}

/// Die stumme Fassung: nichts zu tun, nichts zu melden. Oeffentlich, weil
/// Tests sie als Ausgangspunkt nehmen.
class NoPush implements PushService {
  const NoPush();
  @override
  Future<String?> token() async => null;
  @override
  Stream<String> get tokenRefreshed => const Stream.empty();
  @override
  Future<bool> requestPermission() async => false;
  @override
  Stream<void> get foregroundMessages => const Stream.empty();
}
