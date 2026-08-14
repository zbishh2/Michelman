# SSAS Pull

A data mule, not a report. Imports a working subset of `SSASPROD` / `BIQLTabular` into
`cache.abf` so the data can be mounted and queried locally (uncapped DAX, no jumpbox) via
`mount-pbip-cache.ps1`. It replaces the server-side `.abf` backup we cannot retrieve: same
end state, ordinary user query access only.

## Workflow

1. Copy this folder to the jumpbox.
2. Open `SSAS Pull.pbip` in Power BI Desktop, Refresh, Save, close Desktop.
3. Copy the folder back to this machine.
4. `mount-pbip-cache.ps1` on `SSAS Pull.SemanticModel` → query at `localhost:<port>`.

## Scope

| Table | Source | Rows |
|---|---|---|
| FactForecast | all columns | all |
| Sales | 94 columns | Order, Promised Ship, or GL date within 1095 days |
| Purchase Order Detail | 80 columns | Order, GL, or Received date within 1095 days |
| Purchase Order Receiver | 54 columns | Received or GL date within 1095 days |
| Item Branch | 40 columns | all |
| Item | 58 columns | all |
| Customer | 25 columns | all |
| Customer Ship To | 20 columns | all |
| Territory Manager | all columns | all |
| Address | 14 columns | all |
| Business Unit | 17 columns | all |
| Branch | 9 columns | all |
| Company | all columns | all |
| Date | all columns | all |
| Calendar | 23 columns | Calendar Date 2019–2030 |
| Last Refreshed | refresh timestamp | 1 |

Deliberately excluded (size outweighs use): GL Balances Detail, Inventory Balances,
Inventory Detail, Inventory Snapshot, the Work Order family, Supply and Demand, AP/AR,
Quality. Inventory-history questions go to `BIQLTabular_ISH`, not this model.

No relationships and no measures by design: every table is an independent snapshot; joins
happen in the DAX you run against the mount (SKeys are imported for that purpose). The
KG/LB/EUR conversion factors are imported raw so converted quantities are a multiplication
away.

Column names mirror the SSAS model exactly, validated against `edw_schema\ssasprod.bim`.
The `Sales` KG/LB/PY measure families are model measures over these same base columns —
recompute locally as needed.

The data is frozen at the last jumpbox refresh; freshness and performance questions still
go to SSASPROD itself.

## Adding tables

`gen_pull.py` generates every table TMDL from the `SPECS` list, validating each column
against `edw_schema\ssasprod.bim`. To widen the pull: add a spec entry (or columns to an
existing one), run the script, re-refresh on the jumpbox. It rewrites only the tables and
`model.tmdl`, never the Report side. The scope table above must be kept in step.
