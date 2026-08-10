# Michelman Writeback — Architecture

Design spec for the writeback solution. [HANDOFF.md](HANDOFF.md) is the runbook.

## What this is

A Power BI writeback solution for the Executive Dashboard and OTIF models: **six custom visuals,
one Cloudflare Worker, one D1 database**. Users edit inside the report; the edits fold back into
the semantic model at refresh — except the Scorecard KPIs table, which has no model backing at all
and reads D1 directly.

Pattern cloned from two sibling solutions — `C:\Users\Zack\Documents\Code\Terrasmart\DeliveryReliability`
(rich grid + roles) and `C:\Users\Zack\Documents\Code\MRP` (comment threads).

| Visual | Folder | What it edits | Backing |
|---|---|---|---|
| **Revision Log Editor** | `visual-revisions/` | Override a revision's reason on a `FactScheduleChange` event | `revision_overrides` |
| **Order Line Comments** | `visual-comments/` | One free-text comment per sales order line | `line_comments` |
| **Reason Code Editor** | `visual-otif-hits/` (folder name is legacy) | The full ~48-code reason dimension, including the OTIF flag that drives OTIF | `reason_dim` |
| **OTIF Actions & Comments** | `visual-board/` | Page-level discussion thread with region chips and an inline composer | `board_comments`, `board_key = summary-shipped-as-promised` |
| **Scorecard Comments** | `visual-scorecard-comments/` | Page-level thread for the Executive Scorecard's section 4 | `board_comments`, `board_key = exec-scorecard-people` |
| **Scorecard KPIs** | `visual-scorecard-kpis/` | The Executive Scorecard's section-3 table (Drive Continuous Improvement) — hand-maintained KPI / Target / Value / Trend rows with no model backing, edited inline per row | `manual_kpis` |

## Design decisions

- **Topology:** ONE Worker + ONE D1 database (`michelman-writeback`) serving all five visuals.
- **Comments fold:** the latest comment per line folds into the model at refresh; the full thread
  lives in the visual.
- **Pre-override truth is preserved:** the model keeps `RevisionReasonOriginal` alongside the
  effective (overridden) `RevisionReason`, so OTIF-as-reported and OTIF-with-overrides are both
  computable.
- **The reason dimension lives in D1, not SharePoint.** `'Reason Codes'` loads from
  `GET /reason-dim`; `[OTIF] = "X"` iff the editable `otif` flag is set.
- **Enforcement is doubled on purpose:** the visuals disable the control and explain why on the
  tooltip (`src/permissions.ts`, shared verbatim across the grid visuals); the Worker returns 403
  regardless of what the client believes.
- **Cloudflare account is Michelman-dedicated** (IT handoff cleanliness), not LeanGo's.

## Grain and keys

- `FactScheduleChange` (source `edw_model/FactScheduleChange.m`, ODSPROD `PRODDTA.F42199`) is one
  row per promised-date revision EVENT. No surrogate key. Natural key = OrderCompany + OrderNumber
  + OrderType + OrderSuffix + LineNumber + ChangeDate + ChangeTime.
- Model join idiom: `Orders[Order Line ID]` 1→\* `FactScheduleChange[OrderLineID]`, a composite
  string `Company,OrderNum,Type,Line/1000` — e.g. `"00010,74,CM,4.000"`. OrderSuffix is not in it.
- **`revision_key`** (TEXT PK, opaque to the Worker) =
  `OrderLineID & "|" & <ChangeDate as yyyy-MM-dd> & "|" & <ChangeTime as integer text>`,
  e.g. `"00010,74,CM,4.000|2026-03-14|143502"`. **Defined in exactly one place** —
  `edw_model/FactScheduleChange.m`, culture-pinned. The visual's field-well column and the model
  must produce byte-identical strings; never redefine it elsewhere.
- **Comments key** = `order_line_id`, the `Order Line ID` string as-is.
- `RevisionReason` = F42199 `SLRFRV`, decoded by UDC `42/RR`.

## D1 schema

Core:

