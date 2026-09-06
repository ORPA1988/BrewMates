import 'dart:typed_data';

/// Ohne Browser gibt es keinen Weg, der ohne neues Plugin auskommt.
/// `false` heißt: Die Oberfläche muss etwas anderes sagen.
Future<bool> bildAusgeben(Uint8List bytes, String dateiname) async => false;
