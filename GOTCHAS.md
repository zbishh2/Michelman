# Gotchas — grep this when something breaks. Not loaded per session.

One line each, present tense. If it needs a story, it doesn't belong here.

## PBIP / TMDL / PBIR
- TMDL is tab-indented; spaces silently misparse.
- No `///` comment above a TMDL relationship — breaks PBIP open.
- PowerShell 5.1 `-Encoding UTF8` writes a BOM; PBIR files with a BOM render nothing, no error. Write BOM-less.
- Custom-visual GUIDs ≤ 29 chars — the GUID appears twice in the CustomVisuals path and long paths break open/save.
- Desktop opens "Untitled" with no error when a PBIP path exceeds ~256 chars.
- An open Desktop rewrites `CustomVisuals/` and `model.tmdl` dataAccessOptions on save, discarding hand edits there. Edits under `definition/` and table TMDL files survive.
- Jumpbox Desktop (2.146) reads older PBIR schemas than local Desktop (2.155) writes; a local save can bump `$schema` versions (e.g. bookmarks to 2.1.0) past what the jumpbox opens. PBIR versions each artifact type on its own ladder — discover ladders from Desktop's minerva schema bundles, don't guess.
- `"reportVersionAtImport is not the correct type"` = `baseTheme.version` is an object, must be a string.
- PBIR drops metadata-only conditional-formatting selectors — cell CF needs `dataViewWildcard`. Grep `backColor`, not `FillRule`.
- Renaming a column in PBIR needs `displayName`; a duplicate `nativeQueryRef` is a hard render error.
- `summarizeBy: sum` on an identifier column corrupts a matrix.
- PBIR persists matrix `expansionStates`; legacy report.json doesn't.
- Live connection to external SSAS = proxy SemanticModel with `modelReference.json` + `byPath`; `byConnection` is Fabric-only. Report-level measures go in `reportExtensions`.
- A TMDL `dataType` loses to what Power Query delivers — Desktop rewrites the TMDL on refresh. Change types with a `CAST` in the SQL.
- Power BI invalidates a partition when its M changes as *text*, not semantically.
- A DAX calculated table's columns materialize only on refresh, so relationships to one are invalid on a never-refreshed PBIP ("uses an invalid column ID"). Use an import table for anything a relationship points at.
- ThemeDataColor `ColorId` N resolves to theme `dataColors[N-2]`.
- An `actionButton`'s own `objects` (`fill`, `text`, `outline`, `shape`) are ignored when hand-written — the button draws as a bare box whatever they say, and the validator passes them. Build the look from a `shape` plus a `textbox`, and lay a transparent button on top for the click: only `visualContainerObjects` (`background`/`border` off, `visualLink`) take effect. Putting those style objects under `visualContainerObjects` instead makes the whole report fail to open.
- Cross-report navigation is `visualLink` `type: 'WebUrl'` + `webUrl` — the workspace URL of the target page. `PageNavigation` reaches pages in the same report only.

## DAX
- `1 - DIVIDE(...)` returns 1 on an empty period → false 100%. Write `(a-b)/a` with DIVIDE instead.
- `FILTER('Table', ...)` filters the expanded table — simulating a report filter that way moves unrelated measures. Use a column predicate.
- `CALCULATE` in a calc column depends on every column of its own table; two such columns = circular dep that breaks on *open*, not on lint.
- Report grids can't use `USERELATIONSHIP`; whichever relationship is active governs grids.
- A non-blankable measure (e.g. `USERPRINCIPALNAME()`) in a field well disables slicer pruning on cross-table grids. Gate it: `IF(NOT ISBLANK([X]), ...)`.
- Dimension columns pulled across a 1:1 bidirectional hop into a group-by cause OOM; use `RELATED()` calc columns on the fact instead.
- `VALUES(dim[col])` includes the relationship's blank member wherever the fact carries keys the dim has no row for, so counting "everything except X" comes back one too high and any `<= 1` guard never fires. List the members you want instead of excluding the ones you don't.
- A measure written as `CALCULATE(x, dim[col] = "A")` ignores a slicer on that same column — the inner filter wins. For per-member measures that must still answer to a slicer, gate them: `IF("A" IN VALUES(dim[col]), CALCULATE(...))`. The gate is inert on pages with no slicer on that column, since `VALUES` then returns every member.

