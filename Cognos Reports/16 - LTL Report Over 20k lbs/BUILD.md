# Report 16 — LTL report over 20k lbs — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > Customer Service
**Report name (XML `reportName`):** `LTL over 20000 lbs.`  •  **Page title (rendered):** `LTL Shipments over 20,000 lbs.`
**Migration tracker ID:** 142
**Stage:** **VALIDATED 2026-07-16** — probes all green (§10) + Cognos tight-capture compare 5/5 exact at detail grain (§11, one live-drift status cell). Presentation decisions settled same day: **AVERAGE subtotals** (Dave's call after the defect was raised — Cognos parity; visual.json flipped to `Avg`, needs Desktop close-without-save → reopen to pick up) and **clean `MMM d, yyyy`** (§8.8). **Report-out workbook DELIVERED 2026-07-16** (`Excel Validation\_report_out\16 - LTL over 20k lbs.xlsx` — 13-template parity, live formulas, verified: matched 5/0/0 on (Order Number, Order Line), exactly 1 FALSE = 2744344 Next Status 535 vs 530 drift; Notes carry the AVERAGE-footer finding + Dave's ruling) + `Txt Queries\LTL Over 20k.txt` exported. Remaining: publish + §8 business items (burst replacement, CSR source, carrier list, SSAS bake-off). Build record in §9.

A single-page grouped operational list of open sales-order lines whose primary quantity ordered exceeds 20,000 (lbs). One visible list, subtotaled by pick date / carrier / customer. In Cognos it is a **burst report** — output is sliced per CSR and delivered to each CSR's directory account; that machinery does not surface on the page (see §3).

---

## 0. Intake integrity — READ FIRST

