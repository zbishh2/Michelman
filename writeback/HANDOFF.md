# Michelman Writeback — HANDOFF

Runbook. [ARCHITECTURE.md](ARCHITECTURE.md) is the design spec — read it for the D1 schema, the
Worker API, the permission model and the field-well binding rules.

Six Power BI custom visuals write user input to a Cloudflare Worker + D1 database; the writeback
folds back into the semantic model at refresh (the Scorecard KPIs table skips the model entirely
and reads D1 directly).

## Deployed state

| Thing | Value |
|---|---|
| Worker URL | `https://michelman-writeback.michelman-bi.workers.dev` |
| Cloudflare account | Michelman-dedicated, `Zackbishop@michelman.com`, ID `90b8807948312a9dc357d690babd40ff` |
| D1 database | `michelman-writeback`, ID `72fa2e02-ba2c-478c-b1f7-5f2f5f288564` (region ENAM) |
| Deploy credential | `writeback/CF Token.txt` (gitignored — Workers Scripts:Edit + D1:Edit). Use `CLOUDFLARE_API_TOKEN=$(tr -d '\r\n' < "../CF Token.txt") npx wrangler <cmd>`. The ambient `CLOUDFLARE_API_TOKEN` env var is Zack's *personal* account and will fail. |
| Shared secret | `writeback/worker/.secret` (gitignored); set on the Worker as `SHARED_SECRET`; inlined in every visual's `src/config.ts` (gitignored) and in `RevisionOverrides.m` / `LineComments.m` / `ReasonCodes.m` |
| Visual GUIDs | `revisionLogEditorABA20355…` · `orderLineComments88047B…` · `scComments3F8A2D6C41B94E57` · `scKpis7D2E4A91C6B35F08` |
| Admins | `zackbishop@michelman.com`, `ivanceriani@michelman.com`, and `desktop-pkqsmbt\zack` (the local-Desktop UPN, for testing) |
| Reason codes | 48 in `reason_dim`, 28 flagged `otif = 1`, 47 active ("do not use" codes inactive) |

## Model integration

The `.m` and `.dax` files in `edw_model/` are the source of truth; see ARCHITECTURE.md § Model
fold-back for what each one does.

- DAX in `edw_model/ExecutiveDashboard_Model.dax`: `[Is OTIF Relevant]` includes `&& NOT [Excluded]`;
  `[Is OTIF Relevant (As Reported)]`, `Orders[Relevant Revision Count (As Reported)]`,
  `Orders[On Time (As Reported)]`, and the measures `Orders (Late, As Reported)`,
  `On Time Order % (As Reported)`, `Overwrite Impact (Orders)` (folder "OTIF Header (As Reported)").
- `Current User = USERPRINCIPALNAME()` and `Current User (Grid)` feed the visuals' `currentUser`
  field well. **Bind the `(Grid)` one on any grid over `FactSalesDetail`** — ARCHITECTURE.md
  § Field-well binding rules says why.
- Live model names: Orders = **`FactSalesDetail`** (older docs say `Orders from EDW`); reason dim =
  **`Reason Codes`**.

### Refresh requirements

- Must run where **ODSPROD is reachable** (the jumpbox) **and** outbound HTTPS to the Worker is
  allowed.
- First refresh: Web credentials = **Anonymous**.
- On a `Formula.Firewall` error → **ignore privacy levels**.
- Refreshing `Reason Codes` is what picks up reason-code edits; a full model refresh/recalc then
  moves OTIF.

## Field wells

- **Revision Log Editor:** `columns` (display fields), `revisionKey` = `FactScheduleChange[RevisionKey]`,
  `currentUser`, `hiddenColumns` (export-only).
- **Order Line Comments:** `columns`, `orderLineId` = `FactSalesDetail[Order Line ID]`, `currentUser`,
  `companyList` = `[Company List (All)]`, `hiddenColumns`.
- **Reason Code Editor:** `currentUser`; the grid is fed from `/reason-dim`, not the model.
- **Board visuals:** `currentUser`; `board_key` is a formatting-pane setting, not a field well.
- **Scorecard KPIs:** `currentUser`; the rows are fed from `/manual-kpis`, not the model. Editing
  needs an **editor or admin** role in `people` — hover a row for the pencil, edit inline, Enter
  saves. The trend dropdown speaks the model Trend column's vocabulary (Improving / Needs
  Improvement / Steady / —).

## Identity

