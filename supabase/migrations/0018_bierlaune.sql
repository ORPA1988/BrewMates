-- 0018: „Bierlaune"-Status (Wettbewerbsanalyse: meistgewünschtes
-- Beer-With-Me-Feature — signalisieren, dass man Lust auf ein Bier
-- hätte, ohne schon zu trinken).
--
-- profiles.thirsty_until: Zeitpunkt, bis zu dem die Bierlaune gilt
-- (null = keine). Sichtbarkeit erledigt die bestehende profiles-RLS
-- (eigenes Profil immer, fremde nur öffentlich/befreundet); setzen darf
-- nur der Besitzer über die bestehende Update-Policy. Keine neuen Grants.

alter table public.profiles
  add column if not exists thirsty_until timestamptz;

comment on column public.profiles.thirsty_until is
  'Bierlaune: bis wann Lust auf ein Bier signalisiert wird (null = aus).';