| Artifact | Status | Notes |
|---|---|---|
| Report XML | **COMPLETE, untruncated** | `Report XML.xml` = byte-identical copy of `Intake\XML.txt` (20,315 bytes, `grep -c truncated` = 0, closes on `</report>`). 3 query objects (`Report`, `CAM ID`, `Query1`), 1 page (`Page1`). |
| Generated SQL | **COMPLETE** | `Intake\Generated SQL.txt`, two SELECTs. Confirmed byte-identical to the workbook "OLD report code" (`LTL.0.sql` + `User Details.1.sql`) → the **deployed** report runs the old logic (per-row `SDPQOR/10000 > 20000` in WHERE, separate `USER_DETAILS` lookup). Lilly's rewrite is a *proposed* fix, not deployed. |
| Rendered output (xlsx) | **PENDING** | No export on disk. **There is no row-count validation target yet.** Probe block 5 (`00_verify_tables.sql`) computes today's live count so the build has a number to check against; treat as order-of-magnitude until the human supplies the xlsx captured minutes apart from the refresh (tight-capture rule). |
| Screenshot | **PENDING** | Shown in chat 2026-07-15 but not saved to `Intake\`. Layout/format evidence below = **XML only**. |

**Completeness verdict:** query logic and page structure are fully specified from XML + generated SQL. The two gaps are *validation* artifacts (xlsx row count, screenshot), not build blockers. The one format inference that the xlsx would firm up: the **Scheduled Pick Date display format** (§4) — the XML carries no explicit `<dateFormat>`, so it is model-default.

---

## 1. Source route — **ODS PRODDTA (JDE), SQL Server** (chosen); SSAS is a viable mandate-preferred alternative, deferred

Evaluated SSAS → EDW → ODS per the standing rule.

### SSAS (`SSASPROD` `BIQLTabular_v2`, Live Connection) — VIABLE, but DEFERRED (parity risk)
Unlike report 12, SSAS has **no coverage gap** here — every field this report needs is modeled:
- **`Sales` fact** (F4211/F42119) carries: Status Code Next `[SDNXTR]`, Carrier Num `[SDCARS]`, Carrier Name, Scheduled Pick Date `[SDPDDJ]`, Primary Quantity Ordered `[SDPQOR]`, plus order company/number/type/UOM/line and ship-to customer.
- **`CSR for Sales Orders` dimension** (`v2.xmla` line 64299) is wired to `Sales` via `CompositeKey` (`OrderNum|LineNum|ShipToCustomerSKey`) and exposes `CSRName` / `CSRNum` / Customer Ship To. So even the CSR name — the hard part — is pre-modeled and joinable under a Live Connection.

**Why deferred, not chosen:** two parity risks against the *deployed* report:
1. **CSR source differs.** SSAS `CSR for Sales Orders` derives CSR from `BIQL.DimCustomerCommissionInfo` where `Role LIKE '%CSR%'` (joined on Customer Ship To). The deployed Cognos report derives CSR from **`PRODDTA.F42140` where `CMRTYPE='CSR'`** (joined on ship-to `CMAN8`). These are *different sources* and can yield different CSR names / different fan-out. A faithful port must reproduce F42140, not the enrichment view.
2. **`Sales` is a F4211 + F42119 union** (open + history). The status filter (525–560) should restrict to open lines, but this needs a jumpbox check that the union does not double-count.
Plus the per-line **>20,000** filter and the **23-carrier exclusion** become visual-level filters on a measure/attribute under a Live Connection — expressible but fiddly and easy to get subtly wrong.

**Recommendation:** build on ODS now for guaranteed deployed-parity (below); keep SSAS as the fast-follow the team mandate prefers, gated on a jumpbox bake-off that confirms (a) F42140-CSR vs enrichment-CSR agree, and (b) the union does not inflate counts. This mirrors the reports 08/10 "build one, note the other, pick after jumpbox test" pattern.

### EDW (`EDWPROD`) — not needed
`dbo.FactSalesDetail` (F4211) carries the order/carrier/qty/date fields, and `[EDW].[dbo].[vw_CAM_ID]` (CSRName by OrderNum) is the SQL-Server analogue of the Cognos USER_DETAILS lookup. But EDW's CSR-by-order is again a *different* derivation than F42140-CSR-by-ship-to, so it carries the same parity caveat as SSAS with none of SSAS's live-connection benefit. No reason to prefer it over ODS here.

### ODS PRODDTA — **CHOSEN**
Only route that reproduces the **deployed Cognos SQL exactly**: same `F4211` open lines, same `F42140 CMRTYPE='CSR'` CSR derivation, same per-row `>20000` filter, same 23-carrier exclusion, same `JUL2DATE` decode. **Report 04 (CM Open Sales Orders Live) is the validated precedent** — identical `F4211 + F42140 + F0101` shape; field names reused here. Guaranteed parity, single import connection.

Connection: `Sql.Database("ODSPROD","ODS")`, native T-SQL, `[EnableFolding=true]`. No CTEs (leading `WITH` breaks folding — PBI wraps as `SELECT * FROM (<q>)`); no `ORDER BY` inside the folded query (illegal in SQL Server) — sort in the visual.

---

## 2. Query objects → files

| # | Cognos query | Role | File(s) |
|---|---|---|---|
| 1 | `Report` (SQL name `Report7`) | **The only data the page needs.** F4211 open-order lines > 20k. | `Report.0.sql` (== reference `LTL.0.sql`); build = `LTL_Over_20k.m` / `.commented.m` |
| 2 | `CAM ID` | `USER_DETAILS` lookup: CSR AddressNum → Cognos `CAMID`. **Burst plumbing only, not displayed.** | `CAM ID.1.sql` (== reference `User Details.1.sql`) — **not ported to PBI** |
| 3 | `Query1` | `Report` LEFT JOIN `CAM ID` on CSR AB Number = AB Number; carries `CAMID` for the burst. Page list binds to this, but shows only `Report` columns. | `Query1.2.sql` (documentation only — no standalone generated SQL) |

`Report.0.sql` / `CAM ID.1.sql` are the standard-named authoritative copies; they duplicate the pre-existing `LTL.0.sql` / `User Details.1.sql` (reference copies from the migration workbook) — kept both, standard-named set is authoritative.

**PBI needs one table** (`LTL_Over_20k.m`). `CAM ID` / `Query1` / `USER_DETAILS` are not rebuilt (see §3).

---

## 3. Burst analysis + Power BI replacement — **the visible page does NOT need USER_DETAILS**

**What the XML says.** The report ends with:
```
<burst refQuery="Query1">
  <burstGroups><burstGroup refDataItem="AB Number"/></burstGroups>
  <burstLabel refDataItem="AB Number"/>
  <burstRecipient refDataItem="CAMID" refQuery="Query1" type="directory"/>
