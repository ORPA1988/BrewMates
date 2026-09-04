-- 0048: Der Termin in der Zukunft — Teil 1 von 2 (nur Typ und Spalte).
--
-- ============================================================================
-- WARUM ZWEI DATEIEN
--
-- `alter type ... add value` legt den Wert an, aber Postgres lässt ihn in
-- **derselben Transaktion** nicht mehr benutzen: „unsafe use of new value
-- of enum type". Jede Migrationsdatei läuft als eine Transaktion — also
-- kann eine Datei, die `planned` anlegt, es nicht auch in einer Policy,
-- einem Check oder einer Funktion verwenden.
--
-- 0047 hat dieselbe Klippe mit `k::text` umschifft. Das war dort richtig
-- (eine Funktion, einmal je Trigger), wäre hier aber falsch: Die
-- Bedingung landet in `sessions_select` und damit in **jeder** Abfrage
-- auf die Tabelle, die die Karte alle 30 Sekunden stellt. Ein
-- Text-Vergleich statt eines Enum-Vergleichs ist dort keine Eleganzfrage.
--
-- Deshalb die Teilung: Diese Datei legt den Wert an, 0049 benutzt ihn.
-- Die CI baut beide nacheinander auf, jede in eigener Transaktion.
--
-- ============================================================================
-- WARUM EINE EIGENE SPALTE UND NICHT `started_at`
--
-- `started_at` bedeutet „wann es tatsächlich losging" — die Statistik
-- rechnet damit, und eine nie gestartete Verabredung würde darin lügen.
-- `scheduled_for` ist der geplante Termin und bleibt auch dann stehen,
-- wenn daraus eine laufende Runde wird: Dann sagt `started_at`, wann sie
-- wirklich begann, und die Differenz ist die Verspätung. Zwei Fragen,
-- zwei Spalten.
--
-- Entwurf und Begründung der ganzen Funktion:
-- docs/features/39-geplante-sessions.md
-- ============================================================================

alter type session_status add value if not exists 'planned';

alter table public.sessions
  add column if not exists scheduled_for timestamptz;

comment on column public.sessions.scheduled_for is
  'Geplanter Termin. Gesetzt bei status = planned; bleibt nach dem Start '
  'stehen, damit sich Verspätung gegen started_at ablesen lässt.';

-- Kein Index hier. Der sinnvolle wäre partiell auf `status = 'planned'`,
-- und genau das ist die Verwendung des neuen Werts, die in dieser
-- Transaktion nicht geht. Er steht in 0049 — zusammen mit allem anderen,
-- das den Wert benutzt.
--
-- Rechte: unverändert. `sessions_insert` und `sessions_update` prüfen nur
-- `host_id = auth.uid()` und kennen den Status gar nicht (live geprüft
-- 2026-09-04) — eine geplante Session lässt sich damit anlegen und vom
-- Gastgeber auf `active` setzen, ohne dass hier etwas zu ändern wäre.
-- **`sessions_select` dagegen schon**, siehe 0049.
