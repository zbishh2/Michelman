# Report 20 — jumpbox tight-capture checklist

One trip closes everything left. Order matters only where numbered.

## Before leaving (local)

- Copy `Inventory for Tier 2 Report\` (the PBIP folder) to the jumpbox.
  Remember the `definition.pbir` 2.0.0 check on copy-back is OBSOLETE — both machines accept 2.0.0 now.

## On the jumpbox

1. **Pick the capture date: yesterday** (relative to the trip). DW_LEGACY purges snapshot dates after
   ~10 days (report 14 §9.2) — before anything else, run the Cognos report for that date and confirm it
   returns rows.
2. **Cognos side of the tight capture:** run `Production Moves / Tim Bath / Operations Metrics Reports /
   Inventory for tier 2 report` with the BETWEEN edited to that single date. **Export to Excel** (not
   screenshots — the viewer paginates at 20 rows). Note the run clock time.
3. **PBI side, minutes later:** open the PBIP in Desktop, **refresh** (first refresh, 5.1M rows —
   note the duration; if it crawls, the §9a V36 suspects are the `[K_KG_TO_LB]` reference in the calc
   column, and a trailing-window date bound is a one-clause fallback). Note the clock time.
4. After refresh, **drag the date slicer to the capture date** — the stored landing state is the stale
   literal `2026-08-04` (V36 item 4).
5. Sanity while you're there: table shows ~1,250–2,400 rows for one date, H2O rows present, grand
   total order-of-magnitude 10⁸ lbs *excluding* H2O rows / 10¹¹ with them.

## Bring back

- The Cognos export (file into `Intake\` as `Cognos export - tight capture <date>.xlsx`).
- The refreshed PBIP copy (or just its cache) so I can pull the PBI side via mount + DAX→CSV locally.
- First-refresh duration (one number).

## Also outstanding (not jumpbox)

- The **two Cognos Viewer screenshots from the 2026-08-06 chat** — still unfiled; P6 (date format,
  decimals, header labels) can't close without them. Paste them back in chat or drop the files in
  `Intake\`.
- **Confirm Tim Bath owns this report** before the §11.1 questions go to anyone. Of those questions,
  Q3 (H2O) is already closed by data; Q1 ("tier 2" meaning), Q2 (lot-status carve-out), Q4 (date
  format) remain.

## Rider — report 21 (optional, same trip)

21 is holding the #22(a) `Unit_Weight_Adj` fix pending a refresh. Report 19 has since proven that
exact rule on three captures (−0.0021% totals). If there's time, apply + refresh 21 on the same trip.