</burst>
```
- **Burst key / grouping** = `AB Number` (the CSR's JDE address number). Cognos runs the report once, partitions the output into one slice per CSR AB Number, and delivers each slice to a **directory recipient** = that CSR's `CAMID` (Cognos account).
- **How `CAM ID` / `Query1` relate to `Report`:** `Query1` is a LEFT JOIN of `Report` (0:many) to `CAM ID` (0:1) on `[Report].[CSR AB Number] = [CAM ID].[AB Number]`. Its sole added value over `Report` is the `CAMID` column (the burst recipient) and `AB Number` (the burst group). `CAM ID` itself is the `DW_LEGACY.USER_DETAILS` table mapping CSR AddressNum (`VENDOR_CODE`) → `CAMID`.
- **Does the rendered page use any of it?** **No.** `List1` binds to `Query1`, but its 11 `listColumn`s are all `Report` fields (see §5). Neither `CAMID` nor `AB Number` is a list column. The `Average()` re-wrap on the two quantity items in `Query1` is an identity no-op at the 0:1 join grain (value unchanged). So the CAM ID / USER_DETAILS machinery is **pure distribution plumbing**.

**Conclusion:** the Power BI rebuild is the `Report` query alone. **USER_DETAILS / CAM ID / Query1 are dropped.** The one artifact worth carrying forward is the **CSR AB Number** column (the burst group key) — kept hidden in `LTL_Over_20k.m` to power the burst replacement.

**Power BI has no burst.** Options for the human (recommendation first):

| Option | What CSRs get | Effort | Fit |
|---|---|---|---|
| **A. Single report + CSR slicer** *(recommended)* | One report; each CSR filters to themselves via a `CSR Name` (or `CSR AB Number`) slicer. | Low | Matches how the team rebuilt other multi-owner Cognos reports; no per-user infra. |
| B. RLS on CSR AB Number | Each CSR, on open, sees only their rows automatically. | Medium (RLS role + user↔AB-Number mapping table — the modern `vw_CAM_ID` / USER_DETAILS successor). | Closest to the burst's per-recipient isolation; needs the AddressNum↔account map maintained. |
| C. Power BI **subscriptions** (per-page, filtered) | Scheduled emailed snapshots — the nearest literal "burst" analogue. | Medium; one subscription per CSR, or a paginated-report data-driven subscription. | Only if the business specifically wants *pushed* per-CSR emails like today. |

Recommend **A** for the first release (fastest, no identity infra), and note **B** as the upgrade if per-CSR data isolation is a requirement rather than a convenience. **Open decision** — see §8.

---

## 4. Page layout (from XML `Page1` / `List1`)

**Page header:** one static title, **`LTL Shipments over 20,000 lbs.`** (bold, style `tt`). No date stamp in the Cognos original — add the house `Last Refreshed` card (this report is live; the as-of date is load-bearing).

**Visible list = 11 columns.** Headers render the **data-item name** — every `listColumnTitle` uses `<dataItemLabel>` with **no `label=` override**, so header text = data-item name. **No duplicate column names.** Column order (left→right) and alignment:

| # | Header | Source | Align | Format |
|---|---|---|---|---|
| 1 | Scheduled Pick Date | `JUL2DATE(SDPDDJ)` | left | date — **model default** (no `<dateFormat>` in XML). Recommend `MMM d, yyyy` (month-first; no `displayOrder="DMY"` anywhere). Confirm vs pending xlsx. |
| 2 | Carrier AB Number | `SDCARS` | left | integer, no thousands separator (`0`) |
| 3 | Customer Name | ship-to `F0101.ABALPH` | left | text |
| 4 | Order Number | `SDDOCO` | left | integer, no separator (`0`) |
| 5 | Next Status | `SDNXTR` | left | text |
| 6 | Order Type | `SDDCTO` | left | text |
| 7 | Order Line | `SDLNID / 1000` | left | number (e.g. `1.000`) |
| 8 | Carrier Name | carrier `F0101.ABALPH` | left | text |
| 9 | CSR Name | `F42140(CSR).ABALPH` | left | text |
| 10 | Primary Quantity Ordered | `SUM(SDPQOR / 10000)` | **right** (style `lm`) | `#,##0` (thousands sep) |
| 11 | Primary UOM | `SDUOM1` | left | text |

