/// Eine erzeugte Tabelle beim Menschen abliefern.
///
/// **Warum das eine Plattformweiche braucht:** `dart:io` ist in
/// `app/lib/` verboten (die CI erzwingt `flutter build web`), und
/// `package:web` gibt es auf der VM nicht. Also dasselbe Muster wie bei
/// der Datenbankverbindung (`data/db/connection/`): eine Schnittstelle,
/// zwei Umsetzungen, bedingter Import.
///
/// **Was auf welcher Plattform passiert:**
///
/// | Plattform | Ergebnis |
/// |---|---|
/// | Web | echter Datei-Download über einen Blob |
/// | Android, Desktop | Text in der Zwischenablage |
///
/// Die Zwischenablage ist kein Notbehelf aus Bequemlichkeit: Eine Datei
/// auf Android abzulegen hieße `dart:io` plus ein Teilen-Paket, und ein
/// neues Plugin ist in dieser Toolchain die teuerste Änderung, die es
/// gibt (siehe `CLAUDE.md`, gepinnte Pakete). Eingefügt in eine
/// Tabellenkalkulation kommt dabei dasselbe heraus.
library;

export 'datei_ausgeben_stub.dart'
    if (dart.library.js_interop) 'datei_ausgeben_web.dart';
