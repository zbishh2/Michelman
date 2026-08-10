# EDW model — handoff

Code-of-record for the **Executive Dashboard** semantic model (and the shared pieces the
OTIF PBIP uses). The model is an **import** model sourced directly from EDW and ODS, plus
the Cloudflare/D1 writeback endpoints.

> **Clean Order % = (Orders − Complaints) / Orders**, per month, by region. Higher is
> better. Numerator = Salesforce complaint cases; denominator = JDE orders. Business logic
> origin: `../Dashboard Requirements/COMPLAINTS_REQUIREMENTS.md` +
> `../Dashboard Requirements/ORDER_COUNT_RECONCILIATION.md`. This doc maps that logic onto
> the physical EDW columns.

---

## Way of working

The model is defined **as code in this folder** and applied to the PBIP through the
**`powerbi-modeling` MCP**.

- **Table queries → `*.m`** — one Power Query per table. These are commented masters; the
  shipped copies live in the PBIP partitions and carry no comments.
- **Measures / calc columns / calc tables / relationships → `ExecutiveDashboard_Model.dax`**
  — the commented master. Apply via the MCP (`measure_operations`, `column_operations`,
  `table_operations`, `relationship_operations`). Re-sync with
  `database_operations ExportToTmdlFolder` and fold deltas back in.
- **Generators own their output.** `gen_quality_database_table.py` writes the Quality
  Database WOs table; `apply_tieout.py` reapplies the whole tie-out feature idempotently.
  Edit the generator, never the TMDL.

⚠ **Desktop is opened on the jumpbox only** (CLAUDE.md §1). Edit these files with Desktop
closed; a jumpbox save serialises the entire SemanticModel from Desktop's own state over
the top, including table files it never touched. That is what `apply_tieout.py` exists to
recover from — run it after any jumpbox save that lands before the tie-out objects have
been refreshed in, and close Desktop first.

**Connection pattern:** native SQL (`Sql.Database("EDWPROD","EDW",[Query="…"])`),
gateway-bound. `Complaints.m` is the one remaining navigation-pattern query and is
equivalent.

⚠ **Server strings are SHORT NAMES**, matching what is registered on the shared on-prem
gateway — `EDWPROD`, `EDWDEV`, `ODSPROD`, `ODSDEV`. They resolve on the jumpbox via DNS
suffix. Credential = **Windows auth, UPN `ZackB@michem.com`** — *not* the `michelman.com`
mail address and *not* `Zack.bishop`. The AD account is `ZackB` and the AD domain is
`michem.com`; a wrong identity makes the gateway throw *"service account failed to
impersonate the user"*, which looks like a rights problem and is not.

### Working constraints

- **This machine cannot reach EDW/ODS/SSAS** — firewalled, jumpbox only. Data questions go
  to the mounted PBIP cache (DAX) or the local SQL mirror (T-SQL) first; see CLAUDE.md §9.
- Read-only everywhere. No model writes to `ssasprod`, no EDW DDL.

---

## Sources

| Table | Query | Source |
|---|---|---|
| Orders (live name `FactSalesDetail`) | `Orders.m` | `EDWPROD` / `EDW` / `dbo.FactSalesDetail` |
| Complaints | `Complaints.m` | **`EDWDEV`** / `EDW` / `BIQL.TbSF_Case` (+ `ODSDEV` dims for names) |
| FactScheduleChange | `FactScheduleChange.m` | `ODSPROD` / `ODS` / `PRODDTA.F42199` |
| Reason Codes | `ReasonCodes.m` | D1 `reason_dim` via the michelman-writeback Worker |
| RevisionOverrides | `RevisionOverrides.m` | D1 `revision_overrides` (connection-only helper) |
| LineComments | `LineComments.m` | D1 `line_comments` via the Worker |
| Ship-To / Sold-To | `ShipTo.m`, `SoldTo.m` | `EDWPROD` / `EDW` / `dbo.DimAddress` + `BIQL.DimAddress` |
| WorkOrders | `WorkOrders.m` | `EDWPROD` / `EDW` / `BIQL.DimWorkOrder` |
| WorkOrderRouting | `WorkOrderRouting.m` | `BIQL.TbWorkOrderRouting_Routing` |
| WO Parts List | `WOPartsList.m` | `BIQL.FactWOPartsList` |
| Item Ledger | `ItemLedger.m` | `BIQL.FactInventoryDetail` (doc type `IC`) |
| Quality Database WOs | `QualityDatabaseWorkOrders.m` | frozen Excel extract, tie-out evidence only |

