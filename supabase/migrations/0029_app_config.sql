-- 0029: Serverseitige Mindestversion („Update erforderlich").
--
-- ============================================================================
-- WOZU
--
-- Bisher galt: Eine Migration darf nichts entziehen, was ältere Clients
-- noch lesen — sonst brechen sie, ohne dass der Nutzer versteht warum.
-- Deshalb liegt 0026 seit Wochen auf Halde und `beers.barcode` bleibt in
-- 0028 stehen, obwohl `beer_barcodes` sie ersetzt.
--
-- Das ist auf Dauer teuer: Jede Altlast bleibt für immer, weil niemand
-- weiß, wann der letzte alte Client verschwunden ist.
--
-- Die Alternative ist ein Riegel: Der Server nennt die kleinste noch
-- unterstützte Version, die App vergleicht sie mit ihrer eigenen und
-- zeigt einen Bildschirm „Update erforderlich", statt in unerklärliche
-- Fehler zu laufen. Danach darf eine Migration entziehen — die betroffene
-- Fassung startet ohnehin nicht mehr durch.
--
-- ============================================================================
-- GRENZE, DIE MAN KENNEN MUSS
--
-- Das wirkt **nur für Versionen, die den Riegel schon mitbringen**.
-- Bereits ausgelieferte 0.9.x-Stände kennen ihn nicht und laufen weiter in
-- den unerklärlichen Fehler. Nachrüsten lässt sich das nicht — eine
-- ausgelieferte App tut, was sie beim Bauen gelernt hat.
--
-- Für den heutigen Bestand heißt das: `min_supported_version` bleibt
-- niedrig, bis 0.10.2 verbreitet ist. Ab dann ist das Anheben ein
-- Einzeiler statt einer Migrationsstrategie.
-- ============================================================================

create table if not exists app_config (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

alter table app_config enable row level security;

-- Lesen ohne Anmeldung: Der Riegel muss auch greifen, wenn niemand
-- eingeloggt ist — sonst umginge man ihn durch Abmelden.
drop policy if exists app_config_select on app_config;
create policy app_config_select on app_config for select using (true);

-- Schreiben nur Admins. Wer die Mindestversion setzt, sperrt Nutzer aus;
-- das ist keine Community-Aufgabe.
drop policy if exists app_config_write on app_config;
create policy app_config_write on app_config for all
  using (is_admin(auth.uid()))
  with check (is_admin(auth.uid()));

grant select on public.app_config to anon, authenticated;
grant insert, update, delete on public.app_config to authenticated;

-- Startwert bewusst unter allem, was je ausgeliefert wurde: Der Riegel
-- ist damit vorhanden, aber zu. Erst wenn 0.10.2 verbreitet ist, wird
-- hier hochgesetzt.
insert into app_config (key, value)
values ('min_supported_version', '0.1.0')
on conflict (key) do nothing;