**Not displayed** (selected by the query but absent from `List1`): Order Company (`SDKCOO`, constant `00010`), the duplicate quantity column `c13`, and CSR AB Number (`c12`). `LTL_Over_20k.m` omits the first two and carries CSR AB Number **hidden** (slicer/RLS key).

### Grouping & subtotals (this is NOT a flat table)
`List1` has three nested `listGroup`s (with row-span merging on the grouped columns) plus an overall total:

| Level | Group column | Footer | Footer content |
|---|---|---|---|
| 1 (outer) | Scheduled Pick Date | subtotal row (colSpan 9) | `<pick date> - Total` + Sum(Primary Quantity Ordered) |
| 2 | Carrier AB Number | subtotal row (colSpan 8) | `<carrier> - Total` + Sum(...) |
| 3 (inner) | Customer Name | subtotal row (colSpan 7) | `<customer> - Total` + Sum(...) |
| overall | — | grand-total row (colSpan 9) | `Overall - Total` + Sum(...) |

**Build as a matrix** (not `tableEx`): row groups **Scheduled Pick Date → Carrier AB Number → Customer Name**, then the remaining fields (Order Number, Next Status, Order Type, Order Line, Carrier Name, CSR Name, Primary UOM) at leaf grain; **value = Sum of Primary Quantity Ordered**; subtotals **on** at all three group levels + grand total. This reproduces the Cognos grouped list. Confirm exact look against the pending screenshot/xlsx.

> **Matrix trap (from prior reports):** set `summarizeBy: none` on every identifier/number column — **Order Number, Carrier AB Number, Order Line, Next Status, CSR AB Number** — or the matrix corrupts. Only **Primary Quantity Ordered** aggregates (Sum).

**Sort:** the generated SQL's `order by CSR_AB_Number asc nulls last` is **burst-prep ordering**, not the visual sort. The *visual* order is the group nesting above (pick date, then carrier AB, then customer), ascending, blanks last. Set sorts in the visual (query omits ORDER BY).

---

## 5. Filters (all baked into the query — no prompts, no slicers, no date literals)

Every filter is a static `detailFilter`; **no Cognos prompts** exist, so all belong in the query, not as slicers:

| Cognos filter | Ported (T-SQL) |
|---|---|
| Order Company `= 00010` | `SDKCOO = '00010'` |
| Order Type `in (S4,S5,SZ,SC,ST)` | `SDDCTO IN ('S4','S5','SZ','SC','ST')` |
| Next Status `in (560,550,545,540,535,530,525)` | `SDNXTR IN ('560',…,'525')` |
| Carrier AB Number `not in (22 numbers)` | `SDCARS NOT IN (293371,…,316502)` |
| Carrier AB Number `<> 308636` | `SDCARS <> 308636` |
| **`Total(Primary Quantity Ordered) > 20000`** (XML) → deployed SQL applies it **per-row** in WHERE | `SDPQOR / 10000.0 > 20000` (deployed semantics — see §6/§8) |

