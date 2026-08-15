-- 0021: Grenzen für die Beacon-Laufzeit.
--
-- Die Laufzeit ist seit jeher wählbar (sessions.expires_at, Vorgabe drei
-- Stunden), aber ungeprüft: Ein Client konnte jeden beliebigen Wert
-- setzen — auch „endet in zwei Jahren". Ein Beacon, der aus Versehen
-- stehen bleibt, zeigt Freunden dauerhaft einen Aufenthaltsort an; das
-- ist ein Datenschutzproblem und keine Bequemlichkeit.
--
-- Die App bietet 30 Minuten bis 12 Stunden an und deckelt auch beim
-- Verlängern. Diese Bedingung zieht die Grenze dort, wo sie nicht mehr
-- umgangen werden kann.
--
-- Warum die Obergrenze auf 24 Stunden ab Start und nicht auf 12 steht:
-- Verlängern rechnet ab JETZT, nicht ab dem bisherigen Ende — „noch zwei
-- Stunden" ist das, was jemand um 22 Uhr meint. Wer um 20 Uhr mit drei
-- Stunden startet und um 22:30 um fünf Stunden verlängert, landet bei
-- 7,5 Stunden Gesamtlaufzeit. 24 Stunden lassen das zu und begrenzen
-- trotzdem die Gesamtlebensdauer eines Beacons auf einen Tag.
--
-- NOT VALID: Die Bedingung gilt ab sofort für neue und geänderte Zeilen,
-- ohne den Bestand zu prüfen. Alte Sessions sind längst beendet; sie
-- nachträglich zu bewerten brächte nichts und könnte die Migration an
-- historischen Daten scheitern lassen.

-- Der do-Block statt eines nackten `add constraint`: Postgres kennt für
-- Constraints kein `if not exists`. Ohne die Prüfung bricht ein zweiter
-- Lauf mit duplicate_object ab — und ein Rollout, der sich nicht
-- wiederholen lässt, muss nach jedem Abbruch von Hand aufgeräumt werden.

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sessions_duration_bounds'
  ) then
    alter table public.sessions
      add constraint sessions_duration_bounds
      check (
        expires_at > started_at + interval '29 minutes'
        and expires_at <= started_at + interval '24 hours'
      )
      not valid;
  end if;
end $$;
