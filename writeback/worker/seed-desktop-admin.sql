-- Local Power BI Desktop identity for Zack: USERPRINCIPALNAME() returns the
-- machine account (DESKTOP-PKQSMBT\Zack) instead of the AAD email, so it needs
-- its own admin row to allow testing writeback edits without publishing.
INSERT INTO people (person_key, person_name, display_name, email, role, active)
VALUES ('DESKTOP-PKQSMBT\ZACK', 'Zack (Desktop)', 'Zack (Desktop)', 'desktop-pkqsmbt\zack', 'admin', 1)
ON CONFLICT(person_key) DO UPDATE SET
  email = excluded.email,
  role = 'admin',
  active = 1,
  updated_at = datetime('now');
