# Forecast page — PROFILE ONLY (UNVALIDATED)

**Cannot be validated.** The Cognos export sheet `Forecast_1` is EMPTY (range A1:A1,
zero rows) — confirmed. There is no source-of-truth to tie against. The BUILD.md flags
every uncertain F3460 field with `-- TODO verify`. Numbers below are the PBI rebuild's
own output, profiled for sanity only. Do NOT treat as correct until a human with JDE
access confirms the F3460 field names + quantity scaling (BUILD risk #1).

## Counts / ranges (live model, refreshed 2026-07-06 ~20:54)
- Rows: **124**
- Requested Date range: **2026-07-04 → 2026-07-25** (four weekly buckets, exactly 31 rows
  and 49,685.75 KG in EACH of 7/4, 7/11, 7/18, 7/25 — the same 31 item/customer forecast
  lines repeated per week). Deployed `.m` window = `DATEADD(DAY,1,EOMONTH(GETDATE(),-1))`
  … `EOMONTH(GETDATE())` = **July 2026 only** (dynamic month; note this differs from
  BUILD.md's stale "ceiling literal 2026-06-30" text — the deployed query is the dynamic
  version).
- Distinct 2nd Item Numbers: 9 · Distinct Bulk Items: 6 (211018IX.S, ME91240G.S,
  ME91735.S, ME92040.S, MG7140.S, PP05S.S) · Distinct Customers: 20 · Branches: 2
  (SNG4, MUM3) · Primary UOM: **all KG**.
- Current Forecast: sum **198,743** (= sum KG, since all rows KG) · min **1** · max **9,891.75**.
- TM Name: **1 distinct value = "Not Available"** for all 124 rows (the GTM-rep populated
  path is never exercised here).

## Anomalies / risks to flag
1. **Deployed field names are `MF*`, not `FT*`.** The live `.m` reads `ft.MFDRQJ`,
   `ft.MFFQT`, `ft.MFTYPF` (table aliased `ft` but columns prefixed `MF`) — BUILD.md's
   column table says `FT*`. Still `-- TODO verify` on all of them.
2. **Tiny forecast quantities** (1, 1.75, 3, 21.5 KG) sit next to large ones (9,891.75).
   Could be genuine, but this is exactly the symptom BUILD risk #1 warns about re: the
   `MFFQT / 10000.0` scaling guess. Unverifiable against an empty export.
3. Repeating 31-row block across 4 weekly dates is consistent with F3460 weekly demand
   buckets — plausible, not confirmed.

## Verdict
**UNVALIDATED.** Structure, columns, and types render; the page is internally coherent
but there is no external reference. Requires a JDE/F3460 human check before trust.

(A 100-row sample of the 124 rows is saved as `pbi_Forecast.csv`; the tool capped the
CSV export at 100 rows. All 124 were profiled via DAX aggregation.)
