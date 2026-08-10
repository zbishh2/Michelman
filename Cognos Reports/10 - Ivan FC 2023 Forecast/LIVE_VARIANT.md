# LIVE variant — validation notes (built 2026-07-13)

`PBIP (SSAS Live)\` = thin report, **Live Connection** to `SSASPROD` / `BIQLTabular_v2`.
No semantic model, no refresh, no queries — the team's perspectives own all logic.
Built blind; NOT yet opened in Desktop. First open may prompt to fix the connection —
if it errors, connect via Get Data > Analysis Services > SSASPROD > BIQLTabular_v2 (live).

## What to validate, in order
1. **Report opens + connection resolves** (needs read access on the SSAS model).
2. **Forecast page ties to the import variants** (same model data, so any diff = my
   field mapping or a filter port, not the source).
3. **Sales History vs the accepted ODS version** — this page has KNOWN approximations (below).

## Field mapping — Forecast page
FactForecast: Company, BusinessUnit, Global Bulk, Bulk Item, ItemNum2nd, RequestedDate,
AddressNum(=Customer Code), SUM QuantityForecast/KG/LB, UOM Primary.
Calendar (via Date bridge, bothDirections): Year Num, Calendar Month Num, Week Num.
Address: Address Name, Global Parent, Global Parent Desc. Territory Manager: Mailing Name.
Page filters: ForecastType='SA', Company not 00024/00025, branch list, QuantityForecast>0.

## Field mapping — Sales History page
Sales: Order Company, BusinessUnit, Item Num 2nd, Order Num, Status Code Next,
Promised Shipment Date (+ its -Year/-Month cols), SUM QuantityOrdered/KG/LB, UOM,
Open Order Flag. Item Branch: Item Num Global Bulk / Item Num Bulk.
Customer (sold-to): Customer Sold To Num/Name, Global Parent Num/Name, Country Desc.
Revenue Business Unit: RBU (a REAL RBU at last). Territory Manager: Mailing Name.

## KNOWN approximations / deliberate omissions (check these against Cognos)
- **Forecast page: `Revenue Business Unit` DROPPED** (was a duplicate of Branch Plant —
  open decision D6; the model has no RBU key on forecast rows).
- **Sales History: `Week` column DROPPED** — the model has Promised-Ship Year/Month but
  no Week, and Calendar joins Sales on GL Date (wrong grain). Ask Jim for a
  `Promised Ship Date - Week` column if the business wants it back.
- **Sales History: `DATE` column DROPPED** and both `Last Refreshed` cards deleted —
  meaningless/impossible on live (data is always current).
- **Sales History filters NOT ported** (no model equivalent found):
  `SDLNTY NOT LIKE '%F%'` (line-type), `SDCNDJ = 0` (not-canceled),
  the GST exclusion's `'-' -> SDLITM` fallback, and the dynamic ceiling
  `EOMONTH(today+180)`. Floor date IS ported as a page filter. Expect the live page
  to show MORE rows than ODS until these are reconciled — compare and decide which
  matter; candidates exist in the model (`Filter - Active Order Types`, `Order Exclude`).
- **`Item Num Bulk` / `Item Num Global Bulk`** were chosen over the `Item Bulk` /
  `Item Global Bulk` twins — if the bulk columns render wrong, swap to the others.
- **TM Name = `Mailing Name`** (same choice as the import variants; alt `Territory Manager`).
- Unknown: whether the model's `Sales` keeps purged JDE lines (the F42119 issue).
  If old orders are missing vs ODS, that's the cause — ask Nick.

## Service notes (when it ships)
Gateway needs an **Analysis Services** data source for SSASPROD (EffectiveUserName);
viewers need read on the SSAS model. No refresh schedule needed — that's the point.

Sales History floor date (ported): **2025-11-01**.

## Round-1 findings from Zack's 2026-07-13 data.csv export (and fixes applied)
- VALIDATED GOOD: KG/LB math exact, Customer Code/Name + Global Parent joins right,
  Calendar Year/Month/Week correct, Company Code clean, connection + page filters live.
- FIXED: item slicer preset now uses the slicer's real selection slot
  (objects.general.filter) - the filterConfig approach rendered as "All".
- FIXED: `Branch Plant` display swapped to 'Business Unit'[Business Unit] (dim) -
  the fact column renders raw right-justified 12-char JDE MCU ('        CIN2').
- FIXED: branch page filter now lists padded AND unpadded literals.
- OPEN (data-side, ask Nick/Jim): **TM Name blank on ~93% of forecast rows** -
  the TerritoryManagerSKey join works (7% get real names) but the key is
  unpopulated on most FactForecast_v2 rows. Not a report bug.
- NOTE: Desktop had the report open during these disk fixes - close WITHOUT saving,
  then reopen the .pbip to pick them up.
