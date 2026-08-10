# Cube change request — add `Region (Inventory)` column to `Branch`

**For:** Jim (cube owner)
**Requested by:** Report 14 — "1 - Ivan Global Inventory Excel - Select Date (ISH Live)"

The ISH-live rebuild of Report 14 groups and filters its Summary matrix and Inventory
Data table on a 5-bucket region. That grouping does not exist in the cube today
(`Branch[Region]` holds JDE region codes, not these 5 buckets). Please add a real
column so the report's per-Region subtotals and Region filter work on a live connection
(report-only mode cannot add calculated columns itself).

## Target

| Field | Value |
|---|---|
| Model (prod) | `BIQLTabular_ISH` |
| Dev workspace | `WorkspaceDB_ISH_JimE` |
| Table | `Branch` |
| New column name | `Region (Inventory)` |
| dataType | `string` |
| Visibility | **Visible** (not hidden) |

> ⚠️ **The column name must match byte-for-byte: `Region (Inventory)`** — including the
> space before the parenthesis and the exact casing. The report binds to
> `'Branch'[Region (Inventory)]` in the matrix Rows, the table columns, the sort, and the
> filter card. Any deviation (extra space, different case, hidden flag) breaks the report.

## Mapping (9 Branch Plants → 5 regions)

| `Branch`[Branch Plant] | `Region (Inventory)` |
|---|---|
| CINC | Americas |
| CIN2 | Americas |
| CIN4 | Americas |
| AUBA | Aubange |
| AUB2 | Aubange |
| SING | Singapore |
| SNG4 | Singapore |
| MUM3 | India |
| SHAN | China |

Any other Branch Plant is out of report scope; map it to a blank/`"ERROR"` sentinel as you
prefer — the report already page-filters `Branch[Branch Plant]` to exactly these 9, so
unmapped plants never render.

## Suggested expression

DAX calculated column on `Branch` (mirrors the report's derived logic):

```DAX
Region (Inventory) =
SWITCH(
    TRUE(),
    'Branch'[Branch Plant] IN { "CINC", "CIN2", "CIN4" }, "Americas",
    'Branch'[Branch Plant] IN { "AUBA", "AUB2" }, "Aubange",
    'Branch'[Branch Plant] IN { "SING", "SNG4" }, "Singapore",
    'Branch'[Branch Plant] = "MUM3", "India",
    'Branch'[Branch Plant] = "SHAN", "China",
    "ERROR"
)
```

Equivalent source/SQL lookup (`CASE` on the branch/business-unit code) is fine if you
prefer to land it in the Branch dimension load — the report only cares that the final
column exists with the exact name, is string-typed, and is visible.
