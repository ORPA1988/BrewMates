/// Ein erzeugtes Bild beim Menschen abliefern.
///
/// Dieselbe Weiche wie `datei_ausgeben.dart`, nur für Bytes statt Text:
/// `dart:io` ist in `app/lib/` verboten, `package:web` gibt es auf der
/// VM nicht — also eine Schnittstelle, zwei Umsetzungen, bedingter
/// Import.
///
/// **Was auf welcher Plattform passiert:**
///
/// | Plattform | Ergebnis |
/// |---|---|
/// | Web | echter Datei-Download (PNG) |
/// | Android, Desktop | nichts — die Oberfläche sagt „Bildschirmfoto" |
///
/// Dass Android leer ausgeht, ist kein Versehen: Ein Bild dort zu
/// speichern oder zu teilen hieße `dart:io` plus ein Teilen-Paket, und
/// ein neues Plugin ist in dieser Toolchain die teuerste Änderung, die
/// es gibt (CLAUDE.md, gepinnte Pakete). Ein Bildschirmfoto liefert
/// dasselbe Ergebnis mit einem Griff, den ohnehin jeder kennt — und der
/// Rückblick ist genau dafür gebaut: eine Seite, die auf einen
/// Bildschirm passt.
library;

export 'bild_ausgeben_stub.dart'
    if (dart.library.js_interop) 'bild_ausgeben_web.dart';