- `revision_overrides` — PK `revision_key`; `order_line_id`, `change_date`, `change_time`
  (denormalized for readability), `revision_reason_override`, `note`, `exclude_flag` 0/1,
  `created_at`, `updated_at`. Note and exclude are not exposed in the UI (customer request) and
  stay at defaults.
- `line_comments` — `id` INTEGER PK AUTOINCREMENT; `order_line_id`, `body`, `actor_email`,
  `created_at`, `updated_at`, `deleted_at` (soft delete).
- `reason_dim` — the editable reason dimension, 48 codes. `code` PK, `description`,
  `long_description`, `exemption_criteria`, `otif` 0/1 (**the OTIF driver**), `category`
  (responsible dept), `active` 0/1 (dim-row validity), `sort_order`, `review_530`, `review_540`,
  `typical_hit`, `old_classification`, `usage_examples`, `region_note`, audit columns.
  Schema `worker/schema-reason-dim.sql`, seed `worker/seed-reason-dim.sql`.
- `manual_kpis` — the Executive Scorecard's section-3 rows. `kpi_key` PK, `kpi`, `target`, `value`
  (all display text — these KPIs have no warehouse source), `trend` (CHECK-constrained to the same
  Improving / Needs Improvement / Steady vocabulary the model-backed Trend column speaks, or NULL),
  `sort_order`, `active` 0/1 (soft retire), audit columns. `manual_kpi_history` is its field-level
  audit, mirroring `reason_dim_history`. Served straight to the visual — **no model fold-back**, so
  edits appear on the next visual poll (~60s) with no refresh.
- `board_comments` — page-level thread: `board_key`, `body`, `region`, `actor_email`, soft delete.
  No order grain. `region` ∈ {Americas, EMEA, Asia} or NULL for "all regions", CHECK-constrained so
  a typo cannot create a fourth silent bucket. The vocabulary mirrors `Dim Region` in the semantic
  model (00010 → Americas, 00020 → EMEA, 00030/34/35 → Asia). NULL posts stay visible under every
  filter.

Support:

- `people` — PK `person_key`; `person_name`, `display_name`, `email` (indexed), `role`, `active`.
- `people_companies` — PK (`person_key`, `company`). The approved-editor list. `company` is the
  canonical 5-char JDE order company (`00010`); the Worker normalizes `10` / `0010` / `00010`.
- `override_history` — field-level audit. Each revision-override PUT diffs fields and inserts one
  row per change: `revision_key`, `actor_email`, `changed_at`, `field`, `old_value`, `new_value`.
- `comment_history` — the action-shaped sibling: `order_line_id`, `comment_id`, `actor_email`,
  `changed_at`, `action` ∈ {create, edit, delete}, `old_value`, `new_value`.
- `reason_dim_history` — field-level audit for `reason_dim`, mirrors `override_history`.
- `reason_categories` — the managed Classification picklist behind the Reason Code Editor's
  category dropdown. Deliberately **not** an FK on `reason_dim.category`: a hidden choice must keep
  resolving for rows that still hold it, exactly as a retired reason code keeps resolving for
  historical facts.
- `dropdown_reason_codes` — `code_id` PK, `code` UNIQUE, `label`, `sort_order`, `active`. Source
  for the Revision Log Editor's dropdown. Redundant with `reason_dim`; a candidate to later source
  from it.
- `user_layout` — PK (`email`, `visual_id`); `column_order` JSON. `visual_id` ∈ {`revisions`,
  `comments`, `reasondim`}. Needed because `persistProperties` does not survive the Service.

## Board keys

`board_key` is what makes one board pbiviz serve unrelated threads — same GUID, same Worker, no
shared posts. Set it in the visual's formatting pane under **Board › Board key**.

| Key | Report / page | Read by |
|---|---|---|
| `summary-shipped-as-promised` | OTIF → Summary Shipped as Promised | `visual-board` |
| `exec-scorecard-people` | Executive Dashboard → Executive Scorecard, section 4 | `visual-scorecard-comments` |