## SSAS
- `BIQLTabular_ISH` `Inventory Snapshot` carries each position once per cost method — filter `TRIM([CostMethod]) = "07"` (standard cost) or quantities fan out.
- SSASPROD is compatibility level 1500 (SSAS 2019): no `COALESCE` in any DAX the server evaluates — RDL CommandText, live-connection report measures, native import queries. Use `IF(ISBLANK(x), y, x)`, or nothing at all under `TRIM` (TRIM coerces BLANK to `""`). Local-model DAX is unaffected, and the local mount runs Desktop's modern engine so it cannot catch this — only prod can. `CONTAINSSTRING`/`SELECTEDVALUE` are safe at 1500.

## SQL / Oracle→T-SQL porting
- EDW is case-sensitive: column names AND string predicates.
- Oracle `trim(x) = ''` is NULL-equivalent; T-SQL port needs an explicit `= ''` check.
- Cognos list panels render DISTINCT implicitly — port needs `SELECT DISTINCT`.
- `JUL2DATE(x)` → `CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,DATEFROMPARTS(1900+(x/1000),1,1)) END`.
- Oracle day-of-week (Mon=1) → `(((DATEDIFF(DAY,'2003-01-06',d)%7)+7)%7)+1`.
- Power BI wraps a native query as `SELECT * FROM (<query>)`: no leading `WITH`/CTE (rewrite the chain as nested derived tables) and no `ORDER BY` anywhere (sort in the visual). Count parens in the query string before shipping.
- JDE julian 0 arrives as a 1900 date — guard zero dates.
- F4211 sales history decays into F42119 — UNION it.
- ODS sometimes carries literal `'NULL'` strings.
- `OUTER APPLY` and `ROW_NUMBER` derived tables get inlined per-row by Power Query native-query lookups — materialize a `#tmp` with an index, one batch, `EnableFolding=false`.
- `SALES_FACTOR` = `F41002.UMCONV / 10^7` (line UOM → primary UOM).
- Big scans against ODS/EDW: `WITH (NOLOCK)` — table-lock escalation blocks the replication writers.

## Cognos
- List panels paginate at 20 rows — a screenshot is page 1, not the result.
- Cognos count cards can disagree with their own detail rows (fan-out artifacts).
- Reports 08/10 have a hard-coded `DATE '2026-06-30'` upper bound — empty exports since July are the source, not the data.
- `displayOrder="DMY"` (not `dateStyle`) drives day-first rendering.
- Cognos `label=` → PBIR `displayName`.
- A report embedded in a workspace with no Report Studio entry: widget menu → "Save As Report…", then Tools → Copy Report to Clipboard (XML) and Query Explorer → Show Generated SQL/MDX.

## Validation
- Tight capture: pull Cognos export and PBI numbers minutes apart or the compare is unfalsifiable.
- PBI formatted export rounds — round half-up on both sides before comparing.
- Validation workbooks use live `EXACT()` formulas, never hardcoded TRUE/FALSE.

## Environment
- Gateway/jumpbox identity is `ZackB@michem.com` — wrong domain looks like a rights problem ("failed to impersonate") but isn't.
- Jumpbox is RDP-only by AD policy; WinRM denies by design.
- The ambient `CLOUDFLARE_API_TOKEN` env var is the wrong (personal) account — the Michelman token is `writeback/CF Token.txt` (utf-8-sig).
- A newly deployed Cloudflare Worker 404s for a few seconds.
- Custom visuals: a pbiviz that won't scroll = no pixel height in the chain; stamp `options.viewport` in px onto the container and give flex panes `min-height:0`.
- Custom visuals: the Windows-native scrollbar inside a pbiviz renders blurry and reads as foreign chrome; every scrolling pane carries `scrollbar-width:thin; scrollbar-color:#c8c6c4 transparent`.
- Custom visuals load from `cache.abf`'s document image, not `CustomVisuals/` on disk — `pbip-shoot`'s reload never shows a repackaged visual; only re-importing the `.pbiviz` in Desktop does.
- `USERPRINCIPALNAME()` in Desktop returns the machine account, not the AAD identity.