**Expired-date-ceiling check (defect C1 from reports 08/10): NONE.** No hard-coded date bound anywhere; the only "date" is the live `JUL2DATE` decode. Report is genuinely **live** → schedule a daily refresh (import model; the open-order set moves every day).

---

## 6. Cognos defects / quirks (port faithfully, disclose to business)

1. **23 hard-coded carrier exclusions** (`SDCARS NOT IN (…22…)` + `<> 308636`). A maintenance landmine: a newly-onboarded carrier is silently *included* in the report until someone hand-edits this literal list. **Disclose to the business** (same pattern as other hard-coded-literal defects in this migration). Ported verbatim for parity; consider promoting to a maintained exclusion table later.
2. **Duplicate quantity column `c13`.** The generated SQL outputs `SUM(SDPQOR/10000)` twice (`Primary_Quantity_Ordered` and `c13`). The layout displays it **once** → `c13` dropped. No action.
3. **Per-row vs summed >20k (behavior, not cosmetic).** Deployed = per-row `SDPQOR/10000 > 20000` in WHERE (a single F4211 row must exceed 20k). Lilly's rewrite = `HAVING SUM(...) > 20000` (post-group). They differ **only if a single `(order,line)` has more than one F4211 row**. Probe block 5c measures this; block 5a/5b give both counts. We port the **deployed per-row** semantics. **Which is correct is a business question** (§8).
4. **CSR fan-out.** The CSR join is on ship-to (`CMAN8`) + `CMRTYPE='CSR'` only — no order-company/line qualifier. If a ship-to has >1 `CSR` row in F42140, the LEFT JOIN duplicates the order line (Cognos does this too). Reproduced faithfully; probe block 3 quantifies. If it over-counts, raise with the business rather than silently de-duping (would diverge from Cognos).
5. **`Average()` re-wrap in Query1.** `Query1` re-aggregates the two quantity items with `Average()`. At the 0:1 burst join this is an identity no-op on *detail* rows — **but the 2026-07-16 capture proved the list FOOTERS inherit it**: every "- Total" row computes an **Average**, not a sum (§11). The legacy report's totals are mislabeled averages. Decision §8.7.
6. **Scheduled Pick Date has no explicit format** in the XML → renders in the model default. **CONFIRMED 2026-07-16 (§11):** Cognos shows `Jul 20, 2026 12:00:00 AM` (month-first datetime with midnight timestamp). PBI built as `MMM d, yyyy`. Decision §8.8.

---

## 7. PBIP authoring notes (for the build agent)

- **Author in PBIR format** (like reports 02/03/12), not legacy `report.json`.
- **One table** (`LTL_Over_20k.m`), one page, **one matrix** visual (see §4 grouping). Ship the PBIP **comment-free**; the commented master (`LTL_Over_20k.commented.m`) stays in this folder in parallel.
- **`summarizeBy: none`** on all identifier/number columns (Order Number, Carrier AB Number, Order Line, Next Status, CSR AB Number). Only Primary Quantity Ordered is Sum.
- **Hide** `CSR AB Number` on the visual; wire it (or `CSR Name`) to a **CSR slicer** as the burst replacement (§3 option A). If the human picks RLS (option B), build the role on `CSR AB Number` instead.
- **No conditional formatting** in this report → no `dataViewWildcard` values-CF selector concern.
- **Headers = data-item names** (no `label=` overrides) → no `displayName` renames needed; the query already emits the exact header text.
- Add the house **`Last Refreshed`** card (live report).
- **Sorts** are visual-level (query omits ORDER BY) — set per §4.
- On copy-back to the jumpbox, remember the `definition.pbir` **2.0.0 ↔ 1.0.0** version knock-down (local Desktop rejects 2.0.0).

---