Both keys live in the **same `board_comments` table**, so a mistyped key silently merges two
threads rather than erroring. `summary-shipped-as-promised` is also the Worker's `DEFAULT_BOARD`
and the visual's default setting, so an unconfigured instance lands there — always set the key
explicitly on a new drop. Two visuals sharing a key share their feed, which is the only way to get
one thread onto two pages.

`exec-scorecard-people` is seeded from the slide text by `worker/seed-board-exec-scorecard.sql`;
the seed rows carry `actor_email IS NULL`, which is what makes that script idempotent.

## Scorecard Comments is a fork, not a configuration

`visual-scorecard-comments` has its own GUID (`scComments3F8A2D6C41B94E57`) and its own package.
Differences from `visual-board`:

- **No regions.** No chips, no per-post badge, no picker — people/org KPIs have no regional
  dimension. It always writes `region: null`, so one table still serves both visuals. `edit()`
  sends `region: null` *explicitly*, because the Worker's PATCH reads an absent key as "leave the
  tag alone".
- **No author line.** `[Current User]` is still bound and still sent as `x-actor-email`, so D1
  records who wrote what; it is simply never rendered.
- **No timestamp.** `created_at` still drives the newest-first `ORDER BY` server-side. With the
  author also absent, `.scb-meta` carries no text and survives only as the hover target for Edit /
  Delete.
- **No inline composer.** An **Add comment** button opens a modal editor, which Edit reuses. That
  buys back the ~60px the composer occupies.

Two visuals share a GUID only if they share a package, and a shared package means every OTIF-side
change reships to the Scorecard. Three behavioural differences is past the point where flags stay
readable. The cost: **`richtext.tsx`, `RichTextEditor.tsx` and the Worker API client are
duplicated** — a fix to markdown rendering or the API contract must be applied twice. If that
starts to bite, the answer is a shared package, not re-merging the visuals. The fork's CSS prefix
is `scb-` (vs `obc-`).

⚠ The composer dialog is `position:absolute` inside the visual, not `position:fixed` — Power BI's
sandboxed iframe gives `<dialog>.showModal()` no top layer, so a real modal renders *behind* the
visual. The dialog therefore cannot overflow the visual's own box: below roughly 200px of visual
height the editor gets cramped. Resize the visual rather than fighting the CSS.

## Permission model

Company scope IS the edit permission for order-grain writeback. `role = admin` is the only role
that still means anything.

| Viewer | May edit |
|---|---|
| `role = admin` | every company, plus the People list and the reason codes |
| listed with companies | rows whose Order Company matches one of theirs |
| listed, no companies | nothing (read-only) |
| not on the list | nothing (read-only) |

The **Reason Code Editor is admin-only** regardless of company scope — that table drives OTIF.
Non-admins get a read-only grid with a banner; `GET /reason-dim` stays open so viewing and the
model refresh keep working.

A row's company needs no extra field binding: the Order Line ID is `<company>,<order>,<type>,<line>`
(`00010,74,CM,4.000`), so it is the first comma segment. `revision_key` opens with the same Order
Line ID, so the identical helper works there.

## Worker API

Single file, `worker/src/index.ts`. Auth: `x-secret` on everything except `/health`. Identity is
the `x-actor-email` header (self-asserted UPN — internal tenant-gated report, the secret ships in
the artifacts, rotate if leaked). Role checks are server-side via `people`.

- `GET /health` (unauth)
- `GET /revision-overrides` → `{ revisionKey: {...} }` map (visual load + model refresh)
- `PUT /revision-override` — key and fields in the JSON body; the key contains commas and pipes,
  so it stays out of the URL path. Partial upsert, omitted fields preserved. Writes
  `override_history`.
- `DELETE /revision-override` (key in body)
- `GET /history?revisionKey=&since=&limit=` (≤500)
- `GET /comments/latest` → latest non-deleted comment per `order_line_id` (model refresh)
- `GET /comments/thread?orderLineId=` · `POST /comment` · `PATCH /comment/:id` ·
  `DELETE /comment/:id` (soft) · `PUT /line-comment` — company-gated; every mutation writes
  `comment_history`
