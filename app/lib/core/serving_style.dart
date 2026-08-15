/// Gebinde, in dem ein Bier getrunken wurde.
///
/// Liegt in `core/`, nicht in `data/db/database.dart`, obwohl Drift die
/// Spalte darüber abbildet. Der Grund ist die Schichtregel: Es ist ein
/// reines Wert-Enum ohne jeden Datenbankbezug, aber solange es in der
/// Datenbankdatei stand, musste jeder, der es braucht, `data/` importieren
/// — auch `domain/statistics.dart`, das die Datenbank gar nicht kennen
/// darf. Aus `core/` dürfen `domain/` und `data/` es gleichermaßen lesen,
/// ohne dass eine Schicht die andere anzieht.
///
/// Die Reihenfolge ist bedeutungslos; gespeichert wird der **Name**
/// (`textEnum` in Drift, Textspalte in Supabase). Werte deshalb nie
/// umbenennen — das entwertet den Bestand. Neue nur anhängen.
library;

enum ServingStyle { draft, bottle, can, growler }
