import 'dart:async';

import 'package:brewmates/data/push/push_service.dart';

/// Steuerbares Push-Doppel: liefert ein Token, kann es „wechseln" und
/// Vordergrund-Nachrichten vortaeuschen.
class FakePushService implements PushService {
  FakePushService({this.aktuellesToken = 'tok-1'});

  String? aktuellesToken;
  final List<String> aufrufe = [];
  final _refresh = StreamController<String>.broadcast();
  final _vordergrund = StreamController<void>.broadcast();

  void tokenWechseln(String neu) {
    aktuellesToken = neu;
    _refresh.add(neu);
  }

  void nachrichtImVordergrund() => _vordergrund.add(null);

  @override
  Future<String?> token() async {
    aufrufe.add('token');
    return aktuellesToken;
  }

  @override
  Stream<String> get tokenRefreshed => _refresh.stream;

  @override
  Future<bool> requestPermission() async {
    aufrufe.add('requestPermission');
    return true;
  }

  @override
  Stream<void> get foregroundMessages => _vordergrund.stream;
}