- `GET /comment-history?orderLineId=&since=&limit=` (≤1000) — admin only
- `GET /board-comments?board=&region=&limit=` · `POST /board-comment` ·
  `PATCH|DELETE /board-comment/:id`. `region` accepts any casing plus the aliases people type
  (`apac`→Asia, `europe`→EMEA, `na`→Americas); an unrecognised value is a **400**, never a silent
  widening to all regions. `?region=X` returns X's posts **plus** the untagged ones. On PATCH, an
  absent `region` key leaves the tag alone and an explicit `null` clears it.
- `GET /people` (nested; each person carries `companies: string[]`) ·
  `POST/PUT/DELETE /people[/:key]` — admin only. Accepts `companies` as an array or a comma/space
  separated string, replaced wholesale.
  - `DELETE /people/:key` **soft-deactivates** (`active = 0`, reactivatable, companies kept and
    returned in the payload).
  - `DELETE /people/:key?hard=1` is the People panel's **Remove**: the `people` row and its
    `people_companies` grants are deleted outright. Nothing carries an FK onto `person_key` and
    both history tables record `actor_email`, so a hard delete costs no audit trail — it only
    removes the display name those logs would have resolved the email to.
  - A hard delete of **your own** row is refused **409**: it would revoke the admin rights needed
    to undo it, and there is no way back in through the UI.
- `GET /reason-dim` (open, x-secret only) · `PUT /reason-dim` (admin; diff → `reason_dim_history`) ·
  `DELETE /reason-dim` (admin; soft-retire `active = 0`) · `GET /reason-dim/history`
- `GET /reason-categories` (open) · `PUT/DELETE /reason-categories` (admin).
  `PUT` with `renameFrom` **cascades** the new name onto every `reason_dim` row carrying the old
  one and writes a `category` row per affected code into `reason_dim_history`, so a
  reclassification is visible in each code's history panel instead of looking spontaneous.
  `DELETE` is a hard delete and is **refused 409 while any reason code still carries the value**
  (the body says how many) — rename is the merge tool, delete is only for unused typos.
  `PUT /reason-dim` validates `category` against this list, so the dropdown is UX and the 400 is
  the real control.
- `GET /manual-kpis` (open, x-secret only; active rows, ordered) · `PUT /manual-kpis` (partial
  upsert by `kpiKey`; **editor or admin** — org-level content, so company scope does not apply;
  an unrecognised `trend` is a 400, never a silent fourth verdict; diffs → `manual_kpi_history`) ·
  `DELETE /manual-kpis` (admin; soft retire `active = 0`)
- `GET/POST/PUT/DELETE /reason-codes[/:id]` (admin; a code rename cascades to `revision_overrides`)
- `GET/PUT/DELETE /layout?visual=` (keyed by `x-actor-email` + `visual_id`)

## Visual requirements

`capabilities.json`: dataRoles `columns`, a key role (`revisionKey` / `orderLineId`),
`hiddenColumns`, `currentUser` (measure), `companyList` (`kind: "GroupingOrMeasure"`).
`privileges.WebAccess` MUST whitelist the Worker origin. `dataReductionAlgorithm.top.count = 30000`.

Grid visuals carry: role gating, right-click context menu (copy value/row/row+headers/table, with
an `execCommand` fallback), drag-drop column reorder (persisted to `general.columnOrder` AND D1
`/layout`), column resize (`general.columnWidths`), sort, PQ-style per-column filter popovers that
push `host.applyJsonFilter` to the page (signature-deduped to avoid an infinite loop), sticky
header, a ~20s poll with a JSON-equality bailout to avoid scroll churn, the `hiddenColumns`
export-only field well, and the admin People panel.

`config.ts` (gitignored) + `config.example.ts` for baseUrl and secret.

### Stamp `options.viewport` in pixels, or nothing scrolls

