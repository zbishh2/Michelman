# Report 21 — Slow Moving Global Packaged Items

## Purpose

The report supplies three independent lists used to identify slow-moving packaged inventory:

- `Inventory`: packaged inventory positions with positive on-hand quantity.
- `Shipments`: qualifying shipment lines in the rolling 365-day window.
- `Items - Active`: active packaged item-branches.

The report preserves the Cognos column order. The lists have no model relationships because their
comparison and combination occur outside the report at different business grains.

## Cognos definition

- Report: `1 - Inventory - Slow Moving Global Packaged Items`
- Path: `Michelman Reporting / Production and Shipping / Cogan Excel AD HOC Reports`
- Package: `Data Warehouse`
- Definition evidence: the native-SQL and report-XML capture in `Intake`.
- Render evidence: the three-sheet Cognos workbook in `Intake`.

## Power BI implementation

- Project: `Slow Moving Packaged Items/Slow Moving Packaged Items.pbip`
- Storage mode: Import
- Private validation workspace: `Zack (Validation)`
- Private semantic model ID: `0023e5f9-94b1-4582-af3a-157963dc3371`
- Private report ID: `250a7c01-f5b1-41cf-a395-e348157cc71b`
- Team validation workspace: `Michelman - Validation (Inventory)`

Both fact queries anchor on `TODAY()`, evaluated on the server at refresh time — the same
convention as Cognos `sysdate`. Inventory selects the latest snapshot strictly before the
refresh date; Shipments covers the 365 days before it. Every refresh advances the report
automatically. Validation therefore pairs a refresh with a same-day Cognos export.

## Source routing

The report follows the source ladder at field level:

- Inventory: `SSASPROD / BIQLTabular_ISH` Import.
- Shipments: `SSASPROD / BIQLTabular` Import.
- Items Active: `SSASPROD / BIQLTabular` Import.
- EDW and ODS: no dependency.

Inventory uses the purpose-built history model because the general model does not expose the
required complete historical snapshot. Shipments and Items Active use the production general
model and its validated surrogate-key relationships.

## Inventory query

The native DAX query:

1. Selects the maximum `Inventory Snapshot[Calendar Date]` earlier than `ReportAsOfDate`.
2. Filters standard cost method `07` — the model carries each position once per cost method,
   and `07` is the single reporting cost row (the report 20 rule).
3. Filters positive primary-UOM quantity, fact GL class `IN32`, and the seven report branches.
4. Projects the related Item Branch, Branch, and Lot attributes with `RELATED`, trimming every
   displayed business key.
5. Imports at native fact grain — under cost method `07` one row is one position, so the query
   performs no grouping or reshaping.

The actual selected snapshot date is imported as hidden `Inventory Date`. Displayed `DATE` is the
report as-of date.

### Inventory weights

`Quantity on Hand KGs` and `Quantity on Hand LBs` are the ISH model's own `[Qty On Hand KG]` and
`[Qty On Hand LB]` measures evaluated per position row with `CALCULATE`. The report defines no
conversion logic of its own; the team-validated model supplies both weights.

## Shipments query

The native DAX query filters:

- Record Type = `Sales Detail`
- primary-UOM ordered quantity > 0
- transaction quantity net of cancellation > 0
- Promised Shipment Date >= `ReportAsOfDate - 365`
- Line Type = `S`
- Order Type <> `ST`
- branches `CINC`, `CIN2`, `AUBA`, `AUB2`, `SING`, `SNG4`
- related Item Branch GL class = `IN32`
- effective item not in `IGST`, `CGST`, `SGST`, `CVD`, `ADD`

The output remains at source-line grain. `Line Number` keeps the full decimal sub-line value; the
query does not truncate, group, or sum separate source lines. The stable business key is Order
Company, Order Number, and Line Number.

Every projected value is a stored model column — the report derives nothing. `Ordered Quantity
LBs` / `KGs` are the model's `QuantityOrderedLB` / `KG` columns. The `Qty Ordered Primary UOM
LB` / `KG` pair is not used: it double-converts `TO`-UOM lines (primary-LB quantity × tote
weight). `Open Indicator` is the model's `Open Order Flag`, displayed and never filtered. Hidden diagnostics: `Primary Unit of
Measure` (validation binning) and `Cancelled Flag` — when a refresh proves `Cancelled_Flag = 0`
equivalent to the quantity-net predicate, that predicate becomes a filter on the stored column.

## Items Active query

The native DAX query selects distinct trimmed values from Item Branch where:

- Category GL F4101 = `IN32`
- Stocking Type <> `O`
- branch is one of `CINC`, `CIN2`, `CIN4`, `AUBA`, `AUB2`, `SING`, `SNG4`

The stable business key is Branch Plant and 2nd Item Number.

## Known source differences

- Cognos truncates shipment sub-line labels to five characters. Power BI retains the full source
  line number so distinct sub-lines cannot merge.
- Cognos can show `-` for warehouse bulk attributes where production SSAS retains a derived item value.
- EA-primary weights come from production SSAS stored line or position weights and can differ from
  Cognos warehouse conversions.
- Lot dates can differ because production SSAS and the Cognos warehouse update on different
  source schedules.

## Validation

The `PROBE` directory contains the DAX used against the mounted cache and the private hosted model:

- `cache_validation_summary.dax`
- `cache_validation_legacy_collisions.dax`
- `cache_validation_line_numbers.dax`
- `cache_validation_inventory_sample.dax`
- `hosted_export_inventory.dax`
- `hosted_export_shipments.dax`
- `hosted_export_items_active.dax`

The report PBIR validator returns zero errors and zero warnings. The private semantic model refreshes
through the existing SSAS gateway data sources, and Power BI `executeQueries` validates its row
grain, snapshot selection, conversion outputs, and normalized item keys.
