-- 0027: Trigram-Indizes für die Freundessuche (Backlog B-1).
--
-- Die Suche fragt seit 0.9.13 zwei Spalten ab:
--
--   username     ilike 'begriff%'    -- Präfix
--   display_name ilike '%begriff%'   -- Teilstring
--
-- Beides kann ein gewöhnlicher B-Tree nicht bedienen: `ilike` ist
-- unabhängig von Groß-/Kleinschreibung, und ein Teilstring hat keinen
-- Präfix, an dem sich ein B-Tree entlanghangeln könnte. Postgres liest
-- deshalb heute die ganze Tabelle und prüft jede Zeile einzeln.
--
-- Bei zwei Profilen ist das nicht messbar — das ist kein Argument, es ist
-- der Grund, warum es bisher niemandem auffiel. Ab einigen tausend
-- Profilen wird aus jeder Tasteneingabe ein vollständiger Tabellenscan,
-- und die Suche läuft bei JEDEM Tastendruck.
--
-- `gin_trgm_ops` zerlegt die Werte in Dreibuchstabengruppen und findet
-- darüber auch Treffer in der Wortmitte. Es bedient `like` und `ilike`
-- gleichermaßen.
--
-- Die Erweiterung liegt bewusst im Schema `extensions`, nicht in `public`:
-- Der Security-Advisor meldet Erweiterungen in `public` als Befund. Dass
-- PostGIS dort liegt, ist eine dokumentierte Altlast (CLAUDE.md) — sie
-- muss nicht wachsen. Deshalb ist auch die Operatorklasse unten
-- vollständig qualifiziert.
--
-- Wiederholbar: `if not exists` an allen drei Stellen.

create extension if not exists pg_trgm with schema extensions;

create index if not exists profiles_username_trgm
  on public.profiles using gin (username extensions.gin_trgm_ops);

create index if not exists profiles_display_name_trgm
  on public.profiles using gin (display_name extensions.gin_trgm_ops);

-- Hinweis für später: Der bestehende `profiles_username_idx` (B-Tree)
-- bleibt. Er bedient exakte Vergleiche und die Sortierung `order by
-- username`, die die Suche zusätzlich verlangt — der Trigram-Index kann
-- das nicht. Beide haben ihre Aufgabe.