Every container is `height:100%`, which resolves against `options.element` — and **Power BI does
not guarantee to size that element**. When it doesn't, every percentage below resolves to auto, the
root grows to fit its content, `overflow-y:auto` has nothing to overflow, and everything past the
bottom edge is clipped by the iframe with no scrollbar.

Two lines in `update()` are the fix:

```ts
this.container.style.width  = `${Math.max(0, Math.floor(options.viewport.width))}px`;
this.container.style.height = `${Math.max(0, Math.floor(options.viewport.height))}px`;
```

A flex scroll pane also needs `min-height:0` (the default `min-height:auto` is content height, so
it cannot shrink below its contents). That one is necessary but **not sufficient** — fixing it
alone changes nothing, which is the diagnostic: if `min-height:0` doesn't help, the parent has no
definite height.

⚠ `visual-board` and `visual-scorecard-comments` carry the viewport fix. **`visual-comments`,
`visual-otif-hits` and `visual-revisions` do not** — they use the same `height:100%` pattern and
are exposed to the identical bug. If a grid in any of them ever "won't scroll", this is the first
thing to check.

### Field-well binding rules

These are hard rules. Breaking any of them produces an OOM, a silently unfiltered grid, or a
picker that offers one value.

- **Bind `[Current User (Grid)]`, never `[Current User]`**, on any grid over `FactSalesDetail`:

  ```dax
  Current User (Grid) = IF ( NOT ISBLANK ( [Order Lines] ), USERPRINCIPALNAME () )
  ```

  `SUMMARIZECOLUMNS` prunes a group-by only two ways: AUTOEXIST within one table, and dropping rows
  where every measure is blank. The `DatePeriods` slicer reaches `FactSalesDetail` cross-table, so
  it prunes the grid *only* via blank-row removal — and `USERPRINCIPALNAME()` is never blank, which
  switches that off and hands the grid every row (82,431 instead of 85). Gating on an already-folded
  measure costs nothing and restores it. A revision-log equivalent needs its own gate measure over
  its own fact.
- **Keep a blankable measure in `Columns`.** The grid respects the page slicers only because one is
  there; removing `[Order Lines]` / `[Order Lines (Late)]` re-breaks filtering on its own.
- **Never bind a dimension column** (`Dim Region[Region]`, `Dim Region[CompanyNumber]`) on these
  grids — use the fact-side twin (`FactSalesDetail[Order Company]`). A dim column plus a
  non-blankable measure is a full cross join. Dimension columns from a 1:1 bidirectional hop are
  also what caused the wide-grid OOM; `RELATED()` calc columns on `FactSalesDetail` are the fix.
- **The Company List well takes a MEASURE, not a column.** A Grouping column is part of the
  group-by, so a page filtered to one company leaves the People panel offering only that company —
  and a disconnected table cross-joins the grid instead. Bind `[Company List (All)]`:

  ```dax
  Companies =                                  -- calculated table, deliberately UNRELATED, hidden
      FILTER (
          DISTINCT ( SELECTCOLUMNS ( FactSalesDetail, "Order Company", FactSalesDetail[Order Company] ) ),
          NOT ISBLANK ( [Order Company] ) && [Order Company] <> ""
      )

  Company List (All) =
      IF ( NOT ISBLANK ( [Order Lines] ), CONCATENATEX ( Companies, Companies[Order Company], "," ) )
  ```

  Unrelated ⇒ nothing filters it, so the list is always complete; read through a measure ⇒ it never
  enters the group-by, so no cross join. Same `[Order Lines]` gate, for the same reason. The
  visual's `companyList` role is `kind: "GroupingOrMeasure"` and `App.tsx` splits the bound value on
  `[,;|]` when the column `isMeasure` (first non-empty row wins — every row carries the whole list),
  so a Grouping column still works. `DISTINCT` over the fact means a new JDE company appears at
  refresh with no maintenance.