⚠ **`Complaints` reads EDWDEV because that is the live Salesforce chain.** EDWPROD's SF
copy is frozen at 2024-08-19 — `ODSPROD.ODS_SalesForce.dbo.Case`, `EDWPROD.BIQL.TbSF_Case`
and `ssasprod SF_Case` all max out at the same timestamp to the millisecond, because
EDW/SSAS just mirror ODS. Prod is useful only for deep history (2009+). The JDE/orders feed
on EDWPROD is unaffected and current. If Dave's prod SF→ODS fix ever lands, whether to move
back to prod (full history *and* current in one source) is a live decision.

`WorkOrderRoutingTime.m` is **not currently in the model** — it was imported to make "run
machine actual hours > 0" answerable and removed with the work-centre batch definition. The
query is kept in case the question returns.

---

## Denominator — Orders (`dbo.FactSalesDetail`, line grain)

"Orders" = `DISTINCTCOUNT(OrderNum)`.

| Rule | Column | Filter |
|---|---|---|
| Exclude non-orders | `OrderType` (nchar 2) | order-type list, see open decisions |
| Drop ledger rows | `RecordType` | `<> 'GL Detail'` (= LineType `AA`), dropped at source |
| Exclude freight lines | `LineType` | `<> 'FS'` |
| Exclude cancelled | `Cancelled_Flag` | barely populated — see below |
| Month bucket | `GLDate` | → DateTable |
| Region | `OrderCompany` (e.g. `00010`) | → Region dim |

- ⚠ **The order-type universe is ~29 types in full history**, wider than the locked exclude
  list `{CM,CO,S5,SA,SL,SR,ST,SK,SQ}`, which silently counts non-customer types: `JE`
  (journal), `I4` (inventory), `BF`, `RC/RI/RS/RO/RM/RR` (returns/re-invoice), `AE/PV/PD`.
  An INCLUDE list of customer types — `S4`, `SO`, `SI`, `SE`, `SZ`, `SC`, `SB`, `SD` — is
  the recommendation. **Greg to confirm.**
- ⚠ **`Cancelled_Flag` is barely populated** (267 lines). Cancellation lives in `OrderType`
  (`CM`/`CO`) and status 980. Don't rely on the flag alone.
- ⚠ **42,664 orders carry `GLDate = 1900`** (open / unposted), so bucketing on `GLDate`
  drops them and recent months lag until orders post. Greg chose `GLDate`; `OrderDate` is
  the alternative if open orders should count.
- **Singapore double-count** is unresolved — one customer order across companies 30/34/35
  can count twice, and needs a dedup rule.

### Master Planning Family

`[Master Planning Family]` + `[… Desc]` ride on the fact, folded from **`BIQL.TbItemBranch`**
= JDE **`F4102.IBPRP4`** (item **branch**, not item master), decoded by UDC **`41/P4`**. The
enrichment columns exist only on the `BIQL` view; `dbo.DimItemBranch` does not carry them.

Grain is (`ItemSKey`, `Business Unit`), both already in the SELECT, so it folds in as a
`LEFT JOIN` with no new source and no new relationship. ⚠ **Fact-side, not a dimension** — a
1:1 dimension hop in a wide-grid group-by is what caused the OOM in CLAUDE.md §7, and
pushing the attribute onto the fact was the fix. Zero DAX changes, no bidirectional filter
risk.

The join target is a `GROUP BY` derived table, so it emits at most one row per pair and
**cannot change the fact row count**; it is hash-aggregated once, not the correlated
`OUTER APPLY`/`ROW_NUMBER` lookup that hung report 14 twice. `MIN()` is the tie-break, and
in practice never arbitrary: of 115,989 (ItemSKey, BU) pairs, 2 are duplicated and 1
disagrees on MPF — and that one is `ItemSKey = -1` (the unknown-member sentinel) on BU
`LABR`, used by **0** fact rows.

MPF is NULL on ~16% of rows. Not a join defect: only 13 ItemSKeys are absent from
`TbItemBranch` outright, the rest are items not set up in that branch (CIN2, MUM3, SNG4,
AUBA). The inverted `<> 'PKG'` filter retains them.

**PKG exclusion** is a **report-level** filter in `OTIF.Report`, `Not(In('PKG'))` with
`isInvertedSelectionMode: true`; on the Executive Dashboard it is a **page**-level filter on
the OTIF page only. ⚠ The scopes differ deliberately: at report level MPF `<> 'PKG'` removes
77 orders from `[Orders]`, which would rescope Complaints / RTFT / Safety / Scorecard —
pages with no OTIF counterpart.

### Split lines — 1.001 / 1.002

