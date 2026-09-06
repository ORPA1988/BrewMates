-- Die Trigger-Funktion aus 0063 gehört niemandem außer dem Trigger.
--
-- `vergib_sofortige_auszeichnungen()` ist SECURITY DEFINER und stand
-- damit unter `/rest/v1/rpc/` für `anon` und `authenticated` offen. Ein
-- Direktaufruf wäre am fehlenden Trigger-Kontext gescheitert — aber eine
-- offene SECURITY-DEFINER-Funktion ist kein Zustand, den man mit "geht
-- ohnehin nicht" stehen lässt.
--
-- Gefunden von `get_advisors('security')` beim Gegenlesen nach dem
-- Einspielen, nicht beim Schreiben. Deshalb steht die Prüfung ab jetzt
-- auch im pgTAP-Test.
revoke execute on function public.vergib_sofortige_auszeichnungen()
  from public, anon, authenticated;
