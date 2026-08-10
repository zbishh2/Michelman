# Cognos source collection — Report 20

- **Report name:** Inventory for tier 2 report
- **Cognos path:** `Production Moves / Tim Bath / Operations Metrics Reports`
- **Portal folder ID:** `i593C0D3C30104FC68E5C9E1798BDF446`
- **Cognos package:** `/content/package[@name='Data Warehouse']/model[@name='model']` — DW_LEGACY,
  same legacy warehouse as reports 13/14/18/19. Star used: **Inventory On Hand**.
- **Run output format:** none (`run.outputFormat=` empty → HTML in Cognos Viewer). `run.prompt=true`
  but the report XML has **no prompt pages and no parameters** — inert, same as report 19.
- **Assigned to Zack 2026-08-06.** Folder scaffolded same day.

⚠ First report we've taken out of the **`Production Moves`** tree — every prior one came from
`Michelman Reporting`. Requirements contact is presumably **Tim Bath**; confirm.

## Collected so far

| File | What it is |
|---|---|
| `Intake\Query + XML (filed 2026-08-06).txt` | Cognos-generated SQL + full report XML |
| _(pending)_ | Two Cognos Viewer screenshots (pages 1 and 2 of the list) were supplied in chat 2026-08-06 — **save them into `Intake\` before this note is trusted as complete** |

---

## Report anatomy

**The simplest report in the program so far.** One page, one query, one flat `<list>`, seven columns,
no grouping, no summaries, no styling beyond the default `lt`/`lc`/`lm` classes, no prompts.

Grain = **Branch Plant × 2nd Item Number × Bulk Item × Global Bulk Item × Master Planning Family ×
Inventory Date**, with quantity summed across lot and location.

| Column | Source expression |
|---|---|
| Branch Plant | `ITEM.BRANCH_PLANT` |
| 2nd Item Number | `INVENTORY_ON_HAND_MEASURES.ITEM_NUMBER_2ND` |
| Bulk Item | `ITEM.BULK_ITEM` |
| Global Bulk Item | `ITEM.GLOBAL_BULK_ITEM` |
| Master Planning Family | `INVENTORY_ON_HAND.MASTER_PLANNING_FAMILY` — **off the fact, not the item** |
| Quantity on Hand LBs | `SUM(QUANTITY_ON_HAND * CONVERSION_FACTOR_LB)` |
| Inventory Date | `INVENTORY_ON_HAND.INVENTORY_DATE` |

Filters — there are only two:

```
INVENTORY_DATE between TIMESTAMP '2020-01-01 00:00:00' and TIMESTAMP '2020-12-31 00:00:00'
BRANCH_PLANT in ('CINC','CIN2')
```

---

## The two things that decide this report

### 1. The date range is user-driven — **the literal 2020 dates are disposable**

The generated SQL carries `INVENTORY_DATE between '2020-01-01' and '2020-12-31'`, and the supplied
screenshots are all 2020 rows. **This is not a design choice.** Resolved with Zack 2026-08-06:
users were **editing the date range by hand at run time** in Cognos, so 2020 is simply what was in
the definition when this copy was captured. There was never a 2020 baseline requirement.

⇒ **A date picker is the faithful port**, not an improvement on the original. The real requirement
has always been a user-selectable range; Cognos just implemented it manually. Do not port the two
literals as defaults.

Superseded reading, kept so nobody re-runs this: this initially looked like the hardcoded-bound
pattern of forecast reports 08/10 (§7), which would have made the report a frozen extract. It isn't.

⚠ One factual consequence survives — **EDW holds no 2020 inventory data**, measured locally
2026-08-06 against the SQL mirror:

| Table | Rows | Date span | Rows in 2020 |
|---|---|---|---|
| `BIQL.FactInventorySnapshot_History_Filtered` | 13,349,051 | `CalendarDate` 2021-06-30 → 2026-08-05 | **0** |
| `dbo.FactInventorySnapshot_History` (effective-dated) | 2,029,747 | `StartDate` 2021-06-02 → 2026-08-05 | **0** (no span intersects 2020) |

ODS `PRODDTA.F41021` is current-only and cannot reconstruct history (established on report 14).
So **2021-06-30 is a hard floor** on the picker: a user who selects earlier gets an empty report
with no explanation unless the slicer is bounded or the floor is surfaced on the page.

### 2. "Tier 2" appears nowhere in the query

There is no tier column, no tier filter, no tier grouping. Either "tier 2" means *the CINC/CIN2
branch-plant pair*, or it is a concept applied downstream in Excel by whoever receives this. Ask.
Do not invent a tier dimension.

---

## Other notes and traps

- **⚠ CORRECTED 2026-08-06 — `'-'` is Cognos rendering a NULL, not a stored sentinel.** The
  screenshot row `CINC | H1 | - | H1 | REC` shows Bulk Item as `-`, and this note originally read
  that as a real value. Measured: `BIQL.TbItemBranch` has **0** rows with `'-'` in `[Item Bulk]` or
  `[Item Global Bulk]`, **0** empty strings, and **385** / **17** NULLs. `-` is Cognos's default
  missing-value character. See `BUILD.md` §6.1 / V16 — **store NULL, render `-`, in DAX not SQL.**
- **MPF comes off the fact**, not the item dimension, so it is *snapshotted* — an item whose
  planning family changed since 2020 shows its 2020 family here. Any port that joins MPF from a
  current item-branch dimension will produce different values. This is the most likely source of a
  silent mismatch. The visible domain in the screenshots is `FCB FEC RRC FRC TOL RCB FBW RBW REC` —
  note there is **no `like '%F%'` filter** here, unlike report 19.
- **No lot-status filter.** Held, quarantined and rejected lots are all included in the quantity.
  Confirm that is intended before adding any status carve-out.
- `BETWEEN ... '2020-12-31 00:00:00'` is a **timestamp**, so any 12/31 row with a non-midnight time
  is excluded. If `INVENTORY_DATE` is date-only this is moot; if it carries a time component the
  last day is effectively half-excluded. Check the column's actual type.
- The `ITEM ⋈ INVENTORY_ON_HAND_MEASURES` join is on `ITEM_SID` and is an **inner join** — snapshot
  rows whose item doesn't resolve are dropped. Same class of trap as report 19, though with one
  join instead of five it is much lower risk.
- Cognos list panels **paginate at 20 rows** (§7) — the two screenshots are pages 1 and 2, not the
  whole result. Row count is unknown; a full export is still needed.

---

## Source routing — SSAS → EDW → ODS

Per §1, new report ⇒ prefer SSAS live where one perspective covers it, else EDW, else ODS.

**SSAS** — the `Inventory Snapshot` perspective exists and carries `Item Branch` +
`Item Branch Additional Information`; `Supply and Demand` carries an `Inventory Snapshot` table
alongside `Item Branch` and `Lot`. On the face of it this report — one fact, one dimension, one
measure — is the **best SSAS-live candidate of the three new reports**: no Power Query at all, and
the LB conversion may already exist as a model measure. Worth checking properly.
⚠ Same caveat as report 19: read off the local `ssasprod.bim`, which is a dump of the **stale**
`BIQLTabular`, not `BIQLTabular_v2`. Re-confirm on v2.

**EDW** — `BIQL.FactInventorySnapshot_History_Filtered` (the lineage report 14 and report 18 both
landed on) plus `BIQL.TbItemBranch` for bulk / global bulk. `dbo.FactInventorySnapshot_History` is
the unfiltered twin if the filtered view's window is too narrow. Both, plus `TbItemBranch`, are
**already in the local `EDW-ODS Snapshot`**, so column existence, the 2020 retention question, the
`'-'` sentinel and the MPF-on-fact question are all answerable on this machine (§9).

**ODS** — `PRODDTA.F41021` (item location balances) is current-only and **cannot reproduce 2020
history**, exactly as established for report 14. Not a route.

**Recommendation:** EDW, unless the v2 check shows the Inventory Snapshot perspective covers all
seven columns and the LB conversion — in which case SSAS live is both mandated and genuinely nicer
here.

---

## Open questions for Tim Bath

1. What does "tier 2" mean — the CINC/CIN2 pair, or something applied after the export?
2. Is the HTML-in-Viewer output the delivered form, or does everyone export it?
3. Should held/quarantined lots be excluded from Quantity on Hand?

_Resolved 2026-08-06: the 2020 date range was a run-time edit, not a requirement — the report gets
a date picker. See §1._