`LineNum` is `decimal(9,3)`; JDE splits a sales order line into `1.000` / `1.001` / `1.002`.
These inflate the OTIF line count and late-line count when the children are commercially
one line (~18% of rows are split children).

⚠ **The fact grain is deliberately unchanged.** `[Order Line ID]` is the join key for
`FactScheduleChange`, the key `LineComments` rides on, and is embedded inside `RevisionKey`,
which every writeback row in D1 is keyed by. Re-graining the fact would orphan every
existing revision override and line comment.

Instead the report **filters down to the parent row**, so every field already carries the
parent's own value and the writeback key stays the parent's `[Order Line ID]`.

Descriptive columns in the native query: `[Parent Line Num]`, `[Parent Order Line ID]`,
`[Is Split Child]`. `[Parent Order Line ID]` is derived by **string surgery on the real
`OrderLineID`** rather than reconstructed from its parts, so the prefix matches
byte-for-byte whatever format EDW emits — and on a non-split line it comes out identical to
`[Order Line ID]`, which is the built-in self-check.

Calc columns on `FactSalesDetail`:

| Column | Definition |
|---|---|
| `[Is Parent Row]` | 1 when `[Line Num]` = `MIN([Line Num])` within `ALLEXCEPT(…, [Parent Order Line ID])` |
| `[Qty Ordered (Family)]` | `SUM` over the family, `[Line Type] <> "FS"` |
| `[Qty Shipped (Family)]` | same |
| `[Qty Open (Family)]` | same |
| `[Qty Backordered (Family)]` | same |

- ⚠ **Filter on `[Is Parent Row] = 1`, never on `[Is Split Child] = 0`.** The latter drops
  the ~119 families that have no `.000` row entirely. "Lowest line in the family" folds that
  fallback into the rule instead of needing a branch.
- ⚠ **The `(Family)` columns carry the family total on *every* row of the family.** Without
  the parent-row filter they repeat it once per child and inflate. They are a footgun on any
  surface that lacks that filter — which is why they were not ported to the Executive
  Dashboard, whose OTIF page has no line-detail grid.
- ⚠ **All four qty columns roll up together, deliberately.** A family-total ordered qty
  beside a parent-row-only shipped qty reads as a data error to anyone checking a line.
- ⚠ **Freight is the confound inside a family, not kits.** A family carries its product
  splits at `.001–.00n` plus a `LineType 'FS'` BILLABLE FREIGHT line at `.010`. With `FS`
  excluded, **zero** multi-row families disagree on Item, UoM or Master Planning Family, so
  summing `[Qty Ordered]` across a family is valid — but freight must be excluded, or it
  adds `1 EA` of freight to `15 TO` of product.
- The parent-row filter does **not** remove all freight: it removes the `.010` lines riding
  inside a product family, while standalone freight lines carry an integer line number and
  so are the lowest line of their own one-row family. They survive as parent rows showing
  `[Qty Ordered (Family)] = 0`. No third filter is needed — every OTIF page carries a
  page-level `[Line Type] = 'S'` filter, so freight never reaches a visual.
- `[Order Lines]` is `COUNT('FactSalesDetail'[OrderKey])` — a plain **row count**, not a
  distinct count. `[Order Lines (Parent)]` is `DISTINCTCOUNT([Parent Order Line ID])`.

⚠ **The revision log needs no equivalent fix.** `FactScheduleChange[OrderLineID]` is
many→one to `FactSalesDetail[Order Line ID]`, active and single-direction, so the parent-row
filter propagates. The child-line revisions that survive belong to the families whose parent
IS a fractional line — the no-`.000` case the fallback exists for.

⚠ **The genuine issue this exposes is WINDOWING, not splits.** `FactSalesDetail` windows on
`GLDate` while `FactScheduleChange` windows on `SLUPMJ >= 124001`, so ~13,853 revision rows
have no matching fact row at all and can never contribute to OTIF. They are invisible in the
report (any fact-side filter removes them), so nothing is double-counted — but for those
families the revision history is split between a visible parent and an invisible orphan, so
Days Moved and reason attribution may be incomplete. Worth a separate decision.

---

## Numerator — Complaints (`BIQL.TbSF_Case`, distinct CaseNumber)

| Rule | Column | Filter |
|---|---|---|
| Complaint definition | `Level_1__c` | `UPPER(TRIM())` IN (`PRODUCT QUALITY`, `PRODUCT DELIVERY`) |
| Month bucket | `Date_of_Occurance__c` | → DateTable |
| Region | `Region__c` first, `Location__c` fallback | → Region dim |
| Valid gate | `Complaint_Valid__c` | `= 1`? — **open, Jessica** |

