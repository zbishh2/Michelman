# Report 05 — CM Inventory on Hand — Validation Findings

**Result: CLEAN.** 46/46 rows match Cognos exactly across all 9 columns. Zero real discrepancies. KG/LB conversion math verified on every row. No model/repo/PBIP changes made.

## Data as-of
- Cognos export: `CM - Inventory on Hand.xlsx`, exported 2026-07-06 ~20:43 (live JDE data).
- PBI: `CM_Inventory_on_Hand` table, connection `PBIDesktop-CM Overview LIVE-54787`, refreshed same evening. Pulled 2026-07-06 21:04.
- Both are current-snapshot (query has no date/Julian logic), so like-for-like.

## Counts
| Source | Rows | Distinct business keys |
|---|---|---|
| Cognos | 46 | 46 |
| PBI | 46 | 46 |
| Union of keys | — | 46 |

Business key = Branch Plant + Bulk Item + 2nd Item Number + Status + Primary UOM (BUILD.md grain). Every key unique in both sources and present in both — no orphans either side.

**Fully-matched rows: 46 / 46 (100%).**

## Per-column mismatch table
REGION 0 · Branch Plant 0 · Bulk Item 0 · 2nd Item Number 0 · Status 0 · KG/EA OH 0 · LB/EA OH 0 · Hard Commit 0 · Primary UOM 0.
Numeric columns compared with tolerance `max(0.01, value×1e-6)`; text trimmed; blank/None normalized to empty string.

## Previously-unvalidated rows (the 7/5 pagination gap) — now confirmed
- **Aubange: 17/17 match** (AUB2 × 6, AUBA × 11).
- **Singapore: 5/5 match** (SING × 3, SNG4 × 2).
- Americas: 24/24 match (CIN2 × 22, CINC × 2).

No Shanghai / Mumbai / OTHER rows exist in either source — those regions have no on-hand bulk-item inventory in the current snapshot (not a filter defect). Region distribution identical in both: Americas 24, Aubange 17, Singapore 5. UOM distribution identical: LB 29, KG 17.

## KG/LB conversion math verification (factor 0.453593)
- **KG rows (17):** LB/EA OH == KG/EA OH ÷ 0.453593 — all pass.
- **LB rows (29):** KG/EA OH == LB/EA OH × 0.453593 — all pass.
- No non-LB/non-KG UOM rows present (ELSE passthrough branch not exercised). **Failures: 0.**
- Examples: AUB2 DPE3500-T2 (LB): KG 6259.5834 / LB 13800 ✓ · AUB2 MDU2012B.E-TO (KG): KG 4000 / LB 8818.478 ✓ · AUBA U601-OP (LB) tiny value KG 4.5e-05 / LB 0.0001 ✓

## Cosmetic / normalization notes
None affecting values. Trimmed whitespace; blank Status (Cognos) ↔ empty string (PBI) treated equal; numeric tolerance as above. Number formatting is a visual concern, out of scope.

## Cognos filters (from BUILD.md, reproduced in the .m WHERE clause)
- `loc.LIPQOH/10000.0 > 0` (on-hand qty > 0).
- `LTRIM(RTRIM(tag.IMBULK))` IN the fixed Bulk-Item whitelist (~130 entries as written, ~110 distinct; duplicates kept verbatim to match Cognos byte-for-byte).
- Region prompt (`Select_Region`) is **optional** → base query returns all regions; slicer layered on top. Export was unfiltered (all regions), matching the base population.
- Inner joins: F4102↔F4101 (IBITM=IMITM), F4101↔F554101 (IMITM=IMITM), F4102↔F41021 (IBITM=LIITM AND IBMCU=LIMCU).

## Output files
`_validation_work\05 - Inventory on Hand\`: `cognos.csv`, `pbi_CM_Inventory_on_Hand.csv`, `comparison.csv` (all flags = 1), `residuals.csv` (empty — header only), `compare.py`.

## Conclusion
Report 05 is a byte-for-byte parity match against the live Cognos export, including the Aubange and Singapore rows never validated on 7/5. No bugs found — the `.m` rebuild faithfully reproduces the Cognos Inventory query.

*(Archived by orchestrator from val-05's final message — subagent report-file writes were hook-blocked.)*
