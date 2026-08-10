# Report 18 — 1 - Singapore Warehouse Inv 2025 — BUILD SPEC

**Cognos path:** Public Folders > Michelman Reporting > (likely) Production and Shipping — the `1 - ` Ivan/Cogan AD-HOC family (same lineage as reports 13/14). Tracker ID: **TBD** (capture from the migration workbook).
**Report name (XML `reportName`):** `1 - Singapore Warehouse Inv 2025`
**Assigned:** Zack, 2026-07-17.
**Stage:** ⬜ INTAKE COMPLETE — spec ready for build. Intake artifacts all present and untruncated (§0). Rendered export captured 2026-07-17 → validation target locked (§10).

A four-page dated **snapshot-history** report. Each page is one flat list of on-hand inventory positions (date × branch × item × location × lot), stamped with a KGs conversion and a USD extended cost, over a **rolling, refresh-time window** of twice/thrice-weekly snapshots. Despite the "Singapore 2025" title it covers **all regions** (the "2025" is legacy naming — the windows are `sysdate`-relative, not a fixed year). No prompts, no parameters.

Author the PBIP in **PBIR** format (like reports 02/03/14/17). Production `.m` files are comment-free; a `<name>.commented.m` master sits alongside each (repo rule: prod deliverables carry no comments).

**Do NOT build the PBIP from this file** — a separate build agent consumes this spec. Everything below is explicit enough that the build agent needs zero further research, except the jumpbox probe results that §9 gates the two derived columns on.

---

## 0. Intake integrity + the one insight that shapes the build (READ FIRST)

| Artifact | Status | Notes |
|---|---|---|
| Report XML | **COMPLETE, untruncated** | `Intake\XML.txt`, 194 lines, report/12.0 schema, closes on `</report>` (line 194). 4 query objects ↔ 4 report pages, 1:1. Every page is ONE flat `<list>` (no `<listGroup>`, no crosstab, no grand total). |
| Generated SQL | **COMPLETE** | `Intake\Queries.txt`, all 4 Oracle statements (one per page). Windows land as `sysdate - 365/3` / `sysdate - 365/2` literals → **no `:PQ` binds, no prompt** (contrast report 14). |
| Rendered export (xlsx) | **PRESENT — validation target** | `Intake\Cognos export … (filed 2026-07-17).xlsx`, 4 sheets, profiled 2026-07-17 (§10). Row counts + column sums + every format captured. |
| Screenshots | **Not collected — not needed** | The 4-sheet xlsx is complete render evidence (report-15 precedent). |

**Completeness verdict:** query logic, layout, formats, and a validation target are all in hand. The only open inputs are the jumpbox probe results (§9) that gate the KGs factor tail and the USD/FX join — the same two derived columns report 14 left open.

### 0.1 The insight: report 14's 71× duplicate fan-out is *evidence the EDW view carries a native per-snapshot-date grain* — and that grain is exactly what report 18 needs

Report 14 queried `BIQL.FactInventorySnapshot_History_Filtered` for **one** as-of date via `@AsOf BETWEEN snap.StartDate AND snap.StopDate`, and its first refresh returned **~71 byte-identical copies per position** (292,448 rows vs 4,119 distinct), which it papered over with `SELECT DISTINCT`. Read that number the other way: **a single position valid on one date produced ~71 identical rows because the view already stores one physical row per position per snapshot date, and report 14's `BETWEEN Start/Stop` predicate (position validity, not snapshot date) matched *all ~71 snapshot rows* for that position.** Report 14 then collapsed them and stamped the *parameter* as `[Inventory Date]`, discarding the view's own snapshot-date column.

**Report 18 needs the column report 14 threw away.** This report is a *history* — one row per position **per snapshot date** — which is precisely the view's native grain. So the correct model is **not** report 14's SCD2 as-of reconstruction. It is: select the view's snapshot-date column as `[Inventory Date]`, filter that column to the rolling window + the required weekdays, and let the natural grain stand. This both (a) reproduces the multi-date history and (b) makes the 71× fan-out *disappear* (no `BETWEEN Start/Stop`, no cross-product), so no heroic `SELECT DISTINCT` is masking anything.

**The build's first job (probe P1) is to identify that snapshot-date column's exact name.** Report 14 never referenced it (it used the parameter), so the name is unverified. Candidates to check with `SELECT TOP 5 *`: `SnapshotDate`, `InventoryDate`, `AsOfDate`, `SnapshotDateSKey`(+`DimDate`), `DateSKey`, `FiscalDate`. §2 gives the primary design assuming this column exists (very likely, per the 71× evidence) and a fallback (§2.3) if it genuinely does not.

---

## 1. Source route — **EDW SQL Server** (SSAS + ODS rejected; decided, do not relitigate)

Route is fixed per the team-lead brief and report 14's precedent. Summary of why (evaluated SSAS → EDW → ODS per the standing mandate):

- **Cognos source pkg = Data Warehouse / `DW_LEGACY`** (Oracle `Inventory On Hand Star Schema`; `RS_modelModificationTime = 2018-07-31`). We have **no Oracle gateway** (same no-connection situation as reports 08/10/12/14).
- **SSAS `BIQLTabular_v2` (Live) — REJECTED:** no perspective exposes a *dated* inventory snapshot; the Item Location File (F41021) is in no `v2.xmla` perspective (report 14 finding). A Live Connection also forbids the local KGs/FX/region derivations.
- **ODS `PRODDTA` `F41021` — REJECTED:** current-only, no history dimension → structurally cannot reproduce a 4-to-6-month snapshot history.
- **EDW SQL Server — CHOSEN:** `BIQL.FactInventorySnapshot_History_Filtered` is the only SQL-Server source with dated inventory history and is the direct analog of the Oracle `INVENTORY_ON_HAND` snapshot report 14 already validated (rows tied 1:1 at its as-of date). Enrichment views: `BIQL.DimItem` (item attrs), `BIQL.DimItemUOMConversionLBKG` (KG factors), `BIQL.DimCurrencyExchangeRates` (USD FX), `BIQL.DimCompany` (currency basis).