- ⚠ **The valid gate is the biggest single lever.** PQ+PD complaints = **7,678** total vs
  **2,560** with `Complaint_Valid = 1`, a 3× difference. Both measures exist; Jessica picks.
- ~49% of cases have NULL `Level_1__c` (non-complaint records), excluded by the filter anyway.
- Champion and Product arrive as raw Salesforce IDs (`Champion__c` = User ID,
  `Product_Code__c` = Product2 ID) — there is no SF user/product dim in the warehouse
  (`DimUser` is JDE-only), so `Complaints.m` resolves them against ODSDEV.

---

## Customer OTIF — revision-based

**On-time is not a date comparison.** A shipped order line is an **OTIF miss** if it has
**≥1 promised-delivery-date revision whose reason code is OTIF-relevant**. Revisions come
from `FactScheduleChange` (`F42199`); which reason codes count is decided by the editable D1
reason dimension (`ReasonCodes.m`), `[OTIF] = "X"`. This matches how the business scores
OTIF — by *why* the date moved, not by a raw ship-vs-promise delta.

**Data flow:**

1. `FactScheduleChange[Is OTIF Relevant]` = `UPPER(TRIM(RELATED('Reason Codes'[OTIF]))) = "X"`
   and not user-excluded — the single source of truth. Flipping a code's flag in the Reason
   Code Editor visual reflows the metric on the next refresh, with no DAX change.
2. `Orders[Relevant Revision Count]` / `[Relevant Net Days Moved]` roll the relevant
   revisions up to the line via `Orders[Order Line ID]` → `FactScheduleChange[OrderLineID]`.
3. Measures: **in scope** = shipped; **miss** = `Relevant Revision Count > 0`; **on time** =
   scope − miss; **in full** = `Qty Shipped + Qty Cancelled >= Qty Ordered`; **OTIF** = on
   time ∧ in full. Days-late buckets use `Relevant Net Days Moved`.

- ⚠ **Scope guard is `>= DATE(2000,1,1)`, NOT `NOT ISBLANK`.** JDE stores an empty date as a
  1900-01-01 sentinel, so `NOT ISBLANK` false-counts unshipped lines as in scope.
- ⚠ **Measures are MECHANICAL** — no Order Type / Line Type / company scope is baked in.
  Apply that report-side, via slicer or filter pane.
- ⚠ **The revision trigger is reason-driven, not date-only.** A row-to-row `SLPDDJ` change
  alone under-counts misses: any line whose OTIF reason was logged without a visible date
  delta gets dropped. See `FactScheduleChange.m`.
- **Open (basis):** misses key off promised **delivery** (`SLPDDJ`), while some reason codes
  are logged against promised **ship** (`SLPPDJ`). A delivery-vs-ship reconciliation is a
  separate decision for Ivan.
- **Open:** `Responsible Dept` / `Responsible Detail` on `FactScheduleChange` are still
  hardcoded `SWITCH`es. `Responsible Dept` duplicates the dimension's
  `[Classif ReviewDec 2024]` column and is a candidate to repoint at `RELATED(...)`.

---

## RTFT — Right First Time

The client's SSAS model (`SSASPROD` / **`BIQLTabular_v2`**) names this "Right Time First
Batch". Their formula card, verbatim:

```
Complaint % Per Order   = format(1 - Divide(([Case Count]),([Order Count])),"0.00%")
Right Time First Batch  = 1 - Divide([Case Count],[WO Count])
```

| SSAS object | Definition | EDW object | JDE / SF origin |
|---|---|---|---|
| `[Case Count]` | `DISTINCTCOUNT(SF_Case[CaseNumber])`, no RecordType filter | `EDW.dbo.SF_DimCase` | Salesforce `Case` |
| `[WO Count]` | `DISTINCTCOUNT('Work Order Detail'[WorkOrderSKey])`, *"Based on Order Date"* | `EDW.dbo.DimWorkOrder` | JDE **F4801.WADOCO** |
| `[Order Count]` | `DISTINCTCOUNT(Sales[Order Num])` | — | JDE F4211 / F42119 |

**Our `[RTFT %]` departs from that port in two places, deliberately:** the denominator is
`[Batches]` (the S&OP batch definition the business agreed) rather than the bare `[WO Count]`,
and the numerator isolates the Batch Mfg Issue record type. `[WO Count]` survives as page
context only — ⚠ **do not reconnect it to `[RTFT %]`**.

Full definition, the load-bearing constraints (the `(b−c)/b` form, the 50-batch floor) and
the S&OP batch rules are in `ExecutiveDashboard_Model.dax`. The batch definition itself is
the client's own, transcribed from the Cognos *Work Order Completion Report - S&OP Process*.

