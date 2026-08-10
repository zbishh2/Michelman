-- Seed the four section-3 KPIs from the client slide. INSERT OR IGNORE keyed on
-- kpi_key makes this idempotent AND non-destructive: re-running it never clobbers
-- values that have since been edited in the visual. Trend verdicts translate the
-- slide's arrow colours (green = Improving, red = Needs Improvement); C2C/FMB ships
-- without a verdict.
--
-- Apply: npx wrangler d1 execute michelman-writeback --remote -y --file seed-manual-kpis.sql

INSERT OR IGNORE INTO manual_kpis (kpi_key, kpi, target, value, trend, sort_order) VALUES
  ('capital-projects',  'Capital projects on-time/budget', '≥ 90%',          'On-Time: 63% · Budget: 100%', 'Needs Improvement', 1),
  ('sc-days-on-hand',   'SC Days on Hand',                 '70–94',          '109',                         'Needs Improvement', 2),
  ('inventory-health',  'Inventory healthiness',           '≥ 80%',          '84%',                         'Improving',         3),
  ('c2c-fmb-ops',       'C2C / FMB Operations',            'Milestones met', NULL,                          NULL,                4);
