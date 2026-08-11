-- Start-Set der Abzeichen. Grundsatz (docs/01): belohnt werden Vielfalt,
-- Orte und Gemeinsamkeit – niemals Konsummenge.

insert into badges (slug, name, description, icon, rule) values
  ('stil-entdecker', 'Stil-Entdecker',
   '5 verschiedene Bierstile probiert', '🧭',
   '{"type": "distinct_styles", "threshold": 5}'),
  ('weltenbummler', 'Weltenbummler',
   'Biere aus 5 verschiedenen Ländern probiert', '🌍',
   '{"type": "distinct_countries", "threshold": 5}'),
  ('local-hero', 'Local Hero',
   'In 5 verschiedenen Venues eingecheckt', '📍',
   '{"type": "distinct_venues", "threshold": 5}'),
  ('session-stammtisch', 'Stammtisch',
   '10 gemeinsame Sessions mit Freunden', '🍻',
   '{"type": "shared_sessions", "threshold": 10}'),
  ('prost-meister', 'Prost-Meister',
   '100 Toasts an Freunde vergeben', '🥂',
   '{"type": "toasts_given", "threshold": 100}'),
  ('nuechtern-dabei', 'Nüchtern dabei',
   '5 alkoholfreie Biere eingecheckt – zählt voll!', '💧',
   '{"type": "alcohol_free_checkins", "threshold": 5}');
