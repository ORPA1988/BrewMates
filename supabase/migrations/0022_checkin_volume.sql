-- 0022: Füllmenge je Check-in.
--
-- Das Gebinde wird längst erfasst (checkins.serving_style: draft, bottle,
-- can, growler) — die Menge nicht. Ohne sie gibt es keine Literangabe,
-- und genau danach fragt man als erstes, wenn man ein Jahr zurückblickt.
--
-- Nullable und ohne Vorgabewert: Alle bisherigen Check-ins haben keine
-- Angabe, und ihnen einen Wert anzudichten wäre falsch. Die Auswertung
-- schätzt dort nach Gebinde und weist aus, wie viele Einträge geschätzt
-- sind — eine Literzahl, die so tut, als wäre sie gemessen, wäre eine
-- Lüge.
--
-- Die Obergrenze fängt Vertipper ab (20 l ist mehr als jedes Gebinde,
-- das eine Person auf einmal trinkt); 0 oder negativ ergibt keinen Sinn.

alter table public.checkins
  add column if not exists volume_ml integer;

alter table public.checkins
  add constraint checkins_volume_ml_sane
  check (volume_ml is null or (volume_ml > 0 and volume_ml <= 20000))
  not valid;
