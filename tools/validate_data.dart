// Prüft die Community-Datenbank in `app/assets/data/`.
//
// **Wozu:** Diese acht Dateien sind der Inhalt der App. Sie werden
// redaktionell gepflegt — künftig auch von Menschen oder Werkzeugen, die
// den Code nicht kennen. Ein Tippfehler in einer `brewery_id` erzeugt ein
// Bier ohne Brauerei, ein doppelter Barcode schickt den Scanner auf das
// **falsche** Bier. Beides fällt beim Lesen nicht auf und in der App erst
// dem Nutzer.
//
// Aufruf: `dart tools/validate_data.dart`
// Rückgabe 0 = sauber, 1 = Befunde.

import 'dart:convert';
import 'dart:io';

const laender = ['at', 'by', 'de', 'ch'];

/// Erlaubter Host für Etikettenbilder.
///
/// Wir hosten keine Bilder, wir verlinken auf Open Food Facts (CC-BY-SA,
/// siehe DATENHERKUNFT.md). Ein Link auf eine Brauerei-Webseite wäre eine
/// Urheberrechtsfrage, keine Geschmacksfrage.
const bildHost = 'images.openfoodfacts.org';

/// Obergrenze aus Migration 0023. Was länger ist, lehnt der Server ab.
const storyMax = 1200;