## 8. Open decisions for the human

1. **Burst replacement (§3):** slicer (A, recommended) vs RLS (B) vs subscriptions (C)? RLS needs the CSR-AddressNum ↔ Power BI-account map (the successor to USER_DETAILS/`vw_CAM_ID`) to be maintained.
2. **>20k semantics (§6.3):** ~~open~~ **SETTLED BY PROBES 2026-07-16** — no (order,line) has >1 F4211 row, so per-row (built) and HAVING-SUM are provably identical on current data (5 = 5, diff 0). Keep the deployed per-row port; revisit only if probe 5c ever returns rows.
3. **CSR source (§1):** F42140 `CMRTYPE='CSR'` by ship-to (deployed, built on ODS) vs SSAS/EDW enrichment CSR (`DimCustomerCommissionInfo` / `vw_CAM_ID`, by order). If the business is fine with the enrichment CSR, the SSAS Live build becomes preferred per the mandate.
4. **23-carrier exclusion (§6.1):** leave as a baked-in literal list (parity) or move to a maintained exclusion table so new carriers are handled without a code edit?
5. **Validation target:** ~~pending~~ **DONE 2026-07-16** — tight-capture xlsx + screenshot filed in `Intake\`; detail grain validated 5/5 (§11).
6. **SSAS bake-off (§1):** worth a jumpbox comparison of the ODS build vs an SSAS Live build (CSR agreement + open/history union check) to decide the strategic route for this report family?
7. **Subtotal aggregation (§11):** **DECIDED 2026-07-16 — AVERAGE (Dave Bubash, Teams 9:53 AM, overriding the earlier Sum call).** Zack raised the mislabeled-average defect with Dave; Dave: "what does Cognos do?" → average → "then keep as an average." Matrix value flipped to `Avg` (visual.json `Function: 1`, queryRef `Avg(...)`) same day. Compare workbook now ties 1:1 on all total rows. The "Total"-labeled-average quirk is ported knowingly — defect raised and accepted by Dave.
8. **Date-time suffix (§11):** **DECIDED 2026-07-16 (Zack): keep `MMM d, yyyy`** — clean date, month-first parity; the midnight `12:00:00 AM` suffix is not carried.

---

## 9. Build record (2026-07-15)

**Artifacts authored** (all comment-free; the annotated master `LTL_Over_20k.commented.m` stays in this folder):
- `PBIP\LTL Report Over 20k lbs.pbip` (+ `.gitignore`)
- `...Report\` — PBIR: `definition.pbir` (schema 1.0.0, version 4.0), `report.json` (baseTheme.version as string via `reportVersionAtImport`), `version.json`, `pages\pages.json`, one page `16f0a1b2c3d4e5f6a7b8`, four visuals: **matrix** (pivotTable), **title textbox**, **Last Refreshed card**, **CSR Name slicer**. Theme `CY24SU10.json` copied from report 12.
- `...SemanticModel\` — TMDL: `model.tmdl` (auto date/time OFF via `__PBI_TimeIntelligenceEnabled = 0`; no LocalDateTable/DateTableTemplate), `database.tmdl` (CL 1567), `cultures\en-US.tmdl`, tables `LTL Over 20k.tmdl` (partition M **verified byte-equivalent** to `LTL_Over_20k.m` by tab-de-indent diff) + `Last Refreshed.tmdl` (report-12 pattern verbatim).
- `PROBE\R16 Probe.pbip` — 11 probe tables (one per `00_verify_tables.sql` block): `01/02/03 Cols F4211/F42140/F0101`, `04 Join Drops Shipto`, `05 Join Drops Carrier CSR`, `06 CSR Fan-Out` (block 3), `07 Code Decodes` (block 4), `08 Count Parity` (5a deployed vs 5b HAVING-SUM + diff, one row), `09 Multi-Row Lines` (5c), `10 Format Spot-Checks` (block 6), `11 Live Row Count` (full deployed query wrapped in COUNT(*)). No visuals (Data-view page). ORDER BY probes (06/07/09/10) use `[EnableFolding=false]` so the top-level ORDER BY is legal (folding's `SELECT * FROM (<q>)` wrapper would reject it); the rest fold.

**Column model:** `summarizeBy: none` on all 12 columns **except** `Primary Quantity Ordered` (Sum). `CSR AB Number` `isHidden` (RLS-key alternative kept available). Formats: Carrier AB Number `0`, Order Number `0`, Order Line `0.000`, Primary Quantity Ordered `#,##0`, Scheduled Pick Date `MMM d, yyyy` (**TO-CONFIRM** vs pending xlsx — §6.6). All confirmed via MCP `GetSchema`.