Connection style (copy report 14's): `Sql.Database("EDWPROD", "EDW")`, two-part `BIQL.<obj>` names, native T-SQL via `Value.NativeQuery(..., null, [EnableFolding=false])` for the `#temp`-batch tables (§6). **EDWPROD is the real server** (report 14 / reports 11-14 batch confirmed).

**Fallback of last resort** (human decision, not a silent switch): if EDW cannot tie on the FX rows (§5.2 / §9 probe P4), the escalation is "provision a `DW_LEGACY` Oracle gateway," exactly as report 14 §2.4 framed it.

---

## 2. Snapshot-date modeling — the core design

### 2.1 Primary design (probe-P1 confirmed native snapshot date) — RECOMMENDED

For each page, one native T-SQL `SELECT` against the snapshot fact, filtered on the view's **snapshot-date column** (call it `snap.SnapDate` below — replace with the real name from probe P1):

```
GROUP BY <the 12 display keys incl. snap.SnapDate>,  SUM the 3 measures
WHERE  snap.SnapDate >= <rolling lower bound>          -- §2.4
  AND  (DATEDIFF(DAY,'1900-01-07',snap.SnapDate) % 7) IN (<weekday set>)   -- §2.5
  AND  snap.SnapDate <> '2025-05-07'                    -- blacklist, kept verbatim (§11)
  AND  snap.QuantityOnHandPrimaryUOM > 0
  AND  LTRIM(RTRIM(snap.BusinessUnit)) IN (<branch set>)
  AND  it.MasterPlanningFamily NOT IN ('H2O','PKG')
  -- Lot Status page only: AND snap.LotStatusCode NOT IN ('-')
```

`[Inventory Date]` = `snap.SnapDate` (the real snapshot date, **not** a constant — the crucial difference from report 14). No `BETWEEN snap.StartDate AND snap.StopDate` predicate — that was report 14's single-date trick and is the *cause* of the 71× fan-out (§0.1). Filtering the snapshot-date column directly yields the natural one-row-per-position-per-date grain.

### 2.2 Aggregation — reproduce Cognos's GROUP BY + SUM (not DISTINCT)

The Cognos SQL is `GROUP BY date|branch|globalbulk|bulk|2nd|stocktype|location|lot|status|mpf|uom|weekday|region` with `SUM(QOH)`, `SUM(QOH·CONVERSION_FACTOR_KG)`, `SUM(QOH·UNIT_COST·FX)`. Mirror it exactly: **inner derived table** computes the row-level measures (KGs, USD — §5); **outer query** `GROUP BY` the display keys and `SUM` the three measures. This is faithful whether or not the EDW grain is finer than the Cognos grain (it collapses any sub-position rows the way Cognos does), and it removes the need for `SELECT DISTINCT`. If probe P3 proves the grain is already 1:1 (no fan-out), the GROUP BY is a harmless no-op and may stay for parity.

### 2.3 Fallback design (only if probe P1 finds NO native snapshot-date column)

If the view exposes *only* SCD2 `StartDate/StopDate` validity (no discrete snapshot-date column), reconstruct the history with a **date spine**:

```
-- spine of the required weekday-dates in the window
;WITH d AS ( SELECT CAST(GETDATE() - (365.0/3.0) AS date) dt
             UNION ALL SELECT DATEADD(DAY,1,dt) FROM d WHERE dt < CAST(GETDATE() AS date) )
SELECT dt INTO #spine FROM d
WHERE (DATEDIFF(DAY,'1900-01-07',dt) % 7) IN (0,3) AND dt <> '2025-05-07'
OPTION (MAXRECURSION 1000);
CREATE UNIQUE CLUSTERED INDEX ix_sp ON #spine(dt);
-- then range-join, stamping [Inventory Date] = sp.dt
... FROM #spine sp JOIN <fact slice> snap ON sp.dt BETWEEN snap.StartDate AND ISNULL(snap.StopDate,'9999-12-31') ...
```
**Perf caveat (report 14 lesson):** a range join against the raw view can degrade like report 14's correlated lookup. Materialize the branch/family/qty-filtered fact slice into a `#temp` with an index on `(StartDate, StopDate)` first, then join the (tiny) `#spine`. This fallback is *semantically exact* — SCD2 preserves every state, so each spine date reconstructs the true position — but it is heavier and its row counts depend on EDW's underlying snapshot cadence (§9 P5). **Prefer §2.1.** Only fall to §2.3 if P1 fails.

### 2.4 Rolling window lower bounds (refresh-time, `sysdate`-relative)

| Pages | Oracle | T-SQL lower bound | Observed earliest (2026-07-17 run) |
|---|---|---|---|
| Singapore / Americas / Aubange | `INVENTORY_DATE >= to_date(sysdate - 365/3)` (=121.667 d) | `snap.SnapDate >= CAST(GETDATE() - (365.0/3.0) AS date)` | 2026-03-18 |
| Lot Status | `INVENTORY_DATE >= to_date(sysdate - 365/2)` (=182.5 d) | `snap.SnapDate >= CAST(GETDATE() - (365.0/2.0) AS date)` | 2026-01-16 |

`CAST(GETDATE() - <float> AS date)` does datetime day-arithmetic then truncates — faithful to Oracle's fractional-day subtract. The exact fraction is immaterial in practice because the weekday filter (§2.5) selects the actual snapshot dates; the lower bound only sets how far back the window reaches. **No upper bound** (Cognos has none — defect-C1 expired-ceiling is CLEARED; the window runs to today, and the weekday filter caps it at the latest Wed/Sun/Tue/Fri).

### 2.5 Weekday filter + the displayed `Weekday` column (one expression, DATEFIRST-independent)

Anchor `'1900-01-07'` is a **Sunday**, so `n = DATEDIFF(DAY,'1900-01-07', d) % 7` gives Sun=0, Mon=1, Tue=2, Wed=3, Thu=4, Fri=5, Sat=6 regardless of `SET DATEFIRST`/language.

| Pages | Cognos `GREGORIAN_WEEKDAY IN` | Filter | Displayed `Weekday` values seen |
|---|---|---|---|
| Singapore / Americas / Aubange | `('SUNDAY','WEDNESDAY')` | `n IN (0,3)` | WEDNESDAY, SUNDAY |
| Lot Status | `('SUNDAY','TUESDAY','FRIDAY')` | `n IN (0,2,5)` | TUESDAY, SUNDAY, FRIDAY |

The **displayed** `Weekday` column must render uppercase names (`WEDNESDAY`, `SUNDAY`, …) exactly as the export shows. Do NOT use `DATENAME(WEEKDAY, …)` (locale-dependent, mixed case). Use a `CASE n WHEN 0 THEN 'SUNDAY' WHEN 2 THEN 'TUESDAY' WHEN 3 THEN 'WEDNESDAY' WHEN 5 THEN 'FRIDAY' … END`. (Probe P2 may find a `DimDate` weekday-name column that matches; the CASE is the safe default.)

---

## 3. Query objects → PBI tables (4 → 4)

Each Cognos query feeds exactly one page. Build **4 independent import tables** (see §8 for the rationale vs a single filtered table). No relationships between them.

| # | Cognos query | Page | Table / artifact | Branch set | Window | Weekday | Lot-status filter | Extra col |
|---|---|---|---|---|---|---|---|---|
| 1 | `Singapore - Inventory` | Singapore Inventory | `Singapore Inventory.m` (+`.commented.m`) | `SING, SNG4` | 365/3 | Sun, Wed | none | — |
| 2 | `Lot Status Data` | Lot Status | `Lot Status.m` (+`.commented.m`) | `SING,SNG4,CIN4,CIN2,CINC,AUBA,AUB2` | 365/2 | Sun, Tue, Fri | `NOT IN ('-')` | `DATE` |
| 3 | `Americas - Inventory` | Americas Inventory | `Americas Inventory.m` (+`.commented.m`) | `CINC, CIN2, CIN4` | 365/3 | Sun, Wed | none | — |
| 4 | `Aubange - Inventory` | Aubange Inventory | `Aubange Inventory.m` (+`.commented.m`) | `AUBA, AUB2` | 365/3 | Sun, Wed | none | `<> '2024-08-21'` extra blacklist |

All four share the identical column list (§4) and the identical KGs/USD derivations (§5). They differ only in the four dimensions above.

---

## 4. Column list + EDW mapping (identical across all 4 pages; Lot Status adds col 17)

Display order = the Cognos `<listColumns>` order (XML lines 59/99/139/179). Headers render the **data-item name verbatim** — there are **no `label=` overrides** in this report, so **no `displayName` renames** are needed in PBIR (contrast report 14). Keep header strings exactly, including the uppercase `MANUFACTURING REGION` and `DATE`.

| # | Header (verbatim) | EDW source expression | Format | Notes |
|---|---|---|---|---|
| 1 | Inventory Date | `snap.SnapDate` (probe P1 name) | `m/d/yyyy` | **month-first, 4-digit yr** — Cognos default (no explicit dateFormat in XML), confirmed from the xlsx cell format |
| 2 | Branch Plant | `LTRIM(RTRIM(snap.BusinessUnit))` | text | |
| 3 | Global Bulk Item | `it.ItemGlobalBulk` | text | |
| 4 | Bulk Item | `it.ItemBulk` | text | |
| 5 | 2nd Item Number | `it.ItemNum2nd` | text | Cognos sourced `MEASURE.ITEM_NUMBER_2ND`; probe P2 confirm `DimItem.ItemNum2nd` matches the measure grain |
| 6 | Stock Type Code | `it.StockingType` | text | |
| 7 | Location | `LTRIM(RTRIM(snap.Location))` | text | |
| 8 | Lot Number | `LTRIM(RTRIM(snap.LotNum))` | text | |
| 9 | Lot Status | `snap.LotStatusCode` | text | Cognos used `MEASURE.LOT_STATUS` (position-level); report 14 D-14d — position vs lot-master can differ, probe P2 |
| 10 | Master Planning Family | `it.MasterPlanningFamily` | text | filter key too (`NOT IN ('H2O','PKG')`) |
| 11 | Quantity on Hand | `SUM(snap.QuantityOnHandPrimaryUOM)` | `#,0` | already primary-UOM scaled (DW measure; no JDE implied-decimal) |
| 12 | Primary Unit of Measure | `snap.UOMPrimary` | text | group key; drives the KGs CASE (§5.1) |
| 13 | Quantity on Hand KGs | `SUM(<KGs row expr §5.1>)` | `#,0` | **NEW parity nuance — §5.1** |
| 14 | Extended Cost for Quantity On Hand USD | `SUM(<USD row expr §5.2>)` | `$#,0;($#,0)` | **highest risk — §5.2**; negatives in parens per the xlsx currency format |
| 15 | Weekday | `CASE n …` (§2.5) | text | uppercase day name |
| 16 | MANUFACTURING REGION | `CASE LTRIM(RTRIM(snap.BusinessUnit)) WHEN 'SING'/'SNG4' THEN 'Singapore' WHEN 'AUBA'/'AUB2' THEN 'Aubange' ELSE 'Americas' END` | text | verbatim Cognos `decode`, incl. the `Americas` else-branch |
| 17 | DATE *(Lot Status page only)* | `CAST(DATEADD(DAY,-1,GETDATE()) AS date)` | `d MMM, yyyy` | Oracle `to_date(sysdate-1)`; refresh-time run stamp; **day-first medium** (the one explicitly-formatted date) |

Join skeleton (all pages): `FROM BIQL.FactInventorySnapshot_History_Filtered snap INNER JOIN BIQL.DimItem it ON it.ItemSKey = snap.ItemSKey` + `DimCompany co` (currency basis, §5.2) + the `#lbf` KG-factor temp (§5.1) + the FX join (§5.2). Report 14 also joined `DimLot`; **report 18 needs no lot-master columns** (no Supplier Lot / Memo / expiry here), so **omit `DimLot`** — one fewer join, one fewer fan-out risk.

---

## 5. The three derived columns (the meat — adapts report 14's fixes + two new findings)

### 5.1 Quantity on Hand KGs — per-item factor, NOT the physical constant (NEW finding)

Cognos: `SUM(QUANTITY_ON_HAND · CONVERSION_FACTOR_KG)`, per-row factor from the DW measure, with the DW **`-1` sentinel** gotcha (report 14 fix #5 proved `-1` means "no conversion" and the guard multiplies sentinel rows ×20 KG per unit — e.g. `ETHAL.S` 8,520 GM → 170,400 KG). Report 18 has a **KGs-only** output (no LBs column).

Verified from the 2026-07-17 export (§10):
- **`UOMPrimary = 'KG'` → KGs = QOH exactly** (identity). E.g. Singapore `0.9 KG → 0.9`, Aubange `8000 KG → 8000`. Constant-safe.
- **`UOMPrimary = 'LB'` → KGs = QOH × ~0.4535973** — **NOT the physical `0.45359237`.** The three sampled Americas LB rows all give `KGs/QOH ≈ 0.4535973` (`5461 → 2477.094249129`; `16000 → 7257.555024`; `18.31 → 8.30536453059`). This is the DW's stored `CONVERSION_FACTOR_KG`, which differs from the physical constant in the **6th decimal** — enough to flip a `#,0` rounding on large lots: `16000 × 0.45359237 = 7257.478 → 7,257`, but Cognos shows `7257.555 → 7,258`. **A ±1 parity miss per affected LB row if you hard-code the physical constant.** Report 14 got away with the constant because its LBs column was identity and its KG rows were the ×2.20462262 direction; report 18's KGs-from-LB path is the one that bites.

**Therefore, lead with the dim factor, not the constant.** Materialize per-item KG factors once (report 14 fix #4 `#lbf` perf pattern — a `#temp` with a unique clustered index, in the same `Value.NativeQuery` batch with `[EnableFolding=false]`; do **not** use `OUTER APPLY`/`ROW_NUMBER` derived tables — both re-evaluate per row and hung report 14's jumpbox), then:

```sql
CASE
  WHEN LTRIM(RTRIM(snap.UOMPrimary)) = 'KG' THEN snap.QuantityOnHandPrimaryUOM        -- identity (exact)
  WHEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim) < 0     -- -1 sentinel guard
       THEN -(snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim)) * 20
  WHEN lbx.KGperPrim IS NOT NULL OR lbb.KGperPrim IS NOT NULL
       THEN snap.QuantityOnHandPrimaryUOM * COALESCE(lbx.KGperPrim, lbb.KGperPrim)     -- per-item DW factor (LB, EA, GM)
  ELSE snap.QuantityOnHandPrimaryUOM * 0.45359237                                      -- constant fallback ONLY where the dim lacks the item
END
```

Probe **P3b** must report the dim's coverage of report 18's LB/EA/GM item set and confirm the LB factor reproduces `~0.4535973` (not `0.45359237`). If coverage is poor (report 14 found the dim missing 809 KG + 10 LB items), the fallback constant path will produce those ±1 mis-rounds — **disclose** which rows and how many. `KG`-primary identity needs no dim and is always exact.

### 5.2 Extended Cost USD — cross-currency FX is a ROW FILTER, not just a value (HIGHEST RISK)

Cognos: `SUM(QUANTITY_ON_HAND · UNIT_COST · FROM_TO_EXCHANGE_RATE)`, FX from `FIN_CURRENCY_CONVERSION` joined **`FROM_CURRENCY_CODE = MEASURE.CURRENCY_CODE`, `TO='USD'`, `RATE_TYPE_CODE='-'`, `INVENTORY_DATE BETWEEN EFFECTIVE_START/END`**. **This is a comma-join in the FROM with WHERE predicates = an INNER JOIN.** Two consequences:

1. **It filters rows.** A position whose measure currency has **no** `→USD` rate (type `-`, effective on the snapshot date) is **dropped entirely** — not blanked. So the FX join co-determines the row counts, not merely the USD value.
2. **Cross-currency actually works in Cognos.** The export has USD populated for **all three currencies** — Aubange (EUR) `27,854/28,092` rows, Singapore `23,257/23,284`, Americas `65,997/68,053` (the few blanks are zero/NULL `UNIT_COST` on rows that *did* match FX, not FX misses — an inner join can't emit an unmatched row). And the same lot shows a **different USD on different dates** (Aubange `104DPM.E` 127.75 KG: `3,224.53` on Wed 03-18 vs `3,247.94` on Fri — via the Lot Status page), confirming the FX is **date-effective and genuinely cross-currency**.

**Why this is the highest risk:** report 14 proved its EDW `BIQL.DimCurrencyExchangeRates` join **matched zero cross-currency rows** and even left same-currency (USD→USD) rows blank until patched with an identity `1.0`. Report 14 survived because its validated pages were essentially all-USD (Americas) → identity. **Report 18 cannot dodge it:** Aubange (EUR) and Singapore (SGD/USD?) are entire pages that must convert to USD or their rows vanish.

**Build expression** (report 14's shape, but the cross-currency branch is now load-bearing and probe-gated):

```sql
snap.QuantityOnHandPrimaryUOM * snap.AmountUnitCost
  * CASE WHEN co.CurrencyCode = 'USD' THEN 1.0                       -- Americas: identity, no FX row needed (EDW has none)
         ELSE fxUSD.<rate column> END                               -- Aubange/Singapore: MUST resolve on EDW
```
```sql
LEFT JOIN BIQL.DimCurrencyExchangeRates fxUSD
       ON fxUSD.CurrencyCodeFrom = co.CurrencyCode AND fxUSD.CurrencyCodeTo = 'USD'
      AND fxUSD.CurrencyRateType = '-'
      AND snap.SnapDate BETWEEN fxUSD.DWEffectiveFromDate AND fxUSD.DWEffectiveThruDate
```

Three open decisions the probe (P4) must settle — **the build agent MUST run P4 before first refresh and MUST NOT guess:**
1. **Currency basis.** Cognos joins the *measure's* `CURRENCY_CODE`. Confirm EDW `snap.AmountUnitCost` is in the **company** currency and pull `co.CurrencyCode` for `SING/SNG4` (SGD? or USD?) and `AUBA/AUB2` (EUR). If Singapore cost is already USD, Singapore takes the identity branch and needs no SGD→USD rate.
2. **Do EUR→USD and SGD→USD rows exist** in `DimCurrencyExchangeRates` with rate type `'-'` (or blank), effective across **Jan–Jul 2026**? Pull them for a known date and count.
3. **Rate column + direction (multiply vs divide).** Oracle **multiplies** by `FROM_TO_EXCHANGE_RATE`. Report 14 tentatively used `× CurrencyConversionRateDivisor` **but never validated it cross-currency.** Reconcile a sample: take an Aubange EUR row from the export (e.g. `127,750 g`-scale row → USD `3,224.53` on 03-18) and confirm `QOH × AmountUnitCost × rate` reproduces it; if it comes out inverted, use the reciprocal / the multiplier column. Use `snap.SnapDate` (the row's own snapshot date) in the effective-window predicate so each date picks its own rate.

> Keep the FX join as a **LEFT JOIN + identity-for-USD**, not a literal INNER JOIN: EDW has no same-currency identity row, so an inner join would drop *all* Americas rows (report 14's exact bug). The identity `1.0` branch handles USD; the LEFT JOIN handles the rest. **Parity check:** this reproduces Cognos's inner-join row behavior *iff* EDW's `→USD` coverage matches Oracle's — i.e. every EUR/SGD row finds a rate. If some don't, those rows survive on EDW (LEFT) with a blank/NULL USD but would have survived-with-value on Cognos → a USD-column discrepancy on those rows (not a dropped row). Probe P4/P5 quantifies.

**Fallback disclosure (a human decision, per the team-lead brief):** if EDW genuinely lacks EUR→USD or SGD→USD (rate type `'-'`) for the window, the honest outcome is **the USD column is only valid for the Americas (USD-cost) branch; Aubange/Singapore USD is blank pending an FX source.** Do not fabricate a rate. Surface it as open question D-18c and escalate (resolve the FX source, or provision the `DW_LEGACY` gateway). Reference the pending `_tools\Probes\Probe-R14-FX-Factors.ps1` results — its 8 probes (FX-dim schema, rate types, candidate rows @ a date, company currencies) are the **same gate** for report 18; if those results already exist on the jumpbox, read them before re-probing.

### 5.3 Region + weekday — trivial, verbatim

`MANUFACTURING REGION` = the Cognos `decode` verbatim (§4 row 16). `Weekday` = the §2.5 CASE. Neither is a dim column.

---

## 6. `.m` structure (per table)

Shape = report 14's `Inventory.m` (a single `Value.NativeQuery` multi-statement batch, `[EnableFolding = false]`):

```
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(Source, "
        SET NOCOUNT ON;

        -- (1) materialize per-item KG factors ONCE  (report 14 fix #4 #lbf pattern)
        SELECT z.ItemNumShort, z.BU, z.KGperPrim
        INTO #lbf
        FROM ( SELECT k.ItemNumShort,
                      ISNULL(LTRIM(RTRIM(k.BusinessUnit)),'') AS BU,
                      k.KG / NULLIF(k.ConversionFactorSecToPrim,0) AS KGperPrim,
                      ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)),'')
                                         ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM))=LTRIM(RTRIM(k.UOMPrimary)) THEN 0 ELSE 1 END, k.UOM) AS rn
               FROM BIQL.DimItemUOMConversionLBKG k ) z
        WHERE z.rn = 1;
        CREATE UNIQUE CLUSTERED INDEX ix_lbf ON #lbf (ItemNumShort, BU);

        -- (2) the page query: inner derived table = row-level measures; outer = GROUP BY + SUM (§2.2)
        SELECT
            [Inventory Date], [Branch Plant], [Global Bulk Item], [Bulk Item], [2nd Item Number],
            [Stock Type Code], [Location], [Lot Number], [Lot Status], [Master Planning Family],
            SUM([_QOH])  AS [Quantity on Hand],
            [Primary Unit of Measure],
            SUM([_KGs])  AS [Quantity on Hand KGs],
            SUM([_USD])  AS [Extended Cost for Quantity On Hand USD],
            [Weekday], [MANUFACTURING REGION]
            /* Lot Status page: , [DATE] */
        FROM ( <inner SELECT: joins + §2.4/2.5 filters + row-level _QOH/_KGs/_USD/keys> ) r
        GROUP BY [Inventory Date],[Branch Plant],[Global Bulk Item],[Bulk Item],[2nd Item Number],
                 [Stock Type Code],[Location],[Lot Number],[Lot Status],[Master Planning Family],
                 [Primary Unit of Measure],[Weekday],[MANUFACTURING REGION] /* , [DATE] */
    ", null, [EnableFolding = false])
in
    Data
```

Notes: no CTE/`ORDER BY` needed in the outer wrapper — sorts live in the visual (§7). `SET NOCOUNT ON` keeps rowcount messages out of the stream. No downstream M steps, so losing folding costs nothing. The `.commented.m` master carries the full §5 rationale + probe TODOs inline (report 14 style); the production `.m` is byte-identical minus comments.

---

## 7. Pages / layout / formats

Four pages, each **one flat `tableEx`** (no matrix, no grouping, no totals row — the Cognos lists have no `listGroup`/`listOverallGroup`). Plus the house **`Last Refreshed`** card per page.

- **Columns / order:** §4, left→right. Headers verbatim (no renames). All 16 columns on Singapore/Americas/Aubange; 17 on Lot Status (append `DATE`).
- **Sort** (Cognos `<sortList>`, all pages identical, all ascending): **Inventory Date ▸ Global Bulk Item ▸ Bulk Item ▸ 2nd Item Number ▸ Branch Plant.** Set in the visual (query has no `ORDER BY`).
- **`summarizeBy: none`** on every identifier/text/date column (Inventory Date, Branch Plant, all item/lot/status/family/UOM/weekday/region codes, and `DATE`). The three numeric columns (QOH, KGs, USD) may keep `summarizeBy: sum` but there is **no totals row** in the Cognos output, so **turn column totals OFF** in the `tableEx`. A stray `summarizeBy: sum` on an identifier is the matrix-corruption trap — not applicable here (flat table) but keep identifiers `none` anyway.
- **Formats:** Inventory Date `m/d/yyyy`; `DATE` `d MMM, yyyy`; Quantity on Hand `#,0`; Quantity on Hand KGs `#,0`; Extended Cost USD `$#,0;($#,0)` (negatives in parens, matching the xlsx `[$$-409]#,##0;\([$$-409]#,##0\)`). PBI `formatString` is VBA-style.
- **House style:** red bold column headers + 1pt black cell borders (Cognos `color:red;font-weight:bold`, `border:1pt solid black`) — reproduce via the table style (cosmetic, **not** data-driven CF; no PBIR values-CF selectors anywhere in this report, so the `dataViewWildcard` trap does not arise).
- **`Last Refreshed` card:** copy report 14's `Last Refreshed` table verbatim (`PBIP\…SemanticModel\definition\tables\Last Refreshed.tmdl`) — the Eastern-time DST-aware M partition + `Last Refreshed Label` measure. One card per page. This is the as-of disclosure for the refresh-time-bound rolling window (§10).
- **Model hygiene:** Auto date/time OFF (`__PBI_TimeIntelligenceEnabled = 0`, no `LocalDateTable`). PBIR schema `2.0.0` is fine (local Desktop 2.155 / jumpbox 2.146 both accept it). Theme: copy `CY24SU10.json` from report 14/17.
- **`noDataHandler`:** Cognos "No Data Available" per list = standard non-reproduced LOW; a `tableEx` renders empty naturally. No action.

---

## 8. Table design decision — **4 separate import tables** (recommended)

Build one import table per page, not one shared table with page filters. Rationale:
- The four queries differ on **four independent axes** (branch set, window length, weekday set, and the `LotStatus NOT IN ('-')` filter), and Lot Status carries an **extra column** (`DATE`) the others don't. A single table would need per-visual filters replicating all four, plus a way to suppress `DATE` on three pages — more fragile than four clean tables.
- The windows differ (122 d vs 182 d) and **overlap in content** but not in grain intent (Lot Status is a held-inventory trend, the regionals are full-inventory) — a shared table would double-load the overlap and force every visual to re-filter.
- Matches the delivered report 13/14 pattern (one table per page) and keeps each `.m` a faithful 1:1 port of its Cognos query — easiest to validate against its own xlsx sheet.
- Cost: the snapshot fact is scanned up to 4× at refresh. Acceptable (report 14 refreshed a comparable fact; the `#lbf` temp is built per table). **No relationships** — four islands.

---

## 9. Probe plan (run once on the jumpbox before first refresh; deliver as `PROBE\R18 Probe.pbip`)

Package as a probe PBIP (report 12/17 template: one table per probe block, no visuals, `[EnableFolding=false]`, lint-clean). Six categories. **P1 and P4 are gates — the build's snapshot-date column and USD column cannot be finalized without them.**

1. **P1 — snapshot-date column (GATE).** `SELECT TOP 5 *` from `BIQL.FactInventorySnapshot_History_Filtered`; identify the physical snapshot-date column (§0.1 candidates). Confirm it is a per-position-per-date grain (count distinct snapshot dates in the last 200 days; expect the Wed/Sun/Tue/Fri cadence). If absent → switch the build to the §2.3 spine fallback and say so.
2. **P2 — column existence + decode lineage.** Existence of every §4 source column: `snap.BusinessUnit/Location/LotNum/LotStatusCode/QuantityOnHandPrimaryUOM/UOMPrimary/AmountUnitCost/ItemSKey/CompanySKey`; `it.ItemGlobalBulk/ItemBulk/ItemNum2nd/StockingType/MasterPlanningFamily`; `co.CurrencyCode`. Confirm `snap.LotStatusCode` (position) vs any `DimLot` lot-master status — Cognos used position-level. Confirm `it.ItemNum2nd` = the measure's `ITEM_NUMBER_2ND` grain. Check whether a `DimDate` weekday-name column matches the §2.5 CASE.
3. **P3 — fan-out + KG factors.** **P3a:** with the §2.1 GROUP BY, confirm no residual fan-out (row count = distinct display-key count) for one recent snapshot date; if the raw grain is >1:1, the GROUP BY (not DISTINCT) absorbs it — verify sums, not just counts. **P3b (KGs, GATE-ish):** `DimItemUOMConversionLBKG` coverage of report 18's LB/EA/GM item set; confirm the LB factor reproduces `~0.4535973` (not `0.45359237`) and quantify how many LB rows would mis-round under the constant fallback; confirm the `-1` sentinel still means ×20 KG/unit.
4. **P4 — FX (GATE, highest risk).** (a) `co.CurrencyCode` for `SING/SNG4` and `AUBA/AUB2` (SGD/USD? EUR?). (b) `DimCurrencyExchangeRates` rows for `EUR→USD` and `SGD→USD`, rate type `'-'` (and blank), effective across Jan–Jul 2026 — do they exist, and how many? (c) reconcile one Aubange EUR export row's USD against `QOH × AmountUnitCost × rate` to fix the rate column + multiply-vs-divide direction. Read any existing `Probe-R14-FX-Factors.ps1` output first.
5. **P5 — count/sum parity (tight-capture).** Reproduce each page for the **2026-07-17** window and compare to §10 (row counts + QOH/KGs/USD sums). Because the window is `sysdate`-relative, capture the Cognos re-run and the PBI refresh **the same day** (§10) or the earliest/latest snapshot dates drift and the counts won't tie exactly. Confirm EDW history reaches back to **2026-01-16** (Lot Status) — if EDW's snapshot cadence differs from the Oracle DW, counts may not tie even when the logic is right (report 14 §7.3 risk).
6. **P6 — format / spot-checks.** Inventory Date renders `m/d/yyyy` month-first; `DATE` renders `d MMM, yyyy` and equals refresh-day − 1; KG-primary rows KGs = QOH exactly; a sampled LB row matches the export KG to the unit (e.g. `5461 LB → 2477` after `#,0`); weekday names uppercase and only from the allowed set per page; USD negatives render in parens.

---

## 10. Validation targets (capture 2026-07-17; TIGHT-CAPTURE required)

Per-sheet, from `Intake\Cognos export … (filed 2026-07-17).xlsx`:

| Page (xlsx sheet) | Detail rows | Snapshot dates | Σ Quantity on Hand | Σ KGs | Σ Extended Cost USD |
|---|---|---|---|---|---|
| Singapore Inventory (`Singapore Inventory_1`) | **23,284** | 32 (03-18 → 07-15) | 83,329,492.37 | 82,713,322.71 | 292,908,817.53 |
| Lot Status (`Lot Status_2`) | **32,189** | 71 (01-16 → 07-14) | 103,906,823.56 | 57,458,559.07 | 180,245,130.32 |
| Americas Inventory (`Americas Inventory_3`) | **68,053** | 32 (03-18 → 07-15) | 346,051,294.85 | 157,395,652.29 | 537,246,993.73 |
| Aubange Inventory (`Aubange Inventory_4`) | **28,092** | 32 (03-18 → 07-15) | 53,606,435.40 | 53,281,960.35 | 214,703,335.23 |

Supporting facts (for spot-checks): Lot Status `DATE` col constant = **2026-07-16** (= run day − 1, so the export ran 2026-07-17). Primary-UOM mix — Singapore 97% KG, Americas 98% LB, Aubange 99% KG, Lot Status ≈ half LB / half KG. Lot Status has **no `-` status rows** (held statuses E/A/L/B/H/P/Q/T/R/Z only) and spans all three regions (Americas 16,767 / Aubange 7,833 / Singapore 7,589). USD populated on nearly all rows in every region (the handful of blanks per region are zero/NULL `UNIT_COST`, not FX misses — §5.2).

> **TIGHT-CAPTURE (house rule — the window moves daily).** Both window ends drift: the lower bound advances each day (the earliest Wed/Sun/Tue/Fri drops off) and a new snapshot is added at the top (the next Sun after 07-15 is 07-19; the next Fri after 07-14 is 07-17). So a PBI refresh on any day ≠ 2026-07-17 will legitimately differ from these counts. To validate exactly, **re-run Cognos and refresh PBI on the same day** and compare same-day. Sums round differently between the formatted export and a live query — compare with half-up rounding on both sides. Precedent: the tight-capture method note + report 06's rolling-window disclosure.

---

## 11. Cognos quirks to port verbatim (disclose to the business)

1. **Bad-snapshot blacklist dates.** `INVENTORY_DATE <> DATE '2025-05-07'` on **all four** queries; Aubange **also** `<> DATE '2024-08-21'`. Both dates are **already outside** today's rolling windows (earliest is 2026-01-16), so they are **currently inert** — but port them verbatim (as `AND snap.SnapDate <> '2025-05-07'` etc.) for exactness and future-proofing. Note in the `.commented.m` that they are inert as of build.
2. **`MANUFACTURING REGION` else-branch = `Americas`.** The `decode` maps only SING/SNG4/AUBA/AUB2; everything else (CIN*, and any stray branch) → `Americas`. Port including the else (§4 row 16).
3. **`DATE` column (Lot Status) = refresh-time `sysdate − 1`.** A constant column on every row (Oracle `to_date(sysdate-1)`), day-first `d MMM, yyyy`. It is **not** a data date — it's a run stamp. Reproduce as `CAST(DATEADD(DAY,-1,GETDATE()) AS date)`; it moves with each refresh.
4. **No expired date ceiling** (defect-C1 family CLEARED). The only date bounds are the `sysdate`-relative lower bounds — no hard-coded upper literal (contrast reports 08/10). The report is genuinely rolling, not silently expired; the "2025" in the title is legacy naming.
5. **QOH > 0 and `MPF NOT IN ('H2O','PKG')`** on all pages; **`Lot Status NOT IN ('-')`** on the Lot Status page only. Verbatim.
6. **The USD FX join is an inner join in Cognos** (§5.2) — it can drop rows. The build reproduces its row behavior via LEFT-JOIN + identity-for-USD; disclose any EUR/SGD rows that survive with blank USD if EDW FX coverage is incomplete.
7. **`noDataHandler` "No Data Available"** per list — standard non-reproduced LOW (a `tableEx` renders empty naturally).

---

## 12. Open questions / risks for Zack / team

- **D-18a (snapshot-date column — GATE).** Confirm `FactInventorySnapshot_History_Filtered` exposes a native per-snapshot-date column (§0.1 / probe P1). Very likely given report 14's 71× dup evidence; if not, the build uses the §2.3 spine fallback (heavier, cadence-dependent). *Recommend: probe P1 first; build §2.1.*
- **D-18b (KGs factor — NEW).** Americas LB→KG factor is `~0.4535973` (per-item DW `CONVERSION_FACTOR_KG`), **not** the physical `0.45359237`; the constant mis-rounds `#,0` on large LB lots (§5.1). *Recommend: dim factor primary, constant only as coverage fallback; probe P3b quantifies the residual.*
- **D-18c (USD/FX — HIGHEST RISK, GATE).** Cross-currency EUR→USD and SGD→USD **must** resolve on EDW `DimCurrencyExchangeRates` (rate type `'-'`, Jan–Jul 2026 effective) or entire Aubange/Singapore USD values are blank/wrong — report 14 proved this join matched zero cross-currency rows. Also settle the currency basis (is Singapore cost USD or SGD?) and the rate column + multiply-vs-divide. *Recommend: run probe P4 (and read any existing `Probe-R14-FX-Factors.ps1` output) before first refresh; if EDW FX genuinely absent, USD is Americas-only until the FX source is resolved — escalate (FX source or `DW_LEGACY` gateway), do not fabricate.*
- **D-18d (snapshot cadence parity).** EDW must have snapshots on the same Wed/Sun/Tue/Fri cadence back to 2026-01-16, or row counts won't tie exactly even with correct logic (report 14 §7.3). Probe P5. *Recommend: validate same-day (tight-capture); if EDW cadence differs, disclose the count delta as a source-cadence artifact, not a logic bug.*
- **D-18e (Lot Status source).** Position-level `snap.LotStatusCode` (Cognos used the measure's `LOT_STATUS`) — confirm vs any lot-master status (report 14 D-14d). Probe P2.
- **D-18f (tracker row).** Report ID / owner / prior-owner still TBD from the migration workbook.

---

## 13. Build agent decisions (2026-07-17 build — PBIP + probe delivered, lint-clean, NOT refreshed)

Built per §1–§11. Both semantic models load clean via the powerbi-modeling MCP `ConnectFolder` (main = 5 tables / 1 measure / 0 relationships; probe = 7 tables / 0 errors). All 27 report/model JSON files parse. Local SQL is firewalled → **no refresh attempted** (per constraint); the two derived columns and the snapshot-date column remain probe-gated exactly as §9/§12 require. Decisions made beyond the letter of the spec, all parity-conservative:

1. **Snapshot-date column = `snap.SnapDate` (placeholder, verbatim per §2.1).** Probe P1 is the gate. Used identically in all four page queries and in probe P5/P6, so the first jumpbox refresh of *either* the report or the probe immediately proves/refutes the name. If P1 finds a different physical name, do a single find-replace of `snap.SnapDate` across the 4 table `.m`/TMDL + the 2 probe tables (SELECT, weekday CASE, WHERE window/weekday/blacklist, and the `fxUSD` effective-date predicate). If **no** discrete snapshot-date column exists, switch to the §2.3 spine fallback. Flagged in every `.commented.m` header.
2. **FX rate column = `fxUSD.CurrencyConversionRateDivisor` with `× rate` (report 14 carryover).** §5.2 decision-3 (multiply-vs-divide + column) is UNVALIDATED cross-currency and is deliberately left as the report-14 shape so probe P4 can reconcile one Aubange EUR row and confirm/flip. LEFT JOIN + identity-for-USD kept (not the literal Cognos INNER) so Americas USD rows never drop.
3. **KGs leads with the per-item DW factor for LB (per D-18b),** constant `0.45359237` only in the ELSE branch where `DimItemUOMConversionLBKG` lacks the item; `-1` sentinel → ×20 KG/unit guard retained. (Report 14 hard-coded the LB constant; report 18 does not, because the KGs-from-LB path is the one that mis-rounds `#,0`.)
4. **Aggregation reproduces Cognos GROUP BY + SUM (§2.2/§6), no `SELECT DISTINCT`.** Inner derived table computes row-level `_QOH/_KGs/_USD`; outer `GROUP BY` the 13 display keys (14 on Lot Status, adding `DATE`) and `SUM`s the three measures.
5. **4 separate import tables, no relationships (§8).** `#lbf` KG-factor temp materialized once per table in the same `Value.NativeQuery` batch with `[EnableFolding=false]` (not `OUTER APPLY`/`ROW_NUMBER` — the report-14 perf trap). `DimLot` omitted (§4 — no lot-master columns here).
6. **tableEx numeric columns projected as plain `Column` fields (summarizeBy `none`), column totals OFF** — matches report 14's delivered flat list. No `displayName` renames anywhere (headers render the verbatim data-item names, incl. `MANUFACTURING REGION`/`DATE`). Sort set in the visual: Inventory Date ▸ Global Bulk Item ▸ Bulk Item ▸ 2nd Item Number ▸ Branch Plant (all ascending, 5 keys).
7. **PBIR versions:** report `version.json = 2.0.0` (both PBIP and probe); main report `definition.pbir` uses the `definitionProperties/1.0.0` schema (delivered-report-14 form), probe uses `2.0.0` (report-17-probe form) — both accepted by Desktop 2.155 / jumpbox 2.146. `cultures/en-US.tmdl` uses the minimal `linguisticMetadata` (Version 1.0.0) since there are no renames. `Last Refreshed` table + measure copied verbatim from report 14 (retagged `18a5…`). Theme `CY24SU10.json` copied from report 14.
8. **Probe design (§9).** P1/P2 are `sys.columns` metadata searches (always parse/refresh regardless of the unknown snapshot-date name); P3b/P4a/P4b hit dims whose column names report 14 already confirmed; P5 (count/date parity) and P6 (cadence + weekday CASE) use the `snap.SnapDate` placeholder so they double as the end-to-end P1 check. Formats: probe columns typed via `Table.TransformColumnTypes`. All 7 lint clean.
9. **Lineage-tag scheme:** tables `18aNa000-…`, columns `18aN0000-…` (N = page index), Last Refreshed `18a5…`, probe `1800NN00-…`. Page/visual GUIDs `18a10X0000000000e00X` / `18b10X0000000000f00X` / `…f0cX`.

**Open (unchanged from §12), all jumpbox-gated:** D-18a snapshot-date column (P1), D-18b KG factor coverage (P3b), D-18c FX cross-currency + basis + direction (P4 — HIGHEST RISK), D-18d cadence parity (P5), D-18e position-vs-master lot status (P2), D-18f tracker row. **Jumpbox next step:** run `PROBE\R18 Probe.pbip` once, read P1/P4 first, substitute the real snapshot-date column name if ≠ `SnapDate`, then first refresh → same-day tight-capture vs §10.

**2026-07-17 — `snap.SnapDate` placeholder RESOLVED (D-18a closed).** The view `BIQL.FactInventorySnapshot_History_Filtered` has **no** discrete snapshot-date column; it is an **interval (SCD) fact** — each row carries `StartDate` / `StopDate` (NULL `StopDate` = still current), proven by report 14's validated production query (`14 - …\Inventory.m`, WHERE `AsOf BETWEEN snap.StartDate AND ISNULL(snap.StopDate,'9999-12-31')`). Snapshots are now reconstructed instead of read from a column: a tally-CTE date list (last 200 calendar dates: `digits → nums (h.i ≤ 1) → DATEADD(DAY,-n,GETDATE())`) is materialized as a `#dates` temp table at the top of each batch and joined to the fact via `d.d BETWEEN snap.StartDate AND ISNULL(snap.StopDate,'9999-12-31')`. Every former `snap.SnapDate` reference (the `[Inventory Date]` output, the weekday `CASE`, the `fxUSD` effective-date `BETWEEN`, the rolling-window filter, the weekday-set filter, and the bad-snapshot blacklist) became `d.d`; **no other logic changed** (windows, weekday sets — regional Sun+Wed `(0,3)`, Lot Status Sun+Tue+Fri `(0,2,5)` — blacklist literals, BU lists, KG/LB factor logic, FX joins all identical). Lot Status's `[DATE]` run-stamp column stays `CAST(DATEADD(DAY,-1,GETDATE()) AS date)` (a literal, never a snapshot-date ref). Applied to all three representations (`.m` + `.commented.m` + PBIP TMDL) of the 4 page tables, byte-identical SQL across `.m`/TMDL; production files remain comment-free, `.commented.m` headers updated. Probes P5/P6 already carry the identical pattern (spine + BETWEEN join). Production model re-lints clean via `ConnectFolder` (5 tables / 1 measure / 0 errors). BUILD.md item 1 above and §2.1/§9/§12 references to a physical snapshot-date column are superseded by this note.

**2026-07-17 (round 2, after jumpbox probe readout) — grain corrected + 2 follow-ups.** (a) **`snap.CalendarDate` is the real per-day grain column** (date, ordinal 1; found by P1). The view is an *exploded* interval×calendar fact — the `#dates` BETWEEN-join from the morning multiplied rows (P5 measured ~825k Singapore rows ≈ 23.5k/date × 35 dates). Reverted all 4 page tables (`.m` + `.commented.m` + TMDL) and probes P5/P6 back to the plain `FROM BIQL.FactInventorySnapshot_History_Filtered snap` shape with every date reference now `snap.CalendarDate` (deleted the `#dates` temp / tally-CTE and the `d.d BETWEEN` join); `.commented.m` grain/snapshot notes rewritten to say CalendarDate confirmed via P1 (StartDate/StopDate still exist but are not the filter). (b) **Blank lot-status fix:** `snap.LotStatusCode NOT IN ('-')` was insufficient (EDW stores blank/held statuses as `''`/spaces; `'-'` is only Cognos's display rendering — P5 over-counted ~3.3×); replaced with `LTRIM(RTRIM(ISNULL(snap.LotStatusCode,''))) NOT IN ('', '-')` in Lot Status (×3 files) and P5's Lot Status branch (report 13/14-family gotcha, noted in `.commented.m`). (c) **P4b FX Rows widened** to a discovery dump after it returned zero rows — no `CurrencyCodeTo='USD'` rows exist in the 2026 window; dropped the `CurrencyCodeTo`/`CurrencyCodeFrom` filters, kept the date-window overlap, `SELECT TOP 500`, `ORDER BY CurrencyCodeFrom, CurrencyCodeTo, DWEffectiveFromDate` (report-14 `To='USD', RateType='-'` FX join may have been silently NULL — same lineage risk). Both models re-lint clean (`ConnectFolder`: production 5 tables / 1 measure, probe 7 tables). Zero `#dates` / `d.d` / `snap.SnapDate` remain in any table.

## §14 First probe readouts (2026-07-17, jumpbox rounds 1-2)

- **P1 (44 columns dumped): the view has `CalendarDate` (date, ordinal 1)** — an exploded per-day grain — alongside `StartDate`/`StopDate`. The round-1 interval-join rework over-counted (each row × each matching day); round 2 reverts to plain `CalendarDate` filters (the original build shape, name swapped).
- **P2:** all 8 checked Dim columns exist (CompanySKey, CurrencyCode, ItemSKey, ItemNum2nd, MasterPlanningFamily, StockingType, ItemBulk, ItemGlobalBulk).
- **P4a (currency map):** CINC/CIN2/CIN4/SING/SNG4 → USD; AUBA/AUB2 → EUR.
- **P4b (FX rows): ZERO rows for CurrencyCodeTo='USD' in the 2026 window** — report-14's `fxUSD` join (`To='USD', RateType='-'`) may have been silently NULL all along (shared lineage risk). P4b widened to a full-direction discovery dump for the next refresh; FX stays the open gate.
- **P5 (pre-fix counts):** Singapore 825,427 raw / 35 snap dates ≈ 23,583 per-date ≈ export target 23,284 ✓ grain confirmed. Lot Status 8,279,914 / 79 dates ≈ 104,809 vs target 32,189 → ~3.3x over: `LotStatusCode NOT IN ('-')` misses EDW blanks (''/spaces; '-' is only the Cognos display) — fixed round 2 per the report-13/14 house gotcha.
- **P6:** interval rows start on ALL weekdays — EDW rolls DAILY, so Wed/Sun (and Sun/Tue/Fri) as-of reconstruction is fully supported; snap-date sets will be generated exactly.

**Next: re-refresh probe (P4b discovery + P5 corrected counts are the reads), then production first refresh → tight capture vs §10.**

### §14.1 Round-2 probe readout (2026-07-17 ~13:21) — RETENTION GAP FOUND (potential route blocker) + FX table empty

- **P6 (CalendarDate cadence): the `_Filtered` view keeps DAILY snapshots only from 2026-05-01 forward; older history is pruned to MONTH-ENDS** (12/31, 1/31, 2/28, 3/31, 4/30 — none of which are Wed/Sun). 83 dates total in the last ~200 days. 7/17 (today) shows only 8,855 rows — intraday partial load, exclude "today" from any capture.
- **P5 (corrected counts): Singapore 16,618 rows / 22 snap dates** (needs ~35 — the 13 Wed/Sun dates from ~3/17→4/30 no longer exist in EDW); **Lot Status 16,816 / 35 dates** (needs ~79 — same cause, bigger 6-month window). The Cognos legacy Oracle DW retains the full twice-weekly history; EDW does not. **If the pruning is rolling (looks like a retention policy, not a 5/1 go-live), the head of both report windows will ALWAYS fall in the month-end-only zone → full parity impossible on this view.**
- **P4b round 2: STILL ZERO rows** even with currency filters dropped (only the 2026 date-overlap kept) → `BIQL.DimCurrencyExchangeRates` may be empty or effective-dated entirely outside 2026. Round 3 = bare `TOP 500` dump, no filters at all. **Corollary: report 14's fxUSD/fxEUR LEFT JOINs have likely been producing NULL conversions — flag to the team.**
- **P7 "Snapshot Objects" AUTHORED** (INFORMATION_SCHEMA search for %Snapshot%/%Currency%/%Exchange% objects): looking for an UNfiltered history table/view with full daily or twice-weekly retention. Probe lint-clean (8 tables).
- **Decision tree after P7**: (a) unfiltered object with full history exists → repoint production; (b) nothing → escalate to Nick/Dave: EDW route can only reproduce the report from 5/1 forward (+month-ends), or the report's windows shrink, or DW_LEGACY/other source needed. Production first refresh stays HELD.

### §14.2 Round-3 probe readout (2026-07-17 ~13:26) — P7 candidates found, FX table = CHF→EUR only; round 4 authored

- **P7 (object hunt): 58 snapshot/currency objects.** Inventory-history candidates beyond the pruned `_Filtered` view: **`BIQL.TbInventorySnapshot_History`** (VIEW, no `_Filtered` suffix — prime repoint candidate), **`dbo.FactInventorySnapshot_History`** (BASE TABLE — the physical history; if pruning is a physical retention job, it happens here and nothing has the old dailies), `BIQL.HistoricalSnapshot` (BASE TABLE, purpose unknown), `BIQL.TbInventorySnapshot_Detail`. Also a large FX family r14 never used: `DimCurrencyExchangeRatesUSDDaily`, `DimCurrencyCrossRatesCalc`, `TbCurrencyRates`(+`_History`,`DailyA/B`), `CurrencyRatesTo` (BASE TABLE), `DimCurrencyRatesToCXA/B/C`, `DimCurrencyRestatementRates*`.
- **P4b round 3 (bare TOP 500, ORDER BY DWEffectiveThruDate DESC): table is NOT empty but is useless for us** — 498/500 rows are **CHF→EUR** (plus 1 all-blank row, 1 `???→???` row), all `DWEffectiveFromDate = 2026-06-16`, thru dates NULL, `CurrencyRateType` blank. `BIQL.DimCurrencyExchangeRates` effectively contains only CHF→EUR ⇒ **CONFIRMED: report 14's `fxUSD` (`To='USD'`) and any EUR joins on this view returned NULL for every currency that matters — team flag stands, now with proof.**
- **Round 4 AUTHORED (probe now 11 tables, lint-clean):**
  - **P8 Candidate Columns** — INFORMATION_SCHEMA.COLUMNS dump for the 4 history candidates + 4 FX candidates (names/types unknown until now).
  - **P9 History Cadence** — dynamic-SQL cursor (columns unknown at author time): per history candidate (`dbo.FactInventorySnapshot_History`, `BIQL.TbInventorySnapshot_History`, `BIQL.HistoricalSnapshot`), picks the best date column (CalendarDate > %SnapshotDate% > SnapDate > AsOfDate > StartDate > first date col) and returns per-month distinct-date counts from 2025-12-01 + an `ALL` row (full retention depth). **This is the repoint-vs-escalate decider:** ~30 dates/month in Mar–Apr 2026 on any object → repoint; month-ends only everywhere → escalate.
  - **P10 FX Alt Samples** — TOP 25 rows each from `DimCurrencyExchangeRatesUSDDaily` / `DimCurrencyCrossRatesCalc` / `TbCurrencyRates` / `CurrencyRatesTo` via the `FOR JSON PATH` one-string-column trick (schema-agnostic).
- Production first refresh still HELD. **Jumpbox next: re-copy probe → refresh → read P9 first, then P8/P10.**

### §14.3 Round-4 probe readout (2026-07-17, r18-readout agent) — REPOINT DECIDED; round 5 authored (P11-P13)

- **P9 verdict: `dbo.FactInventorySnapshot_History` COVERS THE GAP — repoint production to it.** Daily distinct StartDates every month (2025-12: 31, 2026-01: 31, 02: 27, 03: 31, 04: 30, 05: 31, 06: 30, 07: 17), ALL = 1,865 distinct dates spanning 2021-06-02 → 2026-07-17. It's the physical SCD2 interval fact (StartDate/StopDate, NO CalendarDate) → production reverts to the **round-1 `#dates` spine + `BETWEEN StartDate AND ISNULL(StopDate,...)` shape**, pointed at dbo. `BIQL.TbInventorySnapshot_History` = same month-end pruning as `_Filtered` (reject); `BIQL.HistoricalSnapshot` = 4-col safety-stock slim table, empty window (reject).
- **P8 caveat: dbo table (48 cols) has NO embedded currency cols** (no LocalCurrency/ToRateUM*) and none of the derived multiplier/reorder cols the BIQL views add — FX and any derived columns must be joined/derived explicitly. It has LotStatusCode, full quantity set, AmountUnitCost/ValueAtCost, and natural keys (ItemNumShort, BusinessUnit, Location, LotNum) + SKeys.
- **P10: FX alternatives are LIVE, not empty** (r14's zero-rows problem is specific to `DimCurrencyExchangeRates`). `DimCurrencyExchangeRatesUSDDaily` = cleanest: {CalendarDate, CurrencyCodeFrom (ISO), Effective Date, Exchange Rate} — **direct multiplier local→USD**, daily, weekend-flat. JDE-style tables (TbCurrencyRates/CurrencyRatesTo/RatesToCXA) carry ToRateDaily/A/M and are the only ones with CurrencyCodeTo='EUR'. LIMITATION: samples were oldest-25 (2005/2012) → 2026 values unconfirmed.
- **Round 5 authored (P1-P10 moved to `PROBE\retired\`; probe = 3 tables, lint-clean, refresh will be FAST):** P11 = per-(from,to) 2026 row counts/date ranges across all 4 FX sources; P12 = most-recent rate rows (≥2026-06) for EUR/SGD/AUD→USD and →EUR with explicit ToRateDaily/A/M values; P13 = OBJECT_DEFINITION chunk dumps of `_Filtered`, `TbInventorySnapshot_History`, `FactInventorySnapshot`, `USDDaily` — reveals exactly what filtering/joins the `_Filtered` view applies (blacklists? branch filters? DISTINCT?) so the dbo repoint reproduces it faithfully, and how the view derives CalendarDate/currency.
- **Plan: after P11-P13 read → spawn Opus build agent for the production repoint** (4 tables × .m/.commented.m/TMDL: dbo source + #dates spine + FX join per P11/P12 verdict + whatever `_Filtered` logic P13 reveals; keep blank-lot-status fix + blacklists + weekday sets). Production first refresh stays HELD until then.

### §14.4 Round-5 probe readout (2026-07-17) — THE FIX IS FULLY SPECIFIED (view SQL obtained)

**P13 OBJECT_DEFINITION cracked it. The retention gap is in a CALENDAR SPINE, not the data.** `BIQL.FactInventorySnapshot_History_Filtered` is literally:
```
FROM BIQL.DimCalendarInventorySnapshot SNDT
LEFT OUTER JOIN ( SELECT ... FROM dbo.FactInventorySnapshot_History ) FISH
   ON  CASE WHEN CompanySKey = 2 THEN DATEADD(DAY,1,SNDT.CalendarDate) ELSE SNDT.CalendarDate END
       BETWEEN FISH.StartDate AND ISNULL(FISH.StopDate, <current date>)
WHERE SNDT.CalendarDate BETWEEN '2021-06-01' AND <yesterday, per-company timezone>
```
- Output `CalendarDate` = **the spine's** SNDT.CalendarDate (NOT a fact column). The view's "daily-only-since-5/1, month-ends-before" behavior comes ENTIRELY from what dates live in `DimCalendarInventorySnapshot` ("any date within current + previous month plus last day of any prior month" — comment verbatim). **`dbo.FactInventorySnapshot_History` itself has daily StartDate/StopDate intervals back to 2021-06 (P9: 1,865 dates).** So the repoint is not a rebuild — it's swapping the pruned spine for our own weekday-date spine over the same interval fact.
- **CRITICAL parity detail we'd otherwise have missed — the CompanySKey=2 timezone shift.** The interval join uses `DATEADD(DAY,1, spineDate)` for CompanySKey=2 (a commented output-side block does the reverse -1 for display). Must replicate verbatim: output the spine date, but match the interval with +1 day when CompanySKey=2. (Which BU = company 2 TBD, but transcribe faithfully regardless; disposal-fee CASE shows CompanySKey 2→'55UC00010', 5→'55UC00020'.)
- `StopDate` NULL = still-current; `ISNULL(FISH.StopDate,'9999-12-31')` in the BETWEEN is equivalent for date containment.
- `FactInventorySnapshot` (non-history, current-day) uses the SAME shape with `CurrentDateByTimeZone` — confirms the pattern.
- `TbInventorySnapshot_History` (the rejected pruned sibling) is built ON TOP of `_Filtered` and adds the UOM ToRateUMA/UMB/UMC logic + LocalCurrency from DimCompany — **its actual FX rate join (CurrencyRatesTo) is COMMENTED OUT**, i.e. that view never money-converts. Confirms FX must be done in our query.

**FX RESOLVED (P11/P12).** Current production joins `BIQL.DimCurrencyExchangeRates` (`To='USD', RateType='-'`, `× CurrencyConversionRateDivisor`) — that table is **CHF→EUR only** (proven §14.2), so every non-USD company's `_USD` has been NULL. Correct live source = **`BIQL.DimCurrencyExchangeRatesUSDDaily`**: ISO from-code, `CalendarDate` daily spine (weekend-flat via Effective Date), **direct multiplier** `localAmount × [Exchange Rate] = USD`. 2026 coverage confirmed: EUR→USD 197 rows to 7/16 (~1.1447), SGD→USD 181 rows to 6/30 (~0.7725), + CNY/INR/JPY. **AUD appears in NO table** — Aubange = Belgium/EUR, not Australia; my AUD guess was wrong, harmless. New FX join: `LEFT JOIN BIQL.DimCurrencyExchangeRatesUSDDaily fxUSD ON fxUSD.CurrencyCodeFrom = co.CurrencyCode AND fxUSD.CalendarDate = <spine date>`; expression `... * CASE WHEN co.CurrencyCode='USD' THEN 1.0 ELSE fxUSD.[Exchange Rate] END`.
- **OPEN (validate at capture / good Dave Q): `co.CurrencyCode` for the in-scope companies.** If SING/SNG4/CINC/CIN2/CIN4 are USD-functional (CurrencyCode='USD'), the `_USD` FX is identity and the broken join never mattered for them — only Aubange (EUR) hit the ELSE and went NULL. Either way USDDaily makes it correct. P4a mapped companies→{USD for CIN*/SING/SNG4, EUR for AUBA/AUB2}; if that map = DimCompany.CurrencyCode then Singapore/Americas are identity and only Aubange's EUR→USD needs the rate (which USDDaily has). Confirm Aubange `_USD` is non-null post-fix.

**REPOINT SPEC (all 4 tables — Singapore/Americas/Aubange/Lot Status — identical except BU filter, window 365/3 vs 365/2, weekday set (0,3) vs (0,2,5)):**
1. Materialize a `#dates` spine (tally-CTE → last ~200 calendar dates) filtered to the table's weekday set + rolling window + blacklist `<>'2025-05-07'` (Aubange also `<>'2024-08-21'` per its current file) — i.e. MOVE those WHERE predicates out of the outer query into the spine. Index it.
2. `FROM #dates d JOIN ( <the _Filtered inner SELECT, verbatim, FROM dbo.FactInventorySnapshot_History> ) FISH ON CASE WHEN FISH.CompanySKey=2 THEN DATEADD(DAY,1,d.d) ELSE d.d END BETWEEN FISH.StartDate AND ISNULL(FISH.StopDate,'9999-12-31')`. Alias FISH as `snap`, expose `d.d AS CalendarDate`.
3. Keep verbatim: DimItem/DimCompany INNER joins, `#lbf` KG/LB temp + COALESCE logic, QOH>0, MasterPlanningFamily NOT IN ('H2O','PKG'), Lot Status blank-status fix `LTRIM(RTRIM(ISNULL(snap.LotStatusCode,''))) NOT IN ('','-')`, GROUP BY, column list/aliases, Weekday CASE, MANUFACTURING REGION CASE.
4. FX join swapped per above. `AmountUnitCost` is per-primary-UOM in company-domestic currency → QOH(primary) × unitcost(local) × FX = USD; structure already correct.
5. Perf: single `Value.NativeQuery` batch, `#dates` + `#lbf` as indexed temps, `[EnableFolding=false]` (native-query-temp-table gotcha).

Parity check after refresh: on the dates the pruned view ALSO had (5/1-forward + month-ends), our counts must match the earlier P5 numbers exactly; the NEW dates (Wed/Sun 3/17→4/30, Sun/Tue/Fri back to 1/16) are the ones that close the gap. **This unblocks the R18 first refresh.** Dispatching Opus build agent to rework all 12 files (4 tables × .m/.commented.m/TMDL). Probe P1-P13 all answered → after build, retire P11-P13 to `PROBE\retired\`.

### §14.5 REPOINT APPLIED (2026-07-17) — lint-clean, first refresh UNBLOCKED

All 4 page tables reworked in-session (main, not an agent) across all 3 representations (.m / .commented.m / PBIP TMDL) via a single generator (`scratchpad\repoint_r18.py`) so the three stay byte-consistent. Changes exactly per §14.4:
1. **Source**: `BIQL.FactInventorySnapshot_History_Filtered snap` → `#dates dt INNER JOIN dbo.FactInventorySnapshot_History snap ON (CASE WHEN snap.CompanySKey=2 THEN DATEADD(DAY,1,dt.d) ELSE dt.d END) BETWEEN snap.StartDate AND ISNULL(snap.StopDate,'9999-12-31')`. `#dates` = tally-CTE list of the required snapshot dates (weekday set + rolling window `>= today-365/N` **and new upper cap `<= yesterday`** to match the view's per-company `<= Yesterday` — excludes today's intraday-partial load + blacklist), indexed. Output `[Inventory Date]` = `dt.d`; Weekday CASE uses `dt.d`.
2. **FX**: broken `BIQL.DimCurrencyExchangeRates` (CHF→EUR only) → `BIQL.DimCurrencyExchangeRatesUSDDaily fxUSD ON fxUSD.CurrencyCodeFrom = co.CurrencyCode AND fxUSD.CalendarDate = dt.d`; expression `× fxUSD.[Exchange Rate]` (multiplier, was the misnamed `CurrencyConversionRateDivisor`). USD-functional companies still short-circuit to 1.0.
3. Everything else verbatim: #lbf KG/LB temp + COALESCE, DimItem/DimCompany inner joins, QOH>0, MPF NOT IN, Lot Status blank-status fix + [DATE] col, GROUP BY, all aliases/format.

**Fixed pre-existing DRIFT:** the PBIP TMDL still carried the original `snap.SnapDate` placeholder (never updated when the .m moved to CalendarDate in round 2) — it would have errored on refresh. The regenerate resolved .m↔TMDL drift; all three now identical SQL.

Production model re-lints clean via `ConnectFolder` (5 tables / 1 measure / 0 errors); TMDL verified free of SnapDate/_Filtered/Divisor, carrying dbo + USDDaily + #dates + the CompanySKey=2 shift; CRLF + annotation tails intact.

**FIRST REFRESH IS NOW UNBLOCKED — this is the R18 priority (Dave 2026-07-17).** Jumpbox next: copy `PBIP\` production → refresh → parity checks: (a) on dates the pruned view ALSO had (5/1-forward + month-ends) counts must equal the earlier P5 numbers; (b) the NEW dates (Wed/Sun 3/17→4/30, Sun/Tue/Fri back to ~1/16) now populate — Singapore should reach ~35 dates (was 22), Lot Status ~79 (was 35). **OPEN validation: confirm `DimCompany.CurrencyCode` for in-scope companies and that Aubange `_USD` is non-NULL (EUR→USD via USDDaily); if SING/SNG4/CIN* are USD-functional their FX is identity.** Then same-day tight capture vs §10. Probes P1-P13 all answered → retire to `PROBE\retired\` once the repoint refresh validates.

### §14.6 FIRST REFRESH VALIDATED (2026-07-17) — repoint clean, gap closed, FX fixed

Production refreshed on jumpbox, read via MCP DAX (port 62064). All checks pass:
- **Date gap CLOSED.** Singapore 26,172 rows / **35 dates** (was 22), Americas 76,911/35, Aubange 31,833/35, Lot Status 36,474 / **78 dates** (was 35). Matches §10 targets (~35 / ~79).
- **Date windows exact to the Cognos export.** Singapore 3/18/2026 (Wed)→7/15/2026 (Wed); Lot Status 1/16/2026 (Fri)→7/14/2026 (Tue). Lower bounds = the intake spec's exact `>= today-365/3` (3/18) and `>= today-365/2` (1/16) first-weekday; upper = latest in-set weekday ≤ yesterday (today 7/17 excluded — the new `<= yesterday` cap works). Weekday sets exact: regional SUNDAY/WEDNESDAY, Lot Status SUNDAY/TUESDAY/FRIDAY.
- **Overlap parity EXACT.** Singapore rows on dates ≥ 5/1 (the dates the pruned `_Filtered` view also had) = **16,618 on 22 dates — identical to the earlier probe P5 count**. The dbo reconstruction reproduces the view row-for-row on shared dates; the repoint only ADDED the 13 missing daily dates (3/18→4/30, ≈9,554 rows). Strong evidence the interval BETWEEN join + CompanySKey=2 shift are faithful.
- **FX FIXED.** Zero NULL `[Extended Cost ... USD]` across all 4 tables. Aubange USD now fully populated ($167.76M; was silently NULL under the broken CHF-only `DimCurrencyExchangeRates`). **Currency question resolved:** Singapore 7/1–7/15 rows are non-null despite USDDaily SGD→USD ending 6/30 ⇒ SING/SNG4/CIN* companies are **USD-functional** (FX identity 1.0); only Aubange (EUR) exercises the rate, and USDDaily EUR→USD covers through 7/16. No SGD-gap risk.

**STATE: R18 structural validation COMPLETE and clean. Next = same-day tight capture** (fresh Cognos export + this refresh, minutes apart) → report-out workbook per STANDARD layout → publish. Probes P1-P13 fully answered → retire `PROBE\` tables to `PROBE\retired\`. This closes the Dave-priority item.

### §14.7 Parity vs fresh Cognos export (2026-07-17) — rows/QOH/KGs PASS, USD systematically ~31% LOW (blocker)

Compared PBI refresh (port 54858) vs Cognos export `Downloads\1 - Singapore Warehouse Inv 2025 (1).xlsx` (4 sheets), per-date × per-measure. Method: aggregate each side per Inventory Date, compare row counts + SUM(QOH/KGs/USD).

**Row parity — PASS (differences explained, all small or Cognos-side data gaps):**
- Cognos has FEWER snapshot dates than EDW: regional 32 vs 35 (PBI-only 5/20, 6/21, 7/5), Lot Status 71 vs 78 (PBI-only 1/20, 3/06, 5/22, 6/19, 6/21, 7/03, 7/05). The legacy Oracle DW simply lacks those daily snapshots; EDW has them. Our rebuild is *more* complete.
- **Cognos 4/8 is a broken/partial snapshot**: 46 / 103 / 76 rows (Sing/Amer/Aub) vs our full 724 / 2159 / 911. Legacy DW data-quality gap, not ours.
- On clean shared dates, row counts track to <1%: Singapore -0.1% (median delta -1/date), Americas +0.2% (+5), Aubange +0.7% (+6, consistent small positive — minor inclusion edge to investigate), Lot Status +2.4%. Genuine cross-warehouse snapshot jitter (legacy Oracle DW vs EDW), same family as R17.

**Quantity + KGs columns — PASS:** on clean shared dates, QOH totals within 0.0–0.24% (per-date median 0.05–0.30%), KGs within 0.0–0.84% (median 0.06–0.78%). Effectively matching; residual = row jitter + tiny per-item KG-factor differences.

**USD Extended Cost — FAIL, systematic ~31% shortfall on EVERY sheet:** Singapore −29.3%, Americas −31.5%, Aubange −31.6%, Lot Status −31.1% (per-date median |diff| 29–37%). **Consistent across the USD-functional sheets (Singapore/Americas) where NO FX rate is applied → it is NOT the exchange rate.** Root-cause hypothesis: our `_USD = QOH × AmountUnitCost × FX` uses the **unit material cost**, whereas Cognos's "Extended Cost for Quantity On Hand" is the **stored fully-loaded extended value** (`dbo.FactInventorySnapshot_History.AmountValueAtCost`, material+labor+overhead). Back-of-envelope on Aubange 127PAR.E (8000 KG): Cognos 2.142 USD/kg vs our ~1.48 → ratio ~0.69, consistent with a material-only vs fully-costed component split. **Likely fix: `_USD = snap.AmountValueAtCost × FX` (drop the QOH×UnitCost recompute).** MUST confirm via probe: compare `AmountValueAtCost` vs `QOH×AmountUnitCost` for sample rows and tie to the export before changing production. This column was never validated on report 14 (its FX was NULL, so USD was never checked) → latent, surfaced now.

**VERDICT: not publish-ready.** Rows/QOH/KGs are at parity; USD needs the cost-basis fix + one confirming probe, then a re-refresh and re-compare of the USD column only. Date-coverage differences (EDW-only dates, broken Cognos 4/8) are Cognos-side gaps to disclose, not rebuild defects — decision needed on whether to match Cognos (exclude) or keep the fuller EDW data.

**§14.7 amendment — USD cause PINPOINTED (P14, 2026-07-17).** P14 dumped both candidate cost calcs vs Cognos USD for 5 export rows:
- 2/5 (AUBA 104DPM.E, SING 104PA.S): our `QOH×AmountUnitCost×FX` = Cognos EXACTLY ($3224.53, $1371.71). Where EDW has a cost, we're right (incl. Aubange EUR→USD via USDDaily — FX is correct).
- 2/5 (SING 104DPM.S, CIN2 100FGK): EDW `AmountUnitCost` = `AmountValueAtCost` = **0** (missing), Cognos has $16.20 / $23,919.18.
- 1/5 (AUB2 127PAR.E): EDW unit 2.01 → $18,516; Cognos implies 1.86 → $17,134 (same FX, different COST).
- Also proven: `AmountValueAtCost` = `QOH × AmountUnitCost` exactly ⇒ "use value-at-cost" is a NO-OP; not a fully-loaded-vs-material issue.
**Root cause = cost DATA, not formula:** `dbo.FactInventorySnapshot_History.AmountUnitCost` is 0/absent (or a different method) for many lots; the legacy Cognos DW sources cost from a dedicated cost table. Matches the `_Filtered`/`TbInventorySnapshot_History` view's **commented-out** `dbo.DimItemCost_History` join (`CostMethod='07'`, effective-dated) — PS disabled it, leaving the snapshot's sparse embedded cost. **Fix = join `dbo.DimItemCost_History` (method 07, `CalendarDate BETWEEN StartDate AND StopDate`) for the unit cost, prefer it over the snapshot's embedded cost, then × FX.** P15 authored to confirm: pulls `DimItemCost_History` method-07 unit cost for the same 5 keys and computes `QOH×costhist×FX` vs Cognos — if all 5 tie, the fix is proven. Probe lint-clean (5 tables). **Refresh probe → read P15.** Best Dave question: exact cost lineage of the Cognos "Extended Cost" column (table + cost method + effective-dating).

### §14.8 USD FIX APPLIED + SINGAPORE 1:1 PARITY (2026-07-17) — PUBLISH-READY

Cost-source hunt resolved (P14-P17 + Dave + direct SSMS on EDWPROD by Zack). Findings that redirected the fix:
- `DimItemCost_History` / `TbStandardItemCost_TABLE` / FCR method-07: **all rejected** — either NULL for the `-1` lots or costs that matched neither Cognos nor the known-good snapshot costs. FCR (`TbInventorySnapshotFCR_*`, Dave's pointer) is the *conceptual* source (method-07 `AmountValueAtCost`) but its history is **date-pruned** (daily current+prior month, month-ends before, back 06/21), so it cannot supply daily historical cost for backfill dates.
- **Real mechanism (proven via sibling-lot probe):** where a lot's `ItemCostSKey <> -1`, the snapshot's own `AmountUnitCost` already ties to Cognos to the penny. The ONLY broken rows are `ItemCostSKey = -1` (embedded cost = 0). For those, the **item/branch standard cost lives on a sibling snapshot row** (the zero-qty blank-lot cost carrier, and/or any costed sibling lot) at the SAME date/item/branch — method-07 standard cost is item/branch-level, identical across lots.

**Fix (applied to all 4 tables, TMDL + `.m` + `.commented.m`):**
1. `_USD = QOH × COALESCE(NULLIF(AmountUnitCost,0), MAX(AmountUnitCost) OVER (PARTITION BY dt.d, ItemSKey, BusinessUnit) filtered to ItemCostSKey<>-1) × FX`. Costed lots untouched; `-1` lots borrow the item/branch carrier cost.
2. Inner filter widened `QOH>0` → `(QOH>0 OR ItemCostSKey<>-1)` so zero-qty carriers enter the window (≈1 extra row/item/branch/date, not the whole zero tail).
3. Outer `WHERE r.[_QOH] > 0` drops carriers back out before GROUP BY → rows/QOH/KGs UNCHANGED, only USD moves.
4. Lot Status only: blank-status filter widened `OR QOH=0` so carriers survive the status filter for the cost window.

**Validation — Singapore vs fresh full export `Downloads\sing inv.csv` (26,172 rows, 35 dates, correct 4/8):**
- Rows 26,172 = 26,172 EXACT. Per-date: all 35 dates tie on row count AND USD/QOH/KGs to −0.00%.
- Totals: USD 330,113,479 vs 330,113,846 (−0.011%), QOH −0.025%, KGs −0.025% — residual = Cognos per-row integer rounding only.
- The earlier "+3.3%" was against the STALE cached export (23,284 rows, 32 dates, broken 4/8); the fresh export supersedes §14.7's Cognos side.
- USD gap −31% → **within rounding. Singapore is turn-in-ready 1:1.**

**TMDL gotcha hit + fixed:** M/SQL expression lines in TMDL must ALL carry the block's leading-tab indentation; inserted space-only lines dedent out of the expression block ("Invalid indentation" on the orphaned GROUP BY). Fix: keep every SQL line tab-prefixed (collapsed the multi-line `_USD` onto its existing tabbed line; retabbed GROUP BY). `.m` masters have no such constraint.

**Open (not blocking Singapore):** Americas/Aubange/Lot Status got the same fix but were NOT validated against fresh exports here. Watch **Americas 100FGK** (`-1`, qty 5,461): carrier cost 4.68 vs Cognos as-of 4.38 ≈ +$1,600 on that lot — too large for rounding to absorb, unlike Singapore's small `-1` lots. Pull those exports before turning in the whole report. Probes P11-P17 can retire to `PROBE\retired\`.