void main() {
  final basis = Directory('app/assets/data').existsSync()
      ? 'app/assets/data'
      : 'assets/data';
  final befunde = <String>[];

  final brauereien = <String, String>{}; // id -> Datei
  final biere = <String, String>{};
  final barcodes = <String, String>{}; // barcode -> Bier-ID

  Map<String, dynamic> lies(String datei) {
    final f = File('$basis/$datei');
    if (!f.existsSync()) {
      befunde.add('$datei fehlt');
      return {};
    }
    try {
      return json.decode(f.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      befunde.add('$datei ist kein gültiges JSON: $e');
      return {};
    }
  }

  void kopfPruefen(String datei, Map<String, dynamic> d) {
    if (d['version'] is! int) befunde.add('$datei: `version` fehlt oder ist keine Zahl');
    final u = d['updated'];
    if (u is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(u)) {
      befunde.add('$datei: `updated` fehlt oder ist kein Datum (JJJJ-MM-TT)');
    }
  }

  // --- Brauereien zuerst: Biere verweisen auf sie -------------------------
  for (final land in laender) {
    final datei = 'breweries-$land.json';
    final d = lies(datei);
    if (d.isEmpty) continue;
    kopfPruefen(datei, d);
    final liste = d['breweries'];
    if (liste is! List) {
      befunde.add('$datei: `breweries` fehlt oder ist keine Liste');
      continue;
    }
    for (final e in liste) {
      final b = e as Map<String, dynamic>;
      final id = b['id'];
      if (id is! String || id.isEmpty) {
        befunde.add('$datei: Brauerei ohne `id`');
        continue;
      }
      if (brauereien.containsKey(id)) {
        befunde.add('Brauerei-ID doppelt: `$id` in $datei und '
            '${brauereien[id]}');
      }
      brauereien[id] = datei;

      final erwartet = land == 'by' ? 'de-by-' : '$land-';
      if (!id.startsWith(erwartet)) {
        befunde.add('$datei: `$id` sollte mit `$erwartet` beginnen — '
            'die Herkunft steckt in der ID');
      }
      for (final pflicht in ['name', 'city', 'country']) {
        if (b[pflicht] is! String || (b[pflicht] as String).trim().isEmpty) {
          befunde.add('$datei/$id: `$pflicht` fehlt');
        }
      }
      final lat = b['latitude'], lng = b['longitude'];
      if (lat != null && lng != null) {
        if (lat is! num || lng is! num) {
          befunde.add('$datei/$id: Koordinaten sind keine Zahlen');
        } else if (lat < 45 || lat > 56 || lng < 5 || lng > 18) {
          // Grob DACH. Ein vertauschtes Paar landet zuverlässig daneben.
          befunde.add('$datei/$id: Koordinaten liegen außerhalb des '
              'DACH-Raums ($lat, $lng) — vertauscht?');
        }
      }
      final story = b['story'];
      if (story != null &&
          (story is! String || story.length > storyMax)) {
        befunde.add('$datei/$id: `story` fehlt als Text oder ist länger '
            'als $storyMax Zeichen (Migration 0023 lehnt das ab)');
      }
    }
  }

  // --- Biere ---------------------------------------------------------------
  for (final land in laender) {
    final datei = 'beers-$land.json';
    final d = lies(datei);
    if (d.isEmpty) continue;
    kopfPruefen(datei, d);
    final liste = d['beers'];
    if (liste is! List) {
      befunde.add('$datei: `beers` fehlt oder ist keine Liste');
      continue;
    }
    for (final e in liste) {
      final b = e as Map<String, dynamic>;
      final id = b['id'];
      if (id is! String || id.isEmpty) {
        befunde.add('$datei: Bier ohne `id`');
        continue;
      }
      if (biere.containsKey(id)) {
        befunde.add('Bier-ID doppelt: `$id` in $datei und ${biere[id]}');
      }
      biere[id] = datei;

      final bid = b['brewery_id'];
      if (bid is! String || !brauereien.containsKey(bid)) {
        befunde.add('$datei/$id: `brewery_id` `$bid` gibt es nicht — '
            'das Bier hätte keine Brauerei');
      }
      for (final pflicht in ['name', 'style']) {
        if (b[pflicht] is! String || (b[pflicht] as String).trim().isEmpty) {
          befunde.add('$datei/$id: `$pflicht` fehlt');
        }
      }
      if (b['is_alcohol_free'] is! bool) {
        befunde.add('$datei/$id: `is_alcohol_free` fehlt oder ist kein '
            'Ja/Nein');
      }
      final abv = b['abv'];
      if (abv != null && (abv is! num || abv < 0 || abv > 20)) {
        befunde.add('$datei/$id: `abv` $abv ist unplausibel');
      }
      if (abv is num && abv > 0.5 && b['is_alcohol_free'] == true) {
        befunde.add('$datei/$id: als alkoholfrei markiert, aber $abv % vol');
      }
      final r = b['community_rating'];
      if (r != null && (r is! num || r < 1 || r > 5)) {
        befunde.add('$datei/$id: `community_rating` $r liegt außerhalb 1–5');
      }
      final bild = b['image_url'];
      if (bild != null) {
        if (bild is! String || !bild.startsWith('https://$bildHost/')) {
          befunde.add('$datei/$id: `image_url` zeigt nicht auf $bildHost — '
              'wir hosten keine Bilder und verlinken nur Open Food Facts '
              '(Lizenzfrage, siehe DATENHERKUNFT.md)');
        }
      }
      final story = b['story'];
      if (story != null && (story is! String || story.length > storyMax)) {
        befunde.add('$datei/$id: `story` zu lang oder kein Text');
      }

      // Gebindegröße je Barcode: Sie MUSS zu einem Code dieses Biers
      // gehören. Eine Größe an einer fremden oder erfundenen EAN wäre
      // schlimmer als keine — sie füllt den Check-in mit einer falschen
      // Menge, und niemand rechnet damit nach.
      final vols = b['barcode_volumes'];
      if (vols != null) {
        if (vols is! Map) {
          befunde.add('$datei/$id: `barcode_volumes` ist keine Zuordnung');
        } else {
          final eigene = ((b['barcodes'] as List?) ?? const [])
              .whereType<String>()
              .toSet();
          vols.forEach((ean, ml) {
            if (!eigene.contains(ean)) {
              befunde.add('$datei/$id: Größe für `$ean`, aber dieser '
                  'Barcode gehört nicht zu diesem Bier');
            }
            if (ml is! int || ml <= 0 || ml > 20000) {
              befunde.add('$datei/$id: Größe `$ml` für `$ean` ist '
                  'unplausibel');
            }
          });
        }
      }

      final codes = b['barcodes'];
      if (codes != null) {
        if (codes is! List) {
          befunde.add('$datei/$id: `barcodes` ist keine Liste');
        } else {
          for (final c in codes) {
            if (c is! String || !RegExp(r'^\d{8,14}$').hasMatch(c)) {
              befunde.add('$datei/$id: Barcode `$c` ist keine 8–14-stellige '
                  'Ziffernfolge');
              continue;
            }
            // Der teuerste Fehler im ganzen Bestand: Ein Barcode, der auf
            // zwei Biere zeigt, führt den Scanner auf das falsche.
            if (barcodes.containsKey(c) && barcodes[c] != id) {
              befunde.add('Barcode `$c` gehört zu zwei Bieren: '
                  '`${barcodes[c]}` und `$id` — der Scanner träfe das '
                  'falsche');
            }
            barcodes[c] = id;
          }
        }
      }
    }
  }

  // --- Verwaiste Brauereien sind kein Fehler, aber einen Hinweis wert ------
  final genutzt = <String>{};
  for (final land in laender) {
    final d = lies('beers-$land.json');
    final liste = d['beers'];
    if (liste is List) {
      for (final e in liste) {
        final bid = (e as Map<String, dynamic>)['brewery_id'];
        if (bid is String) genutzt.add(bid);
      }
    }
  }
  final ohneBier = brauereien.keys.where((k) => !genutzt.contains(k)).toList();

  stdout.writeln('Bestand: ${biere.length} Biere, ${brauereien.length} '
      'Brauereien, ${barcodes.length} Barcodes');
  if (ohneBier.isNotEmpty) {
    stdout.writeln('Hinweis: ${ohneBier.length} Brauereien ohne ein '
        'einziges Bier — ${ohneBier.take(8).join(", ")}'
        '${ohneBier.length > 8 ? " …" : ""}');
  }

  if (befunde.isEmpty) {
    stdout.writeln('Keine Befunde.');
    return;
  }
  stderr.writeln('\n${befunde.length} Befund(e):');
  for (final b in befunde) {
    stderr.writeln('  - $b');
  }
  exit(1);
}