**Lint:** MCP `ConnectFolder` — main model loaded **2 tables / 1 measure / 0 errors**; probe model loaded **11 tables / 0 errors**. All report/PBIR JSON parses valid.

### Matrix subtotal labels vs Cognos "<value> - Total" (deviation, disclosed)
Cognos renders each group footer as `<group value> - Total` (e.g. `28-JUN-2026 - Total`, `ABC TRUCKING - Total`) and the grand total as `Overall - Total`. **Power BI's native matrix cannot reproduce that literal text.** In a Tabular-layout matrix:
- Each subtotal row repeats the **group member value** in the row-header column (no ` - Total` suffix appended) with the `Sum(Primary Quantity Ordered)` beside it.
- The grand-total row is labelled **`Total`** by default (renamable, but there is no way to make it read `Overall - Total` and no way to append ` - Total` per group member).

So the **structure/values match** (subtotal at Scheduled Pick Date → Carrier AB Number → Customer Name via per-level `levelSubtotalEnabled`; grand total on; the 7 leaf attributes have subtotals **off**), but the **label wording differs** from Cognos. This is the standard matrix-vs-grouped-list gap (same as report 01). Left as PBI default rather than faking the text; flag to the business if the exact wording matters.

### Other authoring deviations
- **Blanks-last sort:** spec asks Scheduled Pick Date → Carrier AB Number → Customer Name ascending, **blanks last**. PBI ascending sorts **blanks first** and PBIR has no blanks-last control on a visual sort. Set ascending on all three; blanks (should be none given INNER ship-to join, and pick-date `CASE` can yield NULL) will appear first, not last. Disclosed; revisit only if blanks actually appear.
- **CSR Name slicer** is Dropdown, **multi-select** (a viewer picks their own CSR; not forced single). Switch to single-select or to `CSR AB Number` if RLS (option B) is chosen instead.
- **Leaf grain via matrix Rows:** the 7 "leaf" columns (Order Number, Next Status, Order Type, Order Line, Carrier Name, CSR Name, Primary UOM) are additional Rows levels (all `isPinned`, expanded) under the 3 group levels, with their `levelSubtotalEnabled=false`, so they render as detail columns without their own subtotal rows — the only way to place non-aggregated attributes in a matrix.

### Left for the human (jumpbox)
1. ~~Run probes~~ **DONE 2026-07-16** — see §10.
2. ~~First refresh of the main PBIP~~ **DONE 2026-07-16** (Last Refreshed 9:17 AM EDT); still need the Cognos tight-capture xlsx to validate against the source and **lock the Scheduled Pick Date format**.
3. ~~2.0.0 → 1.0.0 knock-down~~ **OBSOLETE** — local Desktop upgraded to 2.155 (2026-07-16), both sides accept 2.0.0.
4. Decide the open items in §8 (burst replacement, >20k semantics, CSR source, carrier-exclusion table, SSAS bake-off).

---

## 10. Probe results (2026-07-16, refreshed on jumpbox, read via MCP DAX)

Both PBIPs refreshed same morning (main model Last Refreshed 9:17 AM EDT). **All 6 categories PASS:**