Identity is `USERPRINCIPALNAME()`, sent as the self-asserted `x-actor-email` header and recorded on
every write. In the Service it is the AAD UPN; **in Desktop with a local Windows account it is the
`DOMAIN\user` form** (`DESKTOP-PKQSMBT\Zack`) — which is why that account is seeded as an admin.
`normalizeActorEmail()` accepts both forms in all visuals; it must never require an `@`, or the
Desktop form is dropped, no header goes out, and every admin write comes back 403 "admin required".

"I'm an admin but the grid is read-only" is an identity problem, not a D1 one. Two causes: an
unbound `currentUser` field well, or the visual discarding a bound value.

## People panel

- **Remove is a hard delete** — `DELETE /people/:key?hard=1` drops the `people` row and its
  `people_companies` grants. Plain `DELETE /people/:key` soft-deactivates (reactivatable, companies
  kept and returned in the payload). A hard delete of your own row is refused **409**.
- Deactivate remains available for the keep-the-row case: the Revision Log Editor uses its Active
  checkbox, the other two their Deactivate button.
- Row actions confirm **in place** (`Remove` → `Confirm` / `Cancel`) — `window.confirm` is not
  dependable inside the Power BI visual sandbox — and surface the Worker's error message next to
  the control that caused it.

## Day-2 operations

- **Add a user:** the People panel, or SQL:
  `npx wrangler d1 execute michelman-writeback --remote -y --command "INSERT INTO people (person_key, person_name, display_name, email, role, active) VALUES ('KEY','Name','Display','email@michelman.com','editor',1)"`
- **Grant company scope:** insert into `people_companies` (`person_key`, `company`), or use the
  People panel's company picker.
- **Rotate the secret:** `openssl rand -hex 32 > worker/.secret`; `npm run secret:set`; update every
  visual's `src/config.ts` → repackage → reimport; update the Secret in `RevisionOverrides.m`,
  `LineComments.m` and `ReasonCodes.m` and reapply those expressions.
- **Change a visual:** edit source → bump BOTH version fields in `pbiviz.json` → `npx pbiviz package`
  → reimport. Same GUID replaces in place and bindings survive.
- **Deploy the Worker:** `cd worker && npm run typecheck && CLOUDFLARE_API_TOKEN=... npx wrangler deploy`.
- **Re-seed reason codes:** `worker/seed-reason-dim.sql`. `worker/seed-board-exec-scorecard.sql`
  seeds the Scorecard thread and is idempotent.
- **Section-3 KPIs:** schema `worker/schema-manual-kpis.sql`, seed `worker/seed-manual-kpis.sql`
  (INSERT OR IGNORE — re-running never clobbers edits made in the visual). Values are edited in
  the Scorecard KPIs visual itself; adding a row is a `PUT /manual-kpis` with a new `kpiKey`.
- **Backups (TODO):** schedule `wrangler d1 export michelman-writeback --remote`, or an
  Office-Script / Power Automate pull of `/revision-overrides` + `/comments/*`.

### ⚠ After a Worker deploy, wait a minute before testing

A newly deployed Worker **routes 404 for a few seconds**, and the rollout is **gradual, not
atomic** — for ~30–60s requests split between old and new code, so a verification run can show the
old and the new response shape seconds apart. That reads as a bug and is not one. Re-test after a
minute before concluding anything.

## Security posture (accepted)

The static `x-secret` ships inside the `.pbiviz` and `.m` files, so anyone with report access can
extract it; identity is a self-asserted header, so the audit log is accountability, not forensics;
the endpoint is on the public internet.

Mitigations in place: as-reported truth is immutable so full recovery is possible, field-level
audit on every mutation, soft deletes.

Hardenings not yet done: nightly D1 backup, Cloudflare rate limiting, CORS locked to
`app.powerbi.com`, a read-only vs read-write secret split. Delete or relocate `CF Token.txt` once
deploying is finished.

## Open items

- End-to-end OTIF loop check: override → jumpbox refresh → `Orders (Late)` moves, `(As Reported)`
  holds, `Overwrite Impact (Orders)` shows the delta.
- `visual-comments`, `visual-otif-hits` and `visual-revisions` still lack the `options.viewport`
  pixel-height fix (ARCHITECTURE.md § Stamp `options.viewport`).
- "Operations (??)" still to merge in the reason-category picklist.
- `dropdown_reason_codes` is redundant with `reason_dim` — candidate to source from it.
