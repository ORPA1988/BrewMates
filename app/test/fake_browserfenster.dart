import 'dart:async';

import 'package:brewmates/data/push/browserfenster.dart';

/// Ein Browserfenster, das der Test stellt.
///
/// Die `Notification`-API selbst lässt sich im Widget-Test nicht
/// betreiben — sie braucht einen echten Browser und eine erteilte
/// Erlaubnis. Prüfbar ist die **Verzweigung** davor, und genau die stellt
/// dieser Doppelgänger nach: Sichtbarkeit, Erlaubnisstand, Installation
/// und der gemerkte Wegwisch-Zustand sind hier Felder, die der Test setzt.
///
/// Voreingestellt ist der übliche Fall am Rechner: im Browser, Meldungen
/// möglich, noch nicht gefragt, nicht installiert.
class FakesFenster implements Browserfenster {
  final _sichtbarkeit = StreamController<bool>.broadcast();
  bool _sichtbar = true;

  /// Was [zeige] angezeigt hätte, in der Reihenfolge des Aufrufs.
  final List<({String text, String? tag})> gezeigt = [];

  /// Welche Hinweise als weggewischt gelten — der Test darf hineinsehen.
  final Set<String> weggewischt = {};

  @override
  String erlaubnis = 'default';

  @override
  bool imBrowser = true;

  @override
  bool alsAppInstalliert = false;

  void sichtbarSetzen(bool wert) {
    _sichtbar = wert;
    _sichtbarkeit.add(wert);
  }

  void dispose() => _sichtbarkeit.close();

  @override
  bool get benachrichtigungenMoeglich =>
      erlaubnis != Browserfenster.nichtVerfuegbar;

  @override
  Future<String> erlaubnisAnfragen() async => erlaubnis;

  @override
  bool get sichtbar => _sichtbar;

  @override
  Stream<bool> get sichtbarkeit => _sichtbarkeit.stream;

  @override
  bool hinweisWeggewischt(String schluessel) =>
      weggewischt.contains(schluessel);

  @override
  void hinweisWegwischen(String schluessel) => weggewischt.add(schluessel);

  @override
  void zeige({
    required String text,
    String? tag,
    void Function()? beiKlick,
  }) =>
      gezeigt.add((text: text, tag: tag));
}
