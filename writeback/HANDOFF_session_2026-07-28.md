# Handoff — OTIF writeback session, 2026-07-28

Written for whoever picks this up next. Read "Do this first" before touching anything.

Repos in play:
- `C:\Users\Zack\Documents\Code\michelman\writeback` — Worker, D1, four custom visuals
- `C:\Users\Zack\Documents\Code\Michelman\PowerBI Projects\OTIF` — the PBIP (report + model)

---

## Do this first

The report was left in a **working but un-gated** state. Two things are true:

1. **Import the rebuilt visuals** (see the version table below). What is currently imported into the
   PBIP is older than what is built in `dist/`.
2. **Do NOT re-bind `[Current User]` on the wide grids.** It is unbound on purpose — see
   "The blocker" below. Re-binding it will hang the report again.

Power BI Desktop should be **closed** while editing the PBIP; it rewrites `CustomVisuals/` and
`model.tmdl` `dataAccessOptions` from its own state on save.

---

## Visual versions

Imported column read from `OTIF.Report/CustomVisuals/*/package.json` on 2026-07-30.

| Visual | Imported in PBIP | Built in `dist/` | Import? |
| --- | --- | --- | --- |
| Order Line Comments | 1.0.3.0 | 1.0.3.0 | no — current |
| Revision Log Editor | 1.0.1.3 | **1.0.2.0** | yes — never got the companies build; + status bar |
| OTIF Actions & Comments | 1.0.1.0 | **1.0.4.0** | yes — WYSIWYG rich text on Lexical (2026-07-30) |
| Reason Code Editor | 1.0.7.0 | 1.0.7.0 | no — current |

Import via *Visualizations pane → ⋯ → Import a visual from a file*. Writing the folder by hand does
not work; Desktop deletes it.

**OTIF Actions & Comments 1.0.4.0 (2026-07-30)** — WYSIWYG editing on **Lexical** (Meta's editor
framework). The author sees bold text, never `**`.

Supersedes two same-session builds; **neither should be imported**: 1.0.2.0 (marker-inserting
toolbar over a plain textarea — syntax visible while typing) and 1.0.3.0 (hand-rolled
`document.execCommand` WYSIWYG). 1.0.4.0 swapped the hand-rolled editor for the library so nobody
has to maintain caret, undo, list and paste behaviour by hand.

Toolbar: **B**, *I*, ~~S~~, bulleted and numbered list, plus Ctrl+B / Ctrl+I. Buttons light up when
the caret is inside that format. Markdown shortcuts also work live (`**x**`, `- `) for anyone who
knows them — nobody has to.

### The layer split — read this before changing anything here
- **Editing** is Lexical. `src/RichTextEditor.tsx`.
- **Display** is NOT. `src/richtext.tsx` renders posts as plain React nodes; mounting an editor per
  post to show it would be wasteful, and the read path stays free of any innerHTML.
- **Storage is unchanged**: markdown-ish plain text in `board_comments.body`, converted at the
  boundary by `@lexical/markdown`. Editing experience and storage format are independent choices —
  see the storage rationale below for why the column stays text.

Both halves must agree on the dialect: star-only emphasis, strikethrough, inline code, bulleted and
numbered lists. No headings, quotes, code blocks or links.

### Things that were NOT free, and will bite whoever ports this
- **`moduleResolution` had to change.** Lexical publishes subpath `exports` maps; the legacy
  `"node"` resolver ignores them and silently resolves to the `typescript-too-old.d.ts` sentinel
  Lexical ships, which surfaces as *"has no exported member"* on every single import. `tsconfig.json`
  is now `"module": "esnext"` + `"moduleResolution": "bundler"`. Also note **pbiviz parses
  tsconfig.json with strict `JSON.parse` — no comments allowed**, unlike normal tsconfig handling.