**Region hop.** The work-order fact is all surrogate keys with no branch or company text, so
`WorkOrders.m` walks `BranchSKey → BIQL.TbBranch` (F0006) `→ CompanySKey → BIQL.TbCompany`
(F0010) and projects `[Order Company]` — deliberately the same column name and 10/20/30/34/35
domain `FactSalesDetail` carries, so `WorkOrders[Region]` is a byte-for-byte copy of
`FactSalesDetail[Region]`. ⚠ **If the company domain ever widens, change both.**

**Not ported.** The SSAS measure wraps its `DISTINCTCOUNT` in a `CalendarPatternSKey` filter
(their multi-fiscal-calendar machinery). Our `DateTable` is single Gregorian, so there is
nothing to filter and the counts are equivalent.

### ⚠ Open on RTFT

1. **No case-to-work-order join.** Numerator and denominator are two independent counts
   aligned only by `DateTable` and Region. `Complaints` carries `LotSKey` / `Lot_Number__c`
   and `WorkOrders` carries `LotSKey` — **that Lot hop is the only true batch-level link**,
   and neither we nor SSAS wire it (their `SF_Case` has exactly two relationships:
   `Date_of_Occurance__c → Date` and `AddressSKey → Address`). Wiring it converts this from a
   rate-of-two-counts into a real per-batch defect rate. Worth raising with Jessica/Dave.
2. **Near Miss.** A Near Miss subset sits inside the numerator and is ~25–30% of Batch Mfg
   Issue cases, so excluding it would move RTFT materially. Not settled — reopen with
   Jessica/Dave.
3. **Perspective membership.** In the May `ssasprod.bim` dump (model `BIQLTabular`, stale)
   `SF_Case` sits only in the **Quality SF** perspective, which does not contain
   `Work Order Detail`. For their measure to resolve, `BIQLTabular_v2` must have added it.
   Unverified — SSASPROD is unreachable from this machine.

---

## Open decisions (stakeholders — not blocking the build)

- **Greg:** order-type include-list vs exclude-list; region for new companies
  `00024/00025/00037/00038/00080`; date axis (`GLDate` vs `OrderDate`, given ~800 open
  orders / ~1.2k open lines); Singapore double-count dedup.
- **Jessica:** valid-only complaint gate (2,560 vs 7,678); metric framing (`(O−C)/O` vs
  `C/O`); no-occurrence-date handling; duplicates; the ⚠-marked column picks in
  `Complaints.m`; the Near Miss exclusion.
- **Ivan:** promised delivery vs promised ship basis for OTIF misses.
- **Dave/Rohit:** fix the SF→ODS prod feed. Complaints works around it via EDWDEV; a prod
  fix would restore full history *and* current data in one source.

---

## File index

| File | What it is |
|---|---|
| `Orders.m` | EDW sales-order line fact; the orders denominator |
| `Complaints.m` | Salesforce case fact (EDWDEV); the complaints/RTFT numerator |
| `FactScheduleChange.m` | promised-date revision ledger (F42199) + writeback fold |
| `ReasonCodes.m` | the editable D1 revision-reason dimension; OTIF source of truth |
| `RevisionOverrides.m` | connection-only writeback helper for the revision ledger |
| `LineComments.m` | order-line comment writeback |
| `ShipTo.m`, `SoldTo.m` | address dims (true geography + customer segmentation) |
| `WorkOrders.m` | JDE F4801 work order header; the batch denominator |
| `WorkOrderRouting.m` | routing standards at operation grain; carries the work centre |
| `WorkOrderRoutingTime.m` | routing actuals at time grain — **not in the model**, kept for the hours question |
| `WOPartsList.m` | F3111 components; feeds the rename test |
| `ItemLedger.m` | F4111 inventory completions; the S&OP date basis |
| `QualityDatabaseWorkOrders.m` | frozen extract of the client's own workbook; tie-out evidence |
| `ExecutiveDashboard_Model.dax` | commented master for measures, calc columns/tables, relationships |
| `gen_quality_database_table.py` | generator for the Quality Database WOs table |
| `apply_tieout.py` | reapplies the tie-out feature idempotently after a jumpbox save |
| `check_bindings.py` | measure/column binding audit |
| `work_centres_all.csv` | all 148 JDE work centres with usage counts |

Related: `../edw_schema/` (schema dumps, probe SQL, the snapshot generator),
`../dax queries/otif_reconciliation.sql`, `../writeback/ARCHITECTURE.md`.
