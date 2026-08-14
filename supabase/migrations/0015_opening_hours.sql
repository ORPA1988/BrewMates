-- 0015: Strukturierte Öffnungszeiten für Gasthäuser.
--
-- Format: JSON-Liste von Intervallen, z. B.
--   [{"d": 1, "von": "11:00", "bis": "24:00"}, {"d": 6, "von": "10:00", "bis": "02:00"}]
-- d = Wochentag 1–7 (Mo–So), mehrere Intervalle pro Tag erlaubt,
-- "bis" <= "von" bedeutet: bis in den Folgetag (über Mitternacht).
-- Der Freitext `opening_hours` bleibt für Anzeige und Alt-Clients erhalten
-- und wird von der App aus den strukturierten Zeiten generiert.
--
-- Kein neuer Grant nötig: reine Tabellenspalte, RLS-Policies von 0011/0013
-- gelten unverändert.

alter table public.venues
  add column if not exists opening_hours_json jsonb;

comment on column public.venues.opening_hours_json is
  'Strukturierte Öffnungszeiten: [{"d":1-7,"von":"HH:MM","bis":"HH:MM"}]; bis<=von = über Mitternacht.';
