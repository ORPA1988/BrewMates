-- 0061: Was ein Verwalter darf — und was beim Gründer bleibt.
--
-- ============================================================================
-- DER ZUSCHNITT
--
-- Eine Crew hatte bisher genau einen Menschen mit Rechten: den Gründer
-- (`crews.owner_id`). Wer eine Crew gegründet hat und zwei Wochen nicht
-- hineinsieht, blockiert damit alles — niemand kann jemanden entfernen,
-- niemand den Namen richtigstellen.
--
-- Der Verwalter bekommt deshalb genau die Rechte, die den Alltag
-- betreffen, und keines, das die Crew als Ganzes betrifft:
--
--   darf:        Mitglieder entfernen, Name und Emoji ändern
--   darf nicht:  die Crew auflösen, Rollen vergeben, den Gründer entfernen
--
-- **Rollen vergibt nur der Gründer.** Dürfte ein Verwalter das, könnte
-- er sich weitere Verwalter machen und den Gründer aussperren — die
-- Crew gehörte dann faktisch jemand anderem.
--
-- **`owner` bleibt an `crews.owner_id`.** Die Rolle in `crew_members`
-- ist eine Beschreibung, keine zweite Wahrheit; deshalb lässt die neue
-- Update-Policy nur den Wechsel zwischen `member` und `admin` zu. Sonst
-- gäbe es zwei Stellen, an denen steht, wem die Crew gehört, und die
-- erste Uneinigkeit zwischen ihnen wäre ein Rätsel.
--
-- ============================================================================
-- WARUM EIN SECURITY-DEFINER-HELFER
--
-- Dieselbe Falle wie bei `is_my_round` (0050): `crew_members` trägt
-- selbst RLS. Eine Unterabfrage in einer Policy liefe als der fragende
-- Mensch — und der sieht die Zeile eines anderen nur, wenn er ohnehin
-- Mitglied ist. Für die Frage „ist X Verwalter dieser Crew" reicht das
-- zufällig, für „bin ich Verwalter" ebenfalls; verlassen sollte man sich
-- darauf nicht. Der Helfer sieht darunter hindurch und beantwortet
-- ausschließlich Fragen über den Aufrufer — derselbe Maßstab, an dem
-- docs/13 die übrigen Helfer misst.
-- ============================================================================

create or replace function public.is_crew_admin(p_crew uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from crews c
     where c.id = p_crew and c.owner_id = auth.uid()
  ) or exists (
    select 1 from crew_members m
     where m.crew_id = p_crew
       and m.profile_id = auth.uid()
       and m.role = 'admin'
  );
$$;

comment on function public.is_crew_admin(uuid) is
  'Darf der Aufrufer diese Crew verwalten — als Gruender oder als '
  'Verwalter? Security definer, weil crew_members RLS traegt. Nur ueber '
  'den Aufrufer, nie ueber Dritte.';

revoke execute on function public.is_crew_admin(uuid) from public, anon;
grant execute on function public.is_crew_admin(uuid) to authenticated;

-- ----------------------------------------------------------------------------
-- Name und Emoji: auch der Verwalter
-- ----------------------------------------------------------------------------

drop policy if exists crews_update on public.crews;
create policy crews_update on public.crews for update
  using (is_crew_admin(id))
  -- Der Besitzer darf nicht per Update wechseln: Das waere eine
  -- Uebergabe der Crew und keine Aenderung an ihr.
  with check (owner_id = (select owner_id from public.crews c2 where c2.id = id));

-- Aufloesen bleibt beim Gruender — `crews_delete` bleibt unangetastet.

-- ----------------------------------------------------------------------------
-- Mitglieder entfernen: auch der Verwalter, aber nicht den Gruender
-- ----------------------------------------------------------------------------

drop policy if exists crew_members_delete on public.crew_members;
create policy crew_members_delete on public.crew_members for delete
  using (
    -- Selbst gehen darf immer jeder.
    profile_id = (select auth.uid())
    or (
      is_crew_admin(crew_id)
      -- ... aber niemand entfernt den Gruender aus seiner eigenen Crew.
      and profile_id <> (select c.owner_id from crews c where c.id = crew_id)
    )
  );

-- ----------------------------------------------------------------------------
-- Rollen vergeben: nur der Gruender
-- ----------------------------------------------------------------------------

drop policy if exists crew_members_update on public.crew_members;
create policy crew_members_update on public.crew_members for update
  using (
    exists (select 1 from crews c
             where c.id = crew_id and c.owner_id = (select auth.uid()))
    -- Der Gruender selbst behaelt seine Zeile, wie sie ist.
    and profile_id <> (select c.owner_id from crews c where c.id = crew_id)
  )
  with check (role in ('member', 'admin'));

grant update (role) on public.crew_members to authenticated;
