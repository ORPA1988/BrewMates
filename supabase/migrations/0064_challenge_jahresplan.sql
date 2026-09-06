-- Zwölf Challenges für ein Jahr, im Voraus eingetragen.
--
-- Ausgangslage: In `challenges` stand genau **eine** Zeile — „Stil-Safari
-- August", abgelaufen am 31.08.2026. Die Funktion ist seit 0.9.0 fertig
-- gebaut, serverseitig validiert und mit Admin-Editor versehen — und lief
-- seit einer Woche ins Leere.
--
-- Eine Challenge braucht kein App-Update: Sie erscheint, wenn ihr
-- Zeitfenster beginnt, und verschwindet, wenn es endet — auch auf Geräten,
-- die nie wieder aktualisiert werden. Zwölf Zeilen tragen damit ein Jahr.
--
-- ============================================================================
-- KEIN MENGENZIEL
-- ============================================================================
-- Keine dieser zwölf sagt „trink zehn Bier". Sie fordern andere Stile,
-- andere Brauereien, andere Orte — oder ausdrücklich Alkoholfreiheit. Das
-- ist dieselbe Linie wie bei den Abzeichen und steht so in der
-- Produktvision. `checkins_count` kommt bewusst kein einziges Mal vor.
--
-- ============================================================================
-- ZEITZONE UND BEWEGLICHE FESTE
-- ============================================================================
-- Alle Zeitpunkte stehen als `Europe/Vienna`, nicht als UTC: Sonst begänne
-- eine Challenge am 1. Dezember um 01:00 statt um Mitternacht, und die
-- Sommerzeit verschöbe die Hälfte davon um eine Stunde.
--
-- `ends_at` ist **ausschließend** (0014: `created_at < ch.ends_at`). Der
-- letzte Tag ist deshalb immer als *Mitternacht des Folgetags* geschrieben.
--
-- **Fasching und Fastenzeit hängen an Ostern.** Ostern 2027 fällt auf den
-- 28. März, Aschermittwoch damit auf den 10. Februar. Wer diese Daten für
-- ein weiteres Jahr fortschreibt, rechnet sie nach — sie wandern jedes Jahr.
--
-- **Ramadan richtet sich nach dem Mondkalender** und verschiebt sich
-- jährlich um etwa elf Tage. Der Zeitraum unten ist der erwartete für 2027
-- und gehört vor dem nächsten Mal aus einer Tabelle geprüft, nicht
-- gerechnet. Die Challenge ist eine **alkoholfreie** — alles andere wäre
-- eine Zumutung.
--
-- Ramadan überschneidet sich mit Fasching und Starkbierzeit. Das ist kein
-- Fehler: Es sind verschiedene Menschen, und niemand muss beides.
--
-- Feste IDs, damit ein zweiter Lauf nichts verdoppelt.

insert into challenges (id, title, description, emoji, rule,
                        starts_at, ends_at)
values
  ('c0000001-0000-4000-8000-000000000001',
   'Wiesnzeit',
   'Drei Märzen oder Festbiere, solange die Wiesn läuft.',
   '🎪',
   '{"type":"style_specific","style":"märzen","threshold":3}'::jsonb,
   '2026-09-19 00:00 Europe/Vienna'::timestamptz,
   '2026-10-05 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000002',
   'Herbstferien',
   'Drei Brauereien, die du noch nicht im Tagebuch hattest. '
   'Ferien heißt unterwegs sein.',
   '🍂',
   '{"type":"distinct_breweries","threshold":3}'::jsonb,
   '2026-10-24 00:00 Europe/Vienna'::timestamptz,
   '2026-11-03 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000003',
   'Nikolaus',
   'Zwei dunkle Biere bis zum sechsten Dezember.',
   '🎅',
   '{"type":"style_specific","style":"dunkl","threshold":2}'::jsonb,
   '2026-12-01 00:00 Europe/Vienna'::timestamptz,
   '2026-12-07 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000004',
   'Bratapfel & Bock',
   'Vier Bockbiere über die Feiertage. Die Trophäe trägt die Jahreszahl — '
   'sie kommt jedes Jahr wieder, jedes Mal in anderen Farben.',
   '🎄',
   '{"type":"style_specific","style":"bock","threshold":4}'::jsonb,
   '2026-12-01 00:00 Europe/Vienna'::timestamptz,
   '2027-01-07 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000005',
   'Klarer Jänner',
   'Acht alkoholfreie Check-ins. Zählt voll — wie immer in dieser App.',
   '❄️',
   '{"type":"alcohol_free","threshold":8}'::jsonb,
   '2027-01-07 00:00 Europe/Vienna'::timestamptz,
   '2027-02-04 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000006',
   'Fasching',
   'In drei verschiedenen Lokalen einchecken. Nicht, was im Glas ist, '
   'zählt, sondern wo du stehst.',
   '🎭',
   '{"type":"venue_checkins","threshold":3}'::jsonb,
   '2027-02-04 00:00 Europe/Vienna'::timestamptz,
   '2027-02-10 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000007',
   'Alkoholfrei durch den Fastenmonat',
   'Zehn alkoholfreie Check-ins im Ramadan — für alle, die fasten, und '
   'alle, die mithalten wollen.',
   '🌙',
   '{"type":"alcohol_free","threshold":10}'::jsonb,
   '2027-02-08 00:00 Europe/Vienna'::timestamptz,
   '2027-03-10 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000008',
   'Starkbierzeit',
   'Drei Bockbiere zwischen Aschermittwoch und Karsamstag. '
   '„Flüssiges bricht das Fasten nicht" — die älteste Ausrede Bayerns.',
   '🐐',
   '{"type":"style_specific","style":"bock","threshold":3}'::jsonb,
   '2027-02-10 00:00 Europe/Vienna'::timestamptz,
   '2027-03-28 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-000000000009',
   'Frühlingserwachen',
   'Fünf verschiedene Bierstile, sobald es draußen wieder geht.',
   '🌱',
   '{"type":"distinct_styles","threshold":5}'::jsonb,
   '2027-04-17 00:00 Europe/Vienna'::timestamptz,
   '2027-05-17 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-00000000000a',
   'Schulschluss',
   'Fünf verschiedene Brauereien in zwei Wochen. '
   'Zeugnis abgegeben, Sommer angefangen.',
   '🎒',
   '{"type":"distinct_breweries","threshold":5}'::jsonb,
   '2027-06-28 00:00 Europe/Vienna'::timestamptz,
   '2027-07-12 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-00000000000b',
   'Lange Abende',
   'Sechs verschiedene Orte über den Sommer. Die längste Challenge des '
   'Jahres, mit dem kleinsten Druck.',
   '🌇',
   '{"type":"venue_checkins","threshold":6}'::jsonb,
   '2027-07-12 00:00 Europe/Vienna'::timestamptz,
   '2027-09-01 00:00 Europe/Vienna'::timestamptz),

  ('c0000001-0000-4000-8000-00000000000c',
   'Schulbeginn',
   'Drei Biere, die du noch nicht kanntest. Nach dem Sommer wieder '
   'neugierig werden.',
   '📚',
   '{"type":"distinct_beers","threshold":3}'::jsonb,
   '2027-09-01 00:00 Europe/Vienna'::timestamptz,
   '2027-09-22 00:00 Europe/Vienna'::timestamptz)
on conflict (id) do nothing;
