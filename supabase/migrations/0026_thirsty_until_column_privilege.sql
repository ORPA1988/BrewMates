-- 0026: profiles.thirsty_until nur noch über Funktionen lesbar machen.
--
-- ============================================================================
-- ACHTUNG — NICHT ZUSAMMEN MIT 0024 AUSROLLEN.
--
-- Voraussetzung: Es greifen keine Clients mehr zu, die `thirsty_until`
-- direkt mitselektieren. Das sind alle App-Stände vor 0.10.0-beta; erst ab
-- 0.10 liest die App die Bierlaune über my_thirsty_until() und
-- thirsty_friends().
--
-- Vor dem Einspielen prüfen, ob noch alte Clients unterwegs sind (Play
-- Console, API-Logs). Im Zweifel warten: Die Spalte ist seit 0018 lesbar,
-- ein paar Wochen länger ändern daran nichts. Zu früh eingespielt bricht
-- dagegen bei jedem alten Client das Laden des GESAMTEN Profils —
-- PostgREST verweigert die ganze Abfrage, nicht nur die eine Spalte. Der
-- Nutzer sieht dann weder Freundesliste noch eigenes Profil.
-- ============================================================================
--
-- ============================================================================
-- WARUM DIE ERSTE FASSUNG NICHTS BEWIRKT HÄTTE
--
-- Ursprünglich stand hier schlicht:
--
--   revoke select (thirsty_until) on public.profiles from anon, authenticated;
--
-- Das ist wirkungslos, solange ein Recht auf TABELLENEBENE besteht — und
-- genau das besteht (siehe 0025). Postgres nimmt den Befehl an, meldet
-- „REVOKE" und lässt die Spalte lesbar: Ein Tabellenrecht deckt alle
-- Spalten ab und kann nicht spaltenweise beschnitten werden.
--
-- Eine Sicherheitsmaßnahme, die lautlos nichts tut, ist schlimmer als
-- eine, die scheitert: Sie steht in der Migration, sie steht in der
-- Dokumentation, und trotzdem liegt die Angabe offen. Aufgefallen ist es
-- erst durch den RLS-Test in `supabase/tests/`.
--
-- Richtig ist der umgekehrte Weg: das Tabellenrecht ganz entziehen und
-- alle Spalten AUSSER dieser einen einzeln wieder gewähren.
-- ============================================================================
--
-- Warum überhaupt Spaltenrechte und nicht RLS: thirsty_until hängt an
-- profiles, und ein Profil muss für Freunde sichtbar bleiben — die Zeile
-- zu verbergen scheidet aus. RLS wirkt zeilenweise und kann eine einzelne
-- Spalte je Betrachter nicht ausblenden. Das Spaltenrecht kann es, und
-- die beiden Funktionen aus 0024 liefern den abgestuften Zugang.
--
-- WARTUNGSHINWEIS: Ab hier ist die Spaltenliste explizit. Eine später
-- hinzugefügte Spalte auf `profiles` ist für anon/authenticated NICHT
-- lesbar, bis sie gewährt wird. Wer `profiles` erweitert, muss in
-- derselben Migration `grant select (neue_spalte) on public.profiles to
-- anon, authenticated` mitschreiben.

do $$
declare
  spalten text;
begin
  select string_agg(format('%I', column_name), ', ' order by ordinal_position)
    into spalten
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name <> 'thirsty_until';

  -- Erst die Fläche weg, sonst bleibt die Spalte gedeckt.
  revoke select on public.profiles from anon, authenticated;
  execute format(
    'grant select (%s) on public.profiles to anon, authenticated', spalten);
end $$;
