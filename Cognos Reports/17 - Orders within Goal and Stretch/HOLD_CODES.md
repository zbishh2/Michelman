# Hold codes and the 525→540 metric (ticket #2131554, Nathalie Vanhecke)

Nathalie's request: score the report **without the orders that carry a CX or C1 hold
code during the order process**, because hold time inflates the 525→540 interval
through no fault of Customer Service.

## Where hold codes live in ODS/JDE

Holds at Michelman are **order-header-level, current-state only**:

| Location | Content |
|---|---|
| `F4201.SHHOLD` | The active hold on an open order header. **Cleared on release.** |
| `F4211.SDHOLD` / `F42119.SDHOLD` | Line-level hold — **unused (blank everywhere)**. |
| `F42199.SLHOLD` | Ledger copy of the line hold — **blank on every ledger record**; JDE here does not stamp holds into the ledger. |
| `F42019.SHHOLD` | Purged-header copy — frozen at purge time; holds are released before close, so effectively blank (probe 5 verifies). |
| `F4209` (Held Orders file) | **Not replicated to ODS**, and in JDE its rows are deleted on release anyway. |

Decode is UDC **42/HC** (`PRODCTL.F0005`): `C1` = Credit Hold, `C2` = Credit Hold – Aging,
`CX` = Held for Cash Advance, `FM` = Order Entry Hold Code for AUBA. (`PEN`, which the
ticket also mentions, is not a 42/HC code — probe 8 identifies it.)

## What that means for the request

1. **Retroactive exclusion ("was this order ever on CX/C1 hold?") is not answerable**
   from ODS or EDW. Once JDE releases a hold the code is gone everywhere downstream;
   EDW's `FactSalesDetail.HoldOrdersCode` mirrors the current state each night (local
   mirror: 101 C1 orders in EDW vs 76 currently held in F4201 — the excess is values
   frozen at purge, not history).
2. **A current-hold flag is trivial** (`LEFT JOIN F4201` on the order header — grain-safe,
   header is unique per KCOO/DOCO/DCTO). But it touches almost nothing that is scored:
   held orders mostly have not shipped yet, so they are not in the report. Against the
   2026-07-23 cache × Aug-6 ODS mirror: C1 = 26 scored lines all-year (17 in July, 2 of
   them >48h), CX = 0.
3. The orders Nathalie is describing — FM sitting at 525, CX at 530/535, C1 at 525–540 —
   are **open** orders. The PBI report (like the Cognos original) scores a line only
   after it reaches BOTH 525 and 540, so those orders are not being counted as failures
   today; they enter the report only after they ship, at which point the hold time is
   baked into the interval and the hold code is no longer visible.
4. **A real exclusion needs hold history captured going forward** — e.g. a nightly
   snapshot of `F4201` holds (order key, hold code, date) landed in EDW by Michelman's
   EDW consultant. From the first capture day onward, "ever held CX/C1 between 525 and
   540" becomes a join.

## Where this lives now

- **Production (Orders within Goal and Stretch)**: the model fetches `Current Hold Code`
  / `Current Hold Description` (F4201 header join, MIN() aggregates on the display
  grain), and the report page carries a visible page filter **excluding C1 and CX** —
  Nathalie's requested interim behavior. The filter catches holds active at refresh
  time only; released-then-shipped orders show blank and stay in the metric (the
  snapshot above is what fixes that). Masters `Orders_GS.m` / `Orders_GS.commented.m`
  are in sync with the TMDL.
- **Orders GS - Line Explorer (DAX)**: same hold columns on `Order Lines`, a Current
  Hold Code slicer, and the code in the line grid. Line grain includes OPEN orders, so
  the held population at 525/530/535 is visible there. No exclusion filter — the
  explorer shows everything.
- `_tools\Probes\Probe-R17-Hold-Codes.ps1` — jumpbox probe set verifying the
  local-mirror findings against live ODSPROD (results → `probe_results_r17holds.txt`).
