# Forecast page — PBI table profile (UNVALIDATED)

**Cannot be validated against Cognos.** The export sheet `Forecast_1` contains only the
single cell `A1 = "No Data Available"` — the known Cognos date-window issue. There is no
source-of-truth data to tie to. Everything below is a *profile of the PBI rebuild only*
(`Forecast` table, F3460 best-effort rebuild with `-- TODO verify` field maps). Treat all
Forecast numbers as unconfirmed until a human opens F3460 in JDE.

## Row / measure profile (live model, refreshed 2026-07-06 20:50)
| Metric | Value |
|---|---|
| Rows | **768** |
| Sum Current Forecast | 1,046,527 |
| Sum Current Forecast KG | 764,743.82 |
| Sum Current Forecast LB | 1,685,958.37 |
| Requested Date range | **2026-07-04 → 2026-07-25** (21-day window) |
| Distinct 2nd Item Number | 82 |
| Distinct Branch Plant | 5 |
| Distinct Customer Code | 155 |
| Rows with Current Forecast = 0 | **0** (no all-zero-measure anomaly) |

## Branch-plant distribution
| Branch | Rows | Sum Current Forecast |
|---|---|---|
| CIN2 | 436 | 446,898 |
| AUBA | 196 | 138,552 |
| MUM3 | 84 | 390,825 |
| SNG4 | 36 | 1,448 |
| CINC | 16 | 68,804 |

Only 5 of the 9 branch plants in SK's positive include list appear
(`AUBA, AUB2, SING, SNG4, MUM3, SHAN, CINC, CIN2, CIN4`). **AUB2, SING, SHAN, CIN4 have zero
forecast rows** — expected if those plants have no F3460 rows in the window, but unverifiable.
The filter *does* correctly include CINC/CIN2 (the SK-specific difference vs report 10/FC).

## Sample rows (first 6, Requested Date asc)
All `DP040-B1` at CIN2, S-One Labels customers, Requested Date 2026-07-04, Current Forecast
44 LB → KG 19.958092 (= 44 × 0.453593), LB = 44. Primary UOM `LB`. TM Name = `Not Available`.

## Observations / caveats
- **No all-zero-measure anomaly** — forecast quantities populate, KG/LB conversions apply.
- **KG uses the same LB→KG factor 0.453593** as Sales History — which the Sales History
  validation shows is *slightly* off vs Cognos (should be 1/2.2045992 = 0.45359719). If the
  Forecast page is ever tied to a non-empty Cognos export, expect the same 5th-decimal KG drift.
- **TM Name resolves to `Not Available`** on the sampled rows (default GTM path), same as most
  Sales History rows — the populated path is unexercised here.
- Highest-risk unverified fields per BUILD.md remain unverified: `FTFQT` (qty field + /10000
  scaling), `FTDRQJ` (requested date), `FTAN8` (customer), Company Code (`F0006.MCCO`), and the
  Revenue Business Unit placeholder (`FTMCU`). None can be confirmed without JDE access.

**Verdict: UNVALIDATED.** Profile looks internally coherent (non-empty, non-zero, plausible
items/customers/branches), but correctness of the F3460 field mapping is untested.