| # | Probe | Result | Verdict |
|---|---|---|---|
| 1 | Column existence (F4211/F42140/F0101) | all 3 SELECTs returned | PASS |
| 2 | Join drops | qualifying 5, dropped_no_shipto **0**; no-carrier-name **0**, no-CSR **0** | PASS — INNER ship-to join drops nothing; no blank carriers/CSRs |
| 3 | CSR fan-out (global F42140 scan) | 4 ship-tos with 2 `CSR` rows each (345466, 300385, 349421, 329077), **all 1 distinct rep** | PASS today — none intersect the qualifying set (block 6 rows = 5a count). Residual: if one ever qualifies, GROUP BY collapses the row (same rep ⇒ same keys) but **Sum(Primary Quantity Ordered) doubles** — Cognos does the identical thing, so parity holds; disclose, don't fix. |
| 4 | Code decodes | live set = Next Status 530(1)/540(3)/550(1), Order Type S4 only | PASS — IN-lists cover live data with headroom |
| 5 | Count parity | deployed **5** = HAVING-SUM **5**, diff **0**; multi-row (order,line) probe **empty** | PASS — per-row vs HAVING (§6.3/§8.2) is **currently moot**: no (order,line) has >1 F4211 row, so both semantics are provably identical today |
| 6 | Format spot-checks | Julian decode sane (pick dates 7/20–8/11/2026), qty scaling sane (21,600–44,000 LB), line 1.001 = real SDLNID 1001, UOM LB | PASS |

**Report-vs-probe tie-out:** `LTL Over 20k` table = **5 rows, value-identical to probe block 6** (every column, every row, including CSR AB Numbers 350026/349861). The build reproduces the deployed query exactly on live data.

---

## 11. Cognos tight-capture validation (2026-07-16, 09:41 — 24 min after the 09:17 PBI refresh)

Artifacts in `Intake\`: `Cognos export - LTL over 20000 lbs (2026-07-16 0941).xlsx` + `Cognos screenshot (2026-07-16 0941).png`.

**Detail rows: 5/5 EXACT MATCH** on every column, with one live-drift cell: order **2744344** Next Status = Cognos **535** vs PBI **530** — the status advanced in the 24-minute gap (both values in the IN-list; the row qualifies either way). Everything else ties byte-for-byte: dates, carriers, customers, order numbers, lines (incl. 1.001), CSRs, quantities (21,600 / 44,000 / 44,000 / 40,500 / 44,000), UOM.

**FINDING — Cognos "- Total" rows are AVERAGES, not sums.** `Jul 20 - Total` = **32,800** = AVG(21,600, 44,000) (sum would be 65,600); `Overall - Total` = **38,820** = AVG of all 5 (sum would be **194,100**). Root cause: §6.5's `Average()` re-wrap in Query1 — an identity no-op on *detail* rows, but the list **footers** aggregate with the data item's aggregate function = Average. (Customer/carrier totals are single-row groups today, so avg = sum there — indistinguishable.) Our matrix subtotals are **Sum** → PBI shows 65,600 / 194,100 where Cognos shows 32,800 / 38,820. **Open decision (§8.7):** flip the matrix value to Average for exact parity (labels would still read "Total" over an average — the Cognos defect, ported), or keep Sum (correct arithmetic, fails a cell-by-cell compare on 2 of 12 total rows today). Either way, disclose to the business that the legacy report's "Total" rows have always been averages.

**Date format LOCKED:** Cognos renders `Jul 20, 2026 12:00:00 AM` — month-first datetime **with a meaningless midnight timestamp**. PBI currently `MMM d, yyyy` (matches, minus the time). Exact parity = `MMM d, yyyy h:mm:ss AM/PM`; recommend keeping the clean date unless the team wants literal parity. **Open decision (§8.8).**

**Verdict:** build is validated at the detail grain (5/5, one live-drift status cell). Remaining deltas are presentation-layer decisions (subtotal aggregation, date-time suffix), not data defects.