- **Lexical backslash-escapes plain text on export.** `MarkdownExport` runs
  ``output.replace(/([*_`~])/g, '\\$1')``, so `order_line_id` is stored as `order\_line\_id`. That
  backslash is real — it reaches D1, CSV exports, `comment_history`, and would reach
  `LineComments[Latest Comment]`. `readMarkdown()` strips those escapes on the way out. Safe because
  the dialect drops the underscore transformers, so `_` is already inert on the way back in.
- **`shouldPreserveNewLines` must match on both sides** (3rd arg of `$convertToMarkdownString`, 4th
  of `$convertFromMarkdownString`). Without it, `"Actions:\n- chase Ivan"` round-trips to
  `"Actions:\n\n- chase Ivan"` and the post grows a blank line **every time someone edits it**.
- The inline editor carries `key={c.id}` — the surface seeds only on mount, so without it, editing a
  second post would reuse the instance and show the first post's text.
- `Enter` posts and `Shift+Enter` breaks the line, **except inside a list**, where Enter makes the
  next bullet (`KeysPlugin` walks up from the caret looking for a `ListItemNode`).

Covered by `md-roundtrip.test.mjs` — 18 cases run headlessly via `@lexical/headless`, no browser:
`node md-roundtrip.test.mjs` from `visual-board/`. It caught both of the escaping/newline defects
above. **Re-run it after any Lexical upgrade** — the escaping rule is library internals and can move.

**Cost:** bundle 56.5 KB → 150 KB. Irrelevant for an org-imported visual. The 5 `npm audit` high
findings are the pre-existing eslint/minimatch/brace-expansion dev chain, not Lexical, and none of
it ships in the bundle.

**Known limit (unchanged):** a literal `**` typed by hand round-trips and comes back bold. There is
no escaping layer, by choice — escaping is exactly what puts backslashes in the exported text.

### Storage rationale (unchanged, and the reason not to store HTML)
`board_comments.body` stays a plain TEXT
column holding what the author typed (`**urgent** — chase Ivan`). Two reasons that matters:

- Anything reading the column outside the visual — a CSV export, a D1 query, `comment_history` —
  still gets something legible. `**urgent**` degrades gracefully; `<b>urgent</b>` does not.
- If this is ever ported to **Order Line Comments**, that body folds into the semantic model as
  `LineComments[Latest Comment]` and renders in ordinary Power BI table visuals and tooltips, which
  show text literally. Markdown reads acceptably there; HTML tags would be noise. **So if this is
  ported to the line-comment visual, keep the same split: WYSIWYG editing, markdown in the column.
  Storing HTML is what would break, not the editor.**

The **display** path emits React nodes, never an HTML string — no `innerHTML` /
`dangerouslySetInnerHTML`. React escapes text nodes by construction, so a post containing
`<script>` is displayed, not executed. (Lexical manages its own editing DOM internally; that is
fine here because `eslint.config.mjs` ignores `node_modules/**`, so the certification lint only
polices our source. Certification itself is not in play — these visuals are imported from file, not
published to AppSource.)

Two deliberate limits, both learned from testing the grammar:
- **`_italic_` is not supported** on the parse side, only `*italic*`. Suppressing intraword
  underscores the way real markdown does needs a regex lookbehind; without it `RFRV_code_name`
  reads back as `RFRVcodename` with the middle italicised. This domain is wall-to-wall underscore
  identifiers (`order_line_id`, `person_key`, `reason_dim`, `IM_HoursLogged`), so an underscore is
  likelier to be a field name than emphasis. Invisible to authors now that the toolbar writes the
  markers, but it governs what any hand-written or migrated body will do.
- Blocks stop at bullet and numbered lists. No headings, quotes or tables — the panel is ~150px
  tall and authors type two sentences into it.

Links: a bare `https://…` is auto-linked, but a plain `<a href>` is inert inside the sandboxed
visual iframe, so clicks route through `host.launchUrl()` (now captured in `visual.tsx`). Without a
host the URL renders as coloured text rather than a dead link.

No Worker or D1 change — `body` was already TEXT and is stored verbatim.

**Reason Code Editor 1.0.7.0 (2026-07-30)** — fixes "OTIF Reason Codes Maintenance is read-only on
my Desktop". Nothing was wrong with the roster or the field well: `people` held
`desktop-pkqsmbt\zack` as an active admin and the visual's `currentUser` well was bound to
`[Current User]`. The visual's `normalizeActorEmail()` required an `@`, so Desktop's Windows
principal (`DESKTOP-PKQSMBT\Zack` — what `USERPRINCIPALNAME()` returns outside the Service) was
discarded, the viewer resolved to *no identity*, and the grid fell back to read-only. It now
accepts `DOMAIN\user` alongside a UPN; anything else is still rejected so a stray text column
bound to the well cannot pose as an identity.

Two changes came with it so the next occurrence self-diagnoses:
- The read-only banner splits the old "no field bound" message into **unbound**, **bound but
  unreadable** (prints the raw value), and **not-on-the-list** / **not-an-admin**. The old wording
  claimed an unbound field well in a case where the well *was* bound, which is what made this take
  two sessions to find.
- The **People** button is no longer admin-only, and the panel opens for non-admins as a read-only
  roster with a "Signed in as …" strip naming the identity being matched and highlighting your own
  row. Being locked out is exactly when you need to see who can unlock you. Every mutation control
  still hides for non-admins, and the Worker's admin check (403) is unchanged — no Worker redeploy
  was needed, since `actorEmailOf()` never required an `@`.

The same `@` check still exists in **Order Line Comments** (`src/util.ts`) and **Revision Log
Editor** (`src/format.ts`) — both will be read-only on Desktop for the same reason. Not touched
here; port the fix when either is next rebuilt.

**Order Line Comments 1.0.2.0 (2026-07-29)** — the People panel's Companies field is now a
checkbox dropdown instead of a comma-separated text box, in both the add-person row and the
inline row editor. Companies are the edit permission, so a typo used to silently grant or revoke
access; a picked list cannot be mistyped. Admins show "All companies" (disabled — the role already
implies every company). The list comes from an optional **Company List** field well; left empty it
is derived from the Order Line ID's first segment at zero query cost, which is the recommended
setup. If you do bind the well, use `FactSalesDetail[Order Company]` — a *dimension* column there
adds a join to this grid's group-by (measured: 40 ms → 200 ms with `Dim Region[CompanyNumber]`).
An "Other code…" box in the dropdown still allows granting a company with no rows in the visual.
Only visual-comments got this; visual-revisions and visual-otif-hits still have the text input.

**Row-count status bar (2026-07-29)** — all three grids now show `Showing 200 of 12,345 rows —
scroll for more · filtered from 82,430` beneath the totals row, plus an amber warning when Power
BI's 30,000-row `dataReductionAlgorithm` cap is hit. Rows render in windows of 200 as you scroll,
so a partly-rendered grid used to be indistinguishable from a truncated one. **There is no 500-row
grid cap** — the only 500s in the code are the column-filter dropdown's value list (already
disclosed in-menu as "Showing 500 of N — search to narrow"; this is Ivan's item #34) and the
audit-log API's default `limit=500`.

---

## What shipped and is verified

### 1. Company-scoped edit permissions

Company scope IS the edit permission. `editor` / `restricted` no longer gate anything; only `admin`
does.

| Viewer | May edit |
| --- | --- |
| `admin` | every company, and manages the People list |
| listed with companies | rows whose Order Company matches |
| listed, no companies | read-only |
| not listed | read-only |

No new field binding was needed: Order Line ID is `<company>,<order>,<type>,<line>`
(`00010,74,CM,4.000`), so the company is the first comma segment. `revision_key` opens with the same
Order Line ID, so one helper covers both visuals.

Enforced in two places deliberately — the visuals grey the cell and put the reason in the tooltip;
the Worker 403s regardless of what the client believes.

Verified live: scoped editor allowed on 00010, `403 not approved for company 00020`; unlisted person
`403 not on the approved editors list`; admin edits any company. Test data cleaned up.

New D1 tables: `people_companies`, `comment_history`. `GET /people` now returns `companies: string[]`.

### 2. Comment audit log

`comment_history` records create/edit/delete with before **and** after text. Admin-only panel
(`GET /comment-history` 403s for non-admins), matching the Revision Log's.

### 3. Shared People editor

`src/permissions.ts` is byte-identical across `visual-comments`, `visual-revisions`,
`visual-otif-hits`. All three People panels gained a **Companies** field (comma-separated;
`10` / `0010` / `00010` all normalise to `00010`).

### 4. Region tagging on the board (Yvonne's ask)

`board_comments.region` ∈ {Americas, EMEA, Asia} or NULL = "all regions", CHECK-constrained.

**Judgment call to be aware of:** the ask was worded "each company … Americas, EMEA, or Asia", but
those three are **regions**, not companies. Built as regions because `Dim Region` in the model
already maps `00010→Americas, 00020→EMEA, 00030/34/35→Asia`. Switch to company grain if Yvonne
actually wanted five JDE companies.

Untagged posts stay visible under every filter, so nothing needed back-filling.

Live-verified: each region round-trips; `apac`→Asia aliasing; `Atlantis` → **400**, never a silent
widening to all regions; `?region=EMEA` returns EMEA + untagged; region-only PATCH retags without
touching the body.

Visual: filter chips on the title line (the panel is only ~150px tall), a region select in the
composer and in the edit row, and a badge per post.

### Deployed state

- Worker version **`1144d7f1-b8fc-49b7-9127-0184423f5c43`** (region support; the gating deploy was
  `46c4e10f`)
- D1 `michelman-writeback`: 11 tables, plus the `region` column
- Migrations applied: `schema-people-companies.sql`, `schema-board-comments-region.sql`
- Cloudflare token: `writeback/CF Token.txt`, **UTF-8 with BOM — read with `encoding='utf-8-sig'`**.
  The `CLOUDFLARE_API_TOKEN` env var is a *different, personal* account and will fail with
  `Authentication error [code: 10000]`.
- New Worker routes 404 for a few seconds after deploy — that is edge propagation, retry.

---

## The blocker: identity on the wide grids

**Do not re-bind `[Current User]` on the Order Line Comments or Revision Log grids.**

### What happened

The Companies editor was already shipped and working; the reason it looked missing was that
`currentUser` was bound on **none** of the four writeback grids (and on one page it was bound to the
wrong measure entirely — `OTIF Episodes (latest line/reason only)`). With no identity, `isAdmin` is
false, so every admin control silently disappears.

Binding it correctly then broke the report: *"Query has exceeded the available resources"* in the
Service, endless churn in Desktop.

### Measured on the live model

Real 20-column order-line query (~82,430 rows), via the powerbi-modeling MCP:

| Query | Result |
| --- | --- |
| 20 cols + `SUM(Days Moved)` | **85 ms** |
| \+ `[Current User]` | **OOM after 72 s** |
| \+ a constant **string** measure | timed out at 240 s |
| \+ a constant **integer** measure | timed out at 100 s |

`SUM` folds into the storage engine. **Any** non-foldable scalar forces the formula engine to
materialize all ~82k groups. So this is group-by width, not `USERPRINCIPALNAME`, and "make the
measure cheaper" is not a fix.

### A failed fix — do not retry it

Splitting `currentUser` into a **second `table` dataViewMapping** crashed Desktop:

```
TypeError: Cannot read properties of undefined (reading 'additionalProjections')
  at QueryGenerator.rewriteQuery
```

`dataViewMappings` are **alternatives** selected by `conditions`, not additive queries. Reverted;
both visuals are back to one mapping (that is what 1.0.1.3 is).

### Prior art checked — no help

`Terrasmart/DeliveryReliability` is where this visual code was ported from. Same shape: `currentUser`
as a Measure in a single table mapping, `top 30000`. It has the full role gating implemented
(`isAdmin`, `canEditPlannedShipDate`, disabled cell + tooltip).

**But it was never switched on.** `currentUser` appears **0 times** in DR's `report.json`, and there
is **no `USERPRINCIPALNAME` measure anywhere in DR's semantic model**. So `currentUserEmail` is
permanently null there → `canEditPlannedShipDate` is false for everyone.
`HANDOFF_role_permissions.md` still lists it as "The outstanding task".

Two consequences:
- DR is **not** evidence the measure approach scales — it never ran the query.
- **Likely live bug in DR** worth reporting: nobody can edit Planned Ship Date.

No RLS in any neighbour repo (DR, SupplierReliability, MRP, QMS, CorrugatedERP, LeanGo). Jet
Container has nine `roles/*.tmdl` but they are empty shells — `modelPermission: read`, no
`tablePermission` filters, i.e. workspace access, not row filtering.

### Current state and the options

Left **unbound** on the four wide grids; still bound on the two small ones (Reason Code Editor,
Actions & Comments), where the query is tiny and admin identity works.

Consequence: on the wide grids nobody is identified, so nobody can edit comments client-side. The
People panel now **says why** instead of failing silently. The Worker still rejects unauthorized
mutations, so this costs the greyed-out cell, not the security.

Three ways forward, needs Zack's call:

1. **Leave as-is.** Grids render in ~85 ms; comment editing on the wide grids is off.
2. **Bind only where the grid is reliably filtered small** (e.g. OTIF by Reasons after a chart
   click). **The row-count threshold was never measured** — the probes that would have quantified it
   died when Desktop crashed. Treat "small enough" as unknown.
3. **Identity as a grouping column instead of a measure** — a small per-viewer table (the D1
   `/people` feed is already an M query in this model) plus an RLS role on `USERPRINCIPALNAME()`,
   bound to `currentUser` as a Grouping. A group-by column folds into the storage engine. Cost: the
   report gains an RLS role, and a disconnected table cross-joins the grid unless RLS reduces it to
   exactly one row. **Not built** — touches the model, not just a visual.

**Useful unknown that would decide between 2 and 3:** DR's checked-in PBIP may be stale versus what
is published. If the live DR report *does* have the measure bound and gating works in production,
that proves the measure is affordable at DR's row count and makes option 2 viable. Ask whether AJ
Penley can actually edit Planned Ship Date today.

---

## Other things changed in the PBIP this session

- Fixed the `currentUser` binding on `ac7325…` which pointed at `OTIF Episodes (latest line/reason
  only)` — an expensive measure in the wrong slot. Now removed with the rest.
- `visualInteractions` on page `d75396…` (OTIF by Reasons) so the left chart cross-filters the line
  table. `"DataFilter"` is the correct type token.
- All three Order Line Comments grids carry a `[Matches Reason Selection]` visual-level filter. This
  is **not** the performance problem — its `IF` short-circuits when no reason is selected, and it
  measured 19–38 ms. Leave it alone.

## Still open from Ivan's list

`#2` (Cust Seg on canvas vs filter pane — needs Zack's call), `#4` (custom date range), `#14` (no
chart on Shipped as Promised to hang an orange total line on — needs Zack's call), `#15` (Requested
tab layout parity), `#33` (OTIF-impact toggle), `#34` (item filter 500 cap), `#39` (Maintenance row
count), `#47` (shared column sort).

Also never decided: switching `FactScheduleChange[OrderLineID] → FactSalesDetail[Order Line ID]` to
bidirectional, which would make reason filtering immune to Desktop clobbering the visual-level
filters. Offered twice, never answered; it changes measure behaviour report-wide.

## Small thing worth doing

The two real board comments hand-prefix their region in the text — `"America - Reviewing
problematic item…"`, `"EMEA - testing new carrier…"` — and are currently untagged, so they show under
every filter. Offered to tag them and strip the prefixes; no answer yet. Two rows, `PATCH
/board-comment/:id` with `{"region": "..."}`.

---

## Ivan's full 49-item list

Transcribed from Ivan's document. `[x]` = done, `[ ]` = open. Ivan's own colour coding is noted
where it matters (green = Zack had marked it done, yellow = outstanding, red = blocked, cyan =
clarification question).

### All Tabs

- [x] **1.** Replace Customer Segmentation filter with SLO Segmentation (STD / Strategic).
- [ ] **2.** Keep the existing Customer Segmentation filter available in the right-hand panel.
  *It is on the **canvas**, not the filter pane. Needs Zack's call — Ivan literally asked for the pane.*
- [x] **3.** Remove STD and Strategic values from the current Customer Segmentation filter.
- [ ] **4.** Date Range filter: can we add a custom date range option? (Portia request)
  *`DatePeriods` is a disconnected period table; needs a Custom member + Between slicer.*
- [x] **5.** The Reason filter does not appear to refresh the data correctly.
  *Root cause: the pivots read `[Shipped as Promised % (Lines)]`, built on a frozen calc column the
  Reason slicer cannot move. Swapped to reason-aware twins.*
- [x] **6.** Sold To selection is difficult to use and does not appear to function reliably — remove from all tabs.

### Tab — Summary Shipped as Promised

- [x] **7.** Rename to Summary Shipped as Promised.
- [x] **8.** Replace MAP with ASIA in display (sum of companies 30 + 34 + 35 combined).
- [x] **9.** Standardize chart colors: US = Blue, EMEA = Green, ASIA = Dark Yellow.
- [x] **10.** Optional target line in charts (red dotted 96%) that can be adjusted or removed.
- [x] **11.** Include the total in orange solid line.

### Tab — Shipped as Promised %

- [x] **12.** Rename tab to "Shipped as Promised".
- [x] **13.** Strategic Customer section in the Orders view not properly aligned/formatted.
- [ ] **14.** Include the total in orange solid line.
  *This tab has six tables and **no chart** — nothing to attach a line to. Add a trend chart, or call
  it covered by the matrix totals? Needs Zack's call.*

### Tab — Shipped as Requested %

- [ ] **15.** Can this tab follow the same layout as the previous tab, including both Order and Line assessments?
  *Needs order-grain Shipped-as-Requested measures + 3 more tables.*
- [x] **16.** Rename to "Shipped as Requested".
- [x] **17.** Include the total in orange solid line.

### Tab — OTIF By Reason

- [ ] **18.** Clarify the purpose of the Refresh Comments button. *(question for Ivan, not build work)*
- [ ] **19.** Clarify the purpose of the Reset Layout button. *(question for Ivan, not build work)*
- [x] **20.** Clarify the People button. Can it be linked to company ownership instead of individuals?
  *The buried ask — company-level ownership — is what shipped this session as company-scoped
  permissions. "There is not the add people button" was the unbound `currentUser` measure.*
- [x] **21.** The order line tab is not in sync with others when something is selected.
- [~] **22.** Top-right table: Order Number filter does not work, Material filter does.
  *Struck through by Ivan himself — "this works this morning...". No action.*
- [x] **23.** Display dates in the order line table in sequence: Order Date, Original Promised Date,
  Requested Date, Promised Delivery Date, Actual Ship Date.
- [x] **24.** When a reason is selected the Revision Log updates but Order Line Comments does not.
  *Fixed via `[Matches Reason Selection]`; the relationship is many-to-one so a plain slicer could
  never reach the grids.*

### Tab — OTIF By Date Moved

- [x] **25.** Move back to average days, not sum of days.

### Tab — OTIF By Department

- [x] **26.** On the bottom right quadrant, use the average days.
  *Aggregation was already Avg; the header still read "Sum of Days Moved", which is why it looked unfixed.*

### Tab — OTIF Analysis

- [x] **27.** Line number format differs from the one used in OTIF Maintenance.
- [x] **28.** Next to sold to, include the ship to reference.
- [x] **29.** Next to customer segmentation, include also SLO segmentation.
- [x] **30.** Quantity order/shipped should be integer and with UoM.
- [x] **31.** Dates as above: Order date, Original promised, Requested date, Promised Delivery, Actual ship.
- [x] **32.** Reason is not filtering here.
- [ ] **33.** Filter to select only orders with OTIF impact, or all orders. *Not started.*
- [ ] **34.** Item number filter shows only first 500 items and won't select an item last in the list.
  *Plus Ivan's sub-question: Order 2600086 line 2 (item Totequilt) appears despite the S stock type
  filter. Diagnostic — needs a refreshed live model.*
- [x] **35.** Total lines # seems a sum instead of a count; total quantity should be consistent with UoM.

### Tab — OTIF Reasons Pareto

- [x] **36.** Reason is not filtering.

### Tab — OTIF Days Moved Pareto

- [x] **37.** Reason is not filtering. *The combo chart was Avg but the Pareto table was still SUM.*
- [x] **38.** Use the average days.

### Tab — Maintenance

- [ ] **39.** Table extraction is shorter than other screens; filtered to OTIF but line counts still don't match.
  *Diagnostic — needs a refreshed live model to diff row counts.*
- [x] **40.** Reason is not filtering here; allow selecting all lines (also blank) and ones with reason.
- [x] **41.** Next to sold to, include the ship to reference.
- [x] **42.** Next to customer segmentation, also SLO segmentation.
- [x] **43.** Quantity order/shipped should be integer and with UoM.
- [x] **44.** Dates as above: Order date, Original promised (this is missing), Requested date,
  Promised Ship, Actual ship.
- [x] **45.** Add filter BU Revenue.
- [x] **46.** Remove filler line.
- [x] **46b.** *(Ivan's trailing note)* "Permission. Authorized commenter/revisor of hit should be
  managed at company level." **Shipped this session** — company-scoped permissions + audit log.

### Tab — OTIF Reason Code Maintenance

- [ ] **47.** "I modified the sorting of the columns. Hopefully this will be available to others."
  *D1 `user_layout` is keyed per-email; needs a shared default row.*

### Other

- [x] **48.** Portia: scrollable comments section at the bottom of Summary Shipped as Promised.
  *Built as the Actions & Comments visual + `board_comments` D1 table. Now also region-filterable
  per Yvonne.*
- [x] **49.** Show hits vs average days affected in a 2-dimensional chart.
  *Built as a table + scatter on a new "OTIF Hits vs Days Moved" page.*

### Tally

**39 done** · **8 open** (2, 4, 14, 15, 33, 34, 39, 47) · **2 questions for Ivan** (18, 19) ·
**1 withdrawn by Ivan** (22).

Of the 8 open: **2** and **14** are decisions for Zack, not work. **34** and **39** are diagnostic
and unblock once the model is refreshed. **4**, **15**, **33** and **47** are straightforward build
work that was offered and never started.

### 2026-07-28 continuation status

- Item **15** is now built and desktop-validated: the Shipped as Requested page has All / STD /
  Strategic **Order** assessment tables in addition to its Line assessment tables.
- Item **33** is implemented in the PBIP (the Order scope slicer and its visual-level filter are
  loaded in Desktop); it remains un-checked in the Codex ledger until its filtered row count is
  independently observed.
- Item **47** is deployed in Worker version `9b4506c5-b241-4a16-baef-e8143a86425f`: layouts now
  load from one shared default and only a Worker administrator may publish or reset it. Anonymous
  reads and non-admin write rejection were verified live. A shared Comments layout still needs its
  first save by a real admin; `zackleango@jetcontainer.com` returned `403 admin required`, so no
  identity was impersonated and the ledger stays un-checked.

---

## Validation ledger — 2026-07-28

Each item must be independently checked in the report. The two boxes are deliberately separate:
the first is Claude's prior validation and the second is Codex's validation for this session.

| Item | Claude | Codex |
| --- | :---: | :---: |
| 1 | [ ] | [ ] |
| 2 | [ ] | [ ] |
| 3 | [ ] | [ ] |
| 4 | [ ] | [ ] |
| 5 | [ ] | [ ] |
| 6 | [ ] | [ ] |
| 7 | [ ] | [ ] |
| 8 | [ ] | [ ] |
| 9 | [ ] | [ ] |
| 10 | [ ] | [ ] |
| 11 | [ ] | [ ] |
| 12 | [ ] | [ ] |
| 13 | [ ] | [ ] |
| 14 | [ ] | [ ] |
| 15 | [ ] | [x] |
| 16 | [ ] | [ ] |
| 17 | [ ] | [ ] |
| 18 | [ ] | [ ] |
| 19 | [ ] | [ ] |
| 20 | [ ] | [ ] |
| 21 | [ ] | [ ] |
| 22 | [ ] | [ ] |
| 23 | [ ] | [ ] |
| 24 | [ ] | [ ] |
| 25 | [ ] | [ ] |
| 26 | [ ] | [ ] |
| 27 | [ ] | [ ] |
| 28 | [ ] | [ ] |
| 29 | [ ] | [ ] |
| 30 | [ ] | [ ] |
| 31 | [ ] | [ ] |
| 32 | [ ] | [ ] |
| 33 | [ ] | [ ] |
| 34 | [ ] | [ ] |
| 35 | [ ] | [ ] |
| 36 | [ ] | [ ] |
| 37 | [ ] | [ ] |
| 38 | [ ] | [ ] |
| 39 | [ ] | [ ] |
| 40 | [ ] | [ ] |
| 41 | [ ] | [ ] |
| 42 | [ ] | [ ] |
| 43 | [ ] | [ ] |
| 44 | [ ] | [ ] |
| 45 | [ ] | [ ] |
| 46 | [ ] | [ ] |
| 46b | [ ] | [ ] |
| 47 | [ ] | [ ] |
| 48 | [ ] | [ ] |
| 49 | [ ] | [ ] |
