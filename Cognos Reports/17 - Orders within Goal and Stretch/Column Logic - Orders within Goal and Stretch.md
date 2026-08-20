# Orders within Goal and Stretch — Column Logic

Power BI rebuild of the Cognos report *Orders within Goal and Stretch* (Customer Service). Source: JDE via ODS (`ODSPROD`, schema `PRODDTA`). The rebuild reproduces the deployed Cognos report's logic, including its labeling conventions, so the two tie 1:1.

## What each row is

One row per **sales-order line that has both pick-confirmed (status 525) and shipped (status 540)**, for orders whose *order entry date* falls in the selected date window. Lines that never reached both statuses do not appear. The report measures the elapsed **business days between the first 525 event and the first 540 event** on the line, and flags each line against the Goal/Stretch service targets.

Order lines are read from `F4211` (open) plus `F42119` (purged history) so completed lines remain visible after JDE's nightly purge. Status events come from the sales-order ledger `F42199`; the event timestamp is rebuilt from the ledger's Julian date + time (`SLUPMJ` + `SLTDAY`), and the **earliest** qualifying event per line is used.

## Row eligibility (matches the Cognos filters)

- Order types `S5` and `ST` excluded.
- Cancelled lines excluded (last or next status 980) — including lines cancelled after completion.
- Companies 00024 / 00025 excluded.
- Intercompany ship-tos excluded (address book category `AC01 = 'INT'`).
- GST/duty tax items excluded (`IGST`, `CGST`, `SGST`, `CVD`, `ADD`, matched on the global bulk item where one exists, else the item number).
- Date window applies to the JDE **order entry date** (`SDTRDJ`), not to the displayed date columns.

## Columns

| Column | Logic |
|---|---|
| Company Code / Company Name | Derived from the order's branch plant via `F0006` (branch → company), name from `F0010`. |
| Branch Plant | Order line branch (`SDMCU`). |
| Freight Handling Code | `SDFRTH`, as stored. |
| Order Number | `SDDOCO`, kept as text (the report sorts it alphabetically, matching Cognos). |
| **Ordered Quantity** | Order quantity converted to the item's **primary unit of measure**: `(SDUORG ÷ 10,000) × conversion factor`. The factor converts the line's transaction UOM to the item's primary UOM (`F41002` item-specific conversion, `UMCONV ÷ 10⁷`); factor = 1 when the line is already in the primary UOM. Where identical display rows repeat, Cognos groups them and sums quantity — the rebuild does the same. |
| 2nd Item Number | `SDLITM`, trimmed. |
| Sold To Customer Code / Name | Sold-to address number (`SDAN8`) and `F0101` name. |
| **Ship To Customer Code / Name** | **Displays the SOLD-TO code/name** — the Cognos report reuses the sold-to for both column pairs, and the rebuild preserves that. The true ship-to is still used behind the scenes for the intercompany filter and segmentation. |
| Customer Segmentation / Description | True ship-to's address book category `AC06`; description decoded from user-defined codes (UDC 01/06). |
| **Order Date** | **The first 525 (pick-confirm) event date/time.** This is a Cognos label convention: the column named "Order Date" on the deployed report shows the confirmation event, not the order entry date. Preserved for 1:1 parity. |
| **Confirmation Date** | **The first 540 (ship) event date/time.** Same label convention — the column named "Confirmation Date" shows the ship event. |
| Shipped Date | Actual ship date from the order line (`SDADDJ`), date only. |
| Requested Date | Customer requested date (`SDDRQJ`). |
| **Goal** | 1 when the line met its regional service target, measured in business days between first 525 and first 540: **Americas (RAME) ≤ 1 business day; Europe (REUR) and Asia (RASI) ≤ 2 business days.** Region comes from the order's company. |
| **Stretch** | 1 when the interval is ≤ 1 business day (the stretch target, applied globally). |
| **>48h** | 1 when the interval is **more than 2 business days**. |
| **<72h** | 1 when the interval is **less than 3 business days**. |
| **>72h** | 1 when the interval is **more than 3 business days**. |
| **Ever Held C1/CX** | Y when the order was ever placed on a **C1 (Credit Hold)** or **CX (Held for Cash Advance)** hold, at any point in its life. Read from `F4209`, JDE's held-orders file, which records a release date on the row instead of deleting it — so it carries the full hold history, not just orders held right now. Header-level, so it applies to every line on the order. |
| Total row / Total Order Lines | The footer sums each flag column; the card counts the rows. |

## Where the logic lives

The model is split so the calculation logic is directly readable in Power BI. The SQL query only *fetches* raw facts from JDE (order lines, the two ledger event timestamps, quantities, names). Everything the report *computes* — the Business Days interval and all five flag columns — is defined as DAX calculated columns on the table, visible in the field list with a description on each. Opening the model and clicking any flag column shows its complete logic in a few lines, e.g. Stretch is literally `IF ( Orders_GS[Business Days] <= 1, 1, 0 )`.

## The business-day calculation

Calendar days between the 525 date and the 540 date, minus the weekends in between, using the same week-anchored formula as the Cognos original. Notable inherited behavior: intervals that start or end on a weekend are handled by the formula's weekend-endpoint rules exactly as Cognos computes them (a same-weekend pair can count as 0). The hour-styled column names (>48h, <72h, >72h) are thresholds expressed in business days (2 and 3), not literal clock hours — again matching the deployed report.

## Excluding held orders

Hold time inflates the 525→540 interval through no fault of Customer Service, so the
**No On-Hold** copy of the report carries a page filter that drops every line whose order
was ever on a C1 or CX hold (`Ever Held C1/CX` = Y). The standard copy keeps them and
leaves the filter open.

The exclusion is deliberately "ever held", not "held while the clock was running": an
order that went on credit hold *after* it shipped is excluded too. Roughly 22% of scored
lines carry a C1/CX hold somewhere in their history, and about half of those were held
during the measured window.

## Filters

The Cognos prompts are replaced by page slicers — no parameters to edit before refreshing:

- **Order Date Range** — Between slicer on the true JDE order entry date (the report imports a rolling 12 months; pick any window inside it).
- **CSR** — dropdown (customer service rep assigned to the ship-to customer, from `F42140`, mailing name from the address book).
- **Company / Customer / Bulk Item** — dropdowns, as before.

The Cognos **Business Group** prompt is not carried over: it drew its values from the legacy data warehouse's organization hierarchy, which has no populated counterpart in JDE/ODS (the branch category it would map to is empty there). It can be added back as a simple mapping if the business supplies the group-per-company/branch list.

## Known differences vs. the live Cognos numbers

Small residual differences vs. a same-day Cognos run are expected and documented in the validation workbook: (1) the legacy data warehouse behind Cognos loads nightly, so orders confirmed today appear in Power BI first; (2) on a small number of lines (~3–4%) the legacy warehouse picks a different 525/540 event from its nightly history than the live ledger holds, shifting a flag by one business day in either direction; (3) a handful of unit-conversion rows differ where the legacy warehouse's conversion table disagrees with live JDE (details and row counts in the validation workbook notes).