- **`currentUser` stays in the grid's single dataViewMapping.** A second `table` mapping is not a
  workaround — `dataViewMappings` are *alternatives* chosen by `conditions`, not additive queries,
  and declaring two crashes the report with `TypeError: Cannot read properties of undefined
  (reading 'additionalProjections')` in `QueryGenerator.rewriteQuery`. `src/identity.ts` resolves
  the grid and the email **by role** across `options.dataViews`, so it is agnostic to how many
  dataViews arrive.

## Model fold-back

The `.m` and `.dax` files in `edw_model/` are the source of truth.

- `RevisionOverrides.m` — connection-only named expression:
  `Web.Contents(worker, RelativePath="revision-overrides", Headers=[x-secret])` → table keyed by
  `revision_key`.
- `FactScheduleChange.m` — builds `RevisionKey`, NestedJoins the overrides, and produces
  `RevisionReasonOriginal` (source `SLRFRV`), effective `RevisionReason` = override ?? original,
  `RevisionReasonOverride`, `OverrideNote`, `Excluded`. `[Is OTIF Relevant]` (DAX calc column,
  `RELATED` on the reason dim) then re-drives OTIF automatically.
- `LineComments.m` — `Web.Contents(... "comments/latest")` → latest comment + count joined onto
  Orders by `Order Line ID`.
- `ReasonCodes.m` — `Web.Contents(worker, "reason-dim")` → `'Reason Codes'`, with `[OTIF] = "X"`
  iff `otif = true`. Columns: Code, Description, Description_1 (long), OTIF, Category, Exemption
  Criteria, Active. The `FactScheduleChange[RevisionReason] → [Code]` relationship and
  `[Is OTIF Relevant]` read `[OTIF]`.
- ⚠ A **cache-buster** (`_cb` per-refresh Query param) is required on the `Web.Contents` calls —
  without it a warm mashup session serves a stale body and edits do not appear at refresh.

## Build and deploy

- **Visuals:** `npx pbiviz package` → import the `.pbiviz`. There is no Developer Mode on this
  tenant, so re-package after every source edit. Same GUID replaces in place and bindings survive;
  a new GUID is a new import. "Packaged" and "copied into every consuming `CustomVisuals/` folder"
  are one step — a report left on an older extract keeps the old behaviour.
- **Worker:** `npm run deploy` / `npm run db:init` / `npm run secret:set`.
- **Repo layout:** `writeback/worker/`, `writeback/visual-revisions/`, `writeback/visual-comments/`,
  `writeback/visual-otif-hits/`, `writeback/visual-board/`, `writeback/visual-scorecard-comments/`,
  `writeback/visual-scorecard-kpis/`.

### ⚠ Custom-visual GUIDs must be ≤ 29 chars in this repo

Desktop writes `CustomVisuals/<guid>/resources/<guid>.pbiviz.json` — the GUID appears **twice**.
The base path to the Executive Dashboard's `CustomVisuals/` is already **159 chars** (OneDrive +
`Clients\Michelman Bryan Becker\` + `Executive Dashboard\Executive Dashboard.Report\`):

```
  159  base
+   2 × len(guid)
+  23  "/resources/" + ".pbiviz.json"
─────
      must stay ≤ 256
```

A conventional `name + 32 hex` GUID is ~49 chars → 280, which is over. It fails two ways that look
like different bugs: **on open**, "Cannot read … The specified path, file name, or both are too
long"; **on save**, "Unable to save document. The File path … is too long" — the nastier of the
two, because it strands unsaved work.

Shorten the GUID, not the filename. Editing `package.json`'s `resources[].file` to a short name is
legal and *will* let the PBIP open, but it does not survive: Desktop regenerates the folder from
its own state on save and always writes the GUID-named form. 16 hex digits is ample entropy for a
tenant-local visual — `scComments3F8A2D6C41B94E57` is 26 chars → 234, with 22 to spare.
`visual-board`'s 49-char GUID is fine where it lives: OTIF's equivalent path is 250.

Escape hatch if a path problem ever appears that a short GUID can't fix: `subst X: "…\Michelman"`
and open from `X:\PowerBI Projects\…`, which strips 78 chars off everything and writes through to
the same OneDrive files. It does not survive a reboot.
