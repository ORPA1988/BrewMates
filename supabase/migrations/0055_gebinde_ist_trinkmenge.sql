-- 0055: Die Gebindegröße am Barcode ist die **Trinkmenge**, nicht die
-- Verkaufseinheit.
--
-- ============================================================================
-- DER ANLASS
--
-- Beim Auffüllen fehlender Gebindegrößen (2026-09-05) hat Open Food
-- Facts zu vier EANs überhaupt eine Menge geliefert — und **drei davon
-- waren Mehrfachgebinde**:
--
--   9003400391632  „Hell (6er-Tragerl)"            3000 ml
--   9028800602775  „6-pack Zipfer Hell alkoholfrei" 2000 ml
--   4008948192012  „Jever Fun" (6er)               1980 ml
--
-- Das ist kein Fehler der Quelle: Eine EAN bezeichnet die
-- **Handelseinheit**, und ein Tragerl ist eine. Für BrewMates ist der
-- Wert aber etwas anderes — die App setzt ihn nach dem Scannen als
-- Füllmenge in den Check-in. Wer ein Tragerl scannt, trinkt eine
-- Flasche daraus, keine drei Liter.
--
-- Eingetragen wurde deshalb die Einzelflasche (3000/6 = 500 usw.). Damit
-- dieser Unterschied nicht bei der nächsten Datenpflege wieder
-- verlorengeht, steht er ab jetzt als Regel in der Datenbank.
--
-- ============================================================================
-- WARUM 1000 ML
--
-- Das ist der größte Wert, den die App überhaupt anbietet
-- (`volumeChoicesMl`; ein Growler zählt mit 1 l). Alles darüber ist
-- keine Trinkmenge mehr, sondern eine Verpackungsangabe.
--
-- **Der alte Check erlaubte 20 Liter.** Er war nie erreicht — live steht
-- die größte Angabe bei 500 ml (geprüft am 2026-09-05, 4 Zeilen), und in
-- den Community-Dateien liegt alles zwischen 250 und 750 ml. Die Grenze
-- verschärft also nichts Bestehendes; sie hält nur fest, was ohnehin
-- galt, bevor es das erste Mal jemand anders macht.
--
-- Die Regel gehört an den Server und nicht in die App: Eine Grenze, die
-- nur der Client kennt, umgeht der nächste Client.
-- ============================================================================

alter table public.beer_barcodes
  drop constraint if exists beer_barcodes_volume_ml_check;

alter table public.beer_barcodes
  add constraint beer_barcodes_volume_ml_check
  check (volume_ml is null or (volume_ml >= 100 and volume_ml <= 1000));

comment on column public.beer_barcodes.volume_ml is
  'Trinkmenge dieser Handelseinheit in Millilitern (100-1000). Bei einem '
  'Mehrfachgebinde die Groesse der Einzelflasche, nicht die Summe: Wer '
  'ein Tragerl scannt, trinkt eine Flasche daraus.';
