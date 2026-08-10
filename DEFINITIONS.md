# Business definitions — what the numbers ARE. Read on demand, not preloaded.

## OTIF
- Promised-date-change reason code is `RFRV` (`SLRFRV` in F42199, `SDRFRV` in F4211), decoded by UDC `42/RR`.
- Reason dimension is D1-backed (`reason_dim`); `[OTIF]="X"` iff the editable `otif` flag is set.
- Production's on-time = reason codes Reliability + Flexibility, no in-full component; our OTIF converges on the same numbers and adds in-full.
- The trigger for `FactScheduleChange` is reason-driven, not date-only.
- In-Full carries no signal at `FactSalesDetail` line grain — nothing ships short there, so OTIF collapses to On-Time.
- Do not add `DaysMoved > 0 && NextStatus >= 540` to `Is OTIF Relevant`: it drops the revisions logged without a date move that the reason-driven trigger exists to catch.
- EDW carries ~2× the orders Cognos shows (upstream scope issue; rates match). Residual = the "OTIF code but shipped on time" carve-out plus order types the Cognos slicer excludes. Order-type decode: `F0005` `00`/`DT`.
- The Cognos order report runs on `DW_LEGACY` with a revenue gate (`SALES_FACTOR > 0`), `ORDER_LINE_LAST_UPDATED_BY <> 'SCHED'`, an India tax pseudo-item exclusion, an update-date window and customer inner joins — that combination is what drops ST transfers and cost-only SL lines from its population.
- "OTIF (strategic)" is believed to mean Customer Tier = Strategic — unconfirmed.

## TRIR
- `(recordable cases × 200,000) / hours`, OSHA calc, by Orgname/year. The `Hours` table feeds it.
- YTD runs to the last complete month.
- Long-term feed is the Gensuite DWH/NiFi raw feed (`IM_HoursLogged`). Open: PII exclusion, contingent-hours scope, EDW landing, cadence.

## RTFT
- One measure: `[RTFT %] = IF([Batches] >= 50, DIVIDE([Batches] - [Batch Mfg Issues], [Batches]))`.
- "RTFB" is the client's SSAS name for the same thing — traceability only, never a second measure.
- Denominator is `[Batches]` (work-order rows flagged `SOP Flag - Counts As Batch = "Batch"`), not `[WO Count]`.
- Numerator `[Batch Mfg Issues]` = distinct SF cases of the Batch Mfg Issue record type only (`RecordTypeId = '012f4000000DyF9AAK'`).
- Written as `(b - c)/b`, never `1 - DIVIDE(...)` — the latter plots false 100% on empty periods.
- The 50-batch floor is load-bearing; re-measure before changing it.
- `WorkOrders`→`DateTable` active join is `[Completion Date (SOP Basis)]`; `[Order Date]` join exists but is inactive. No `USERELATIONSHIP` anywhere in the model.
- The zero-date guard on `[Completion Date (SOP Basis)]` is load-bearing (JDE julian 0 → 1900 date).
- WO Ledger and WO Parts List carry no date filter and show WOs with no completion date; a date slicer on either page would silently hide them.
- Region: `BranchSKey → TbBranch → TbCompany`, reusing the `FactSalesDetail[Region]` SWITCH.
- Open: reinstate a Near Miss exclusion? Near Misses are a material share of Batch Mfg Issue cases — decision belongs to Jessica/Dave.
- Open: no case-to-work-order join exists (only `LotSKey` on both sides could provide one; unwired).

## Executive Scorecard
- A `Scorecard` calc table + `[Scorecard *]` measures rebuilding the client slide. Section 3 (Drive Continuous Improvement) is the Scorecard KPIs custom visual — hand-maintained rows in D1 `manual_kpis`, no model backing; section 4 is the Scorecard Comments visual.
- Every `[Scorecard *]` basis must be self-scoping — the page's filters are all on `FactSalesDetail`, so measures sourced from `Complaints`/`Hours`/`WorkOrders` get no page filtering. The RTFT basis includes `Complaints[Level_1] = "Product Quality"` for this reason.

## Complaints
- Source: `ODSDEV ODS_SalesForce.dbo.Case` — the raw SF object mirror, live chain. EDWPROD's SF feed is frozen at 2024-08 — prod is deep-history only. All lookups (RecordType, Account, Product2, User) join on the same server, so the query folds to one statement.
- `Record_Type` = `dbo.RecordType.Name`. The RTFT numerator's type is "Batch Mfg Issue" (`012f4000000DyF9AAK`); all 13 ids in use resolve.
- `Days_Case_Open` = SF's `days_Case_Open__c`: calendar days created→closed, frozen at close, ticking while open; NULL on closed cases with no ClosedDate (they drop out of `[Avg Open Days]`, which is correct). Never derive it from ClosedDate — null ClosedDate ≠ open on ~23% of cases.
- The OTIF PBIP's Complaints table still reads `EDWDEV BIQL.TbSF_Case`.

## Model naming
- Orders fact is `FactSalesDetail` (older docs say `Orders from EDW` — same thing). The OTIF model carries **invoiced** lines (GL-posted, `GLDate >= 2024-01-01`) **plus open** order lines (`StatusCodeNext <> 999`; `GLDate` holds the JDE 1900 placeholder until invoicing). `[Flag In Population]` (DAX) = 1 marks the invoiced population; a report-level filter holds Flag = 1, so shipped OTIF numbers read invoiced-only and open lines surface only where a page asks for them. The Executive Dashboard copy of the query is invoiced-only (`GLDate >= 2024-01-01` alone). ODS `F4211` ∪ `F42119` is the shipped-grain source.
- Customer names live in the address book (`DimAddress.MailingName` via `AddressSKey`); `DimCustomer` carries none.
- `Ext Price` is local currency — rank within a country, never sum across countries. A $-weighted metric needs a base/USD amount.
- `Region` comes from Order Company. Ship-To Country is a drill field only, not a Region source.
- Reason dimension is `Reason Codes`. `Reason Filter` is a disconnected table powering the revision-reason multiselect via `TREATAS` — a static `[On Time]` calc column would break it, don't reintroduce one.
- `RevisionKey` is defined in exactly one place: `edw_model/FactScheduleChange.m` (`OrderLineID|yyyy-MM-dd|ChangeTime`, culture-pinned).
- Enrichment columns (e.g. `CustomerSegmentation`) exist only on `BIQL.*` views, not `dbo` dims — join across schemas on the SKey.
- Source routing for new reports: SSAS → EDW → ODS, preferring SSAS live connection where the perspective covers it. Delivered reports stay on EDW/ODS.
