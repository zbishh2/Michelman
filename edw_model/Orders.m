// Orders — EDW sales-order line fact; the orders denominator. Live model table
// name is FactSalesDetail. "Orders" = distinct [Order Num] (a measure); column
// aliases match Complaints.xlsx 'Sales Orders'.
//
// SOURCE: EDWPROD / EDW / dbo.FactSalesDetail. The JDE/orders feed is current
// (through 2026); only the Salesforce chain on prod is stale.
//
// CONNECTION: native query (Sql.Database with [Query=...]), matching the deployed
// PBIP partition, and bound to the shared on-prem data gateway for scheduled
// refresh in the Power BI Service. ⚠ A native query is a fixed passthrough, so PQ
// steps past Typed may not fold — keep transforms in the SQL.
//
// SERVER must match the gateway's registered data source string — the short name
// "EDWPROD" — and resolve where Desktop refreshes (the jump box, via DNS suffix).
// Gateway creds: Windows auth, UPN "ZackB@michem.com" (NOT the michelman.com mail
// address, NOT "Zack.bishop" — the AD account is ZackB, the AD domain is michem.com).
//
// WINDOW: GLDate >= 2024-01-01 (the invoiced, GL-posted population, aligned to dev
// complaint coverage) OR StatusCodeNext <> '999' (open order lines: not yet
// GL-posted, so GLDate carries the JDE 1900 placeholder until invoicing).
// [Flag In Population] — a DAX column on the OTIF model, = 1 iff GLDate >= 2024-01-01 —
// marks the invoiced population; the OTIF report-level filter keeps Flag = 1, so every
// shipped number reads the invoiced population and open lines surface only where a
// page asks for them.
// ⚠ The Executive Dashboard partition runs this same SELECT with the invoiced-only
// window (WHERE GLDate >= '2024-01-01' alone) — open lines stay out of revenue reporting.
//
// RecordType 'GL Detail' rows (= Line Type 'AA') are dropped at source. The
// "IS NULL OR" guard keeps NULL RecordType rows under SQL's three-valued logic.
//
// [Business Unit Revenue] = JDE revenue business unit (MCU): first 2 digits =
// company (10 = Americas, 20 = Europe); remainder = cost center / product line.
//
// SSAS helper columns (Order Exclude / Filter Active Types / Exclude Freight) do
// not exist in the raw fact — apply the equivalent on Order Type / Line Type /
// Cancelled_Flag, kept raw here and filtered in the measure. ⚠ Open: Greg to lock
// the order-type list.
//
// COGNOS FILTERSETS ARE SOFT FLAGS. The IT-provided Cognos query hard-filters five
//   conditions; here each is a 1/0 [Flag ...] column, so the report reproduces the
//   Cognos population exactly via slicer (Flag = 1 on all five) without losing rows.
//   GLDate is the only hard bound. FactSalesDetail carries every source column, so
//   these are EXACT, not proxies:
//     [Flag Positive Volume]          (QuantityOrdered*ConversionFactorLB*SalesFactor) > 0
//     [Flag Line Type S]              LineType = 'S'
//     [Flag Not Sched]                UserID <> 'SCHED'   (UserID = JDE SDUSER, last-updated-by)
//     [Flag Updated In Cognos Window] UpdatedDate in 2024-01-01..2025-02-24
//     [Flag Not India Tax]            ItemNum2nd not in IGST/CGST/SGST/CVD/ADD
//   ⚠ India-tax is the one approximation: Cognos keys off
//     decode(GLOBAL_BULK_ITEM,'-',ITEM_NUMBER_2ND,GLOBAL_BULK_ITEM) and
//     FactSalesDetail has no GlobalBulkItem column, so ItemNum2nd is tested
//     directly. Equivalent unless a bulk item overrides the 2nd item number.
//   Supporting raw columns [Updated Date] / [Updated By] / [Conversion Factor LB] /
//   [Sales Factor] / [Revision Reason] are surfaced so the flags are auditable, and
//   [Revision Reason] sits alongside [Order Line ID] for FactScheduleChange.
//
// MASTER PLANNING FAMILY is folded on as FACT columns, not a dimension + relationship.
//   MPF is F4102.IBPRP4 (item BRANCH, not item master), decoded by UDC 41/P4, exposed
//   only on the BIQL view — dbo.DimItemBranch carries no enrichment columns
//   (CLAUDE.md §4). Its grain is (ItemSKey, Business Unit), both already in this
//   SELECT, so it folds in as a LEFT JOIN with no new source, zero DAX changes and no
//   bidirectional filter risk. Fact-side by design: a 1:1 dimension hop in a wide-grid
//   group-by is what caused the OOM in CLAUDE.md §7, and pushing the attribute onto the
//   fact was the fix.
//   ⚠ FAN-OUT GUARD: the join target is a GROUP BY derived table, so it emits at most
//   one row per (ItemSKey, BU) and cannot change the fact row count. TbItemBranch is
//   not documented as unique on that pair; MIN() is the tie-break. A GROUP BY derived
//   table is hash-aggregated once — it is NOT the correlated per-row lookup
//   (OUTER APPLY / ROW_NUMBER) that hung report 14 twice, per CLAUDE.md §7.
//   Both sides are nchar(12), so ANSI padding makes '=' trailing-space-insensitive;
//   the TRIMs are belt-and-braces.
//   ⚠ Open: the ask behind MPF is excluding 'PKG' (packaging / quilts). Per the
//   soft-flag convention nothing is dropped here — slice it in the report. Lock the
//   exclusion list, then promote it to a [Flag ...] column.
//
// SPLIT LINES are DESCRIBED, never collapsed. JDE splits a sales order line into
//   1.000 / 1.001 / 1.002 (LineNum is decimal(9,3)), which inflates the OTIF line and
//   late-line counts when the children are commercially one line. Three descriptive
//   columns exist — [Parent Line Num], [Parent Order Line ID], [Is Split Child] — and
//   nothing is filtered.
//   ⚠ THE GRAIN MUST NOT CHANGE. [Order Line ID] is the join key for
//   FactScheduleChange, the key LineComments rides on, and is embedded inside
//   RevisionKey, which every writeback row in D1 is keyed by
//   (writeback/ARCHITECTURE.md). Re-graining the fact orphans every existing revision
//   override and line comment. Parent roll-up belongs in DAX over
//   [Parent Order Line ID], sitting beside the line-grain measures for comparison.
//   Rule: take the PARENT row's values for everything; only order qty aggregates
//   across the family.
let
    Source = Sql.Database(
        "EDWPROD",
        "EDW",
        [Query = "
SELECT
    OrderNum                 AS [Order Num],
    OrderCompany             AS [Order Company],
    OrderType                AS [Order Type],
    OrderSuffix              AS [Order Suffix],
    LineNum                  AS [Line Num],
    LineType                 AS [Line Type],
    LineTypeDesc             AS [Line Type Desc],
    RecordType               AS [Record Type],
    Cancelled_Flag,
    StatusCodeLast           AS [Status Code Last],
    StatusCodeNext           AS [Status Code Next],  -- 999 = closed; anything below is an open line
    GLDate                   AS [GL Date],
    ActualShipDate           AS [Actual Ship Date],
    OrderDate                AS [Order Date],
    QuantityOrdered          AS [Qty Ordered],
    QuantityShipped          AS [Qty Shipped],
    QuantityCanceledScrapped AS [Qty Cancelled],
    UOMTransaction           AS [UOM],  -- transaction unit of measure, matching the Qty* columns (nchar(2) JDE code, e.g. BX/EA/LB). Alternative bases: UOMPrimary / UOMSecondary / UOMPricing.
    LotSKey,
    LotNum                   AS [Lot Num],
    ShipToCustomerSKey,
    PromisedDeliveryDate         AS [Promised Delivery Date],
    RequestedDate                AS [Requested Date],
    PromisedShipmentDate         AS [Promised Shipment Date],
    OriginalPromisedDeliveryDate AS [Original Promised Delivery Date],
    ScheduledPickDate            AS [Scheduled Pick Date],
    Description1             AS [Product Description],
    Description2             AS [Product Description 2],
    ItemNumShort             AS [Item Num],
    ItemNum2nd               AS [Item Num 2nd],
    Location                 AS [Location],
    BusinessUnit             AS [Business Unit],
    BusinessUnitRevenue      AS [Business Unit Revenue],
    OrderTakenBy             AS [Order Taken By],
    OrderedBy                AS [Ordered By],
    ShipmentNum              AS [Shipment Num],
    BillOfLading             AS [Bill Of Lading],
    OrderLineID              AS [Order Line ID],
    OrderHeaderID            AS [Order Header ID],
    -- Split-line roll-up helpers. LineNum is decimal(9,3); 1.001/1.002 are JDE split
    -- children of parent line 1.000. [Parent Order Line ID] is derived by string surgery
    -- on the REAL OrderLineID rather than reconstructed from its parts, so the prefix
    -- matches byte-for-byte whatever format EDW uses — and on a non-split line it comes
    -- out identical to [Order Line ID], which is the built-in self-check.
    -- ⚠ FREIGHT, not kits, is the confound inside a parent family: a family carries its
    -- product splits at .001-.00n plus a LineType 'FS' BILLABLE FREIGHT line at .010.
    -- Exclude 'FS' from any parent roll-up — with it excluded, no multi-row family
    -- disagrees on Item, UoM or Master Planning Family, so summing across a family is
    -- valid. (KitMasterLineNum / KitIdentifier are not zero-defaulted in EDW and cannot
    -- be used to flag kit lines.)
    CAST(FLOOR(LineNum) AS decimal(9,3)) AS [Parent Line Num],
    LEFT(LTRIM(RTRIM(OrderLineID)),
         LEN(LTRIM(RTRIM(OrderLineID))) - CHARINDEX(',', REVERSE(LTRIM(RTRIM(OrderLineID)))))
      + ',' + CAST(CAST(FLOOR(LineNum) AS decimal(9,3)) AS varchar(12)) AS [Parent Order Line ID],
    CASE WHEN LineNum <> FLOOR(LineNum) THEN 1 ELSE 0 END AS [Is Split Child],
    SerialNumLot             AS [Serial Num Lot],
    AmountExtendedPrice      AS [Ext Price],
    AmountOpen               AS [Amount Open],
    QuantityBackordered      AS [Qty Backordered],
    QuantityOpen             AS [Qty Open],
    QuantityShippedtoDate    AS [Qty Shipped To Date],
    GrossWeight              AS [Gross Weight],
    UnitWeight               AS [Unit Weight],
    HoldOrdersCode           AS [Hold Code],
    ReasonCode               AS [Reason Code],
    ReasonCodeDesc           AS [Reason Code Desc],
    ModeOfTransport          AS [Mode Of Transport],
    CarrierNum               AS [Carrier Num],
    FreightHandlingCode      AS [Freight Handling Code],
    CancelDate               AS [Cancel Date],
    InvoiceDate              AS [Invoice Date],
    ShipToAddressSKey,
    SoldToAddressSKey,
    SoldToCustomerSKey,
    ParentCustomerSKey,
    f.ItemSKey,
    -- Master Planning Family (F4102.IBPRP4, UDC 41/P4) folded from BIQL.TbItemBranch
    -- at (ItemSKey, Business Unit). Dedup guaranteed by the GROUP BY in the join below.
    ib.MasterPlanningFamily     AS [Master Planning Family],
    ib.MasterPlanningFamilyDesc AS [Master Planning Family Desc],
    -- Supporting raw columns for the Cognos flags below (and FactScheduleChange link)
    UpdatedDate              AS [Updated Date],
    UserID                   AS [Updated By],
    ConversionFactorLB       AS [Conversion Factor LB],
    SalesFactor              AS [Sales Factor],
    RevisionReason           AS [Revision Reason],
    -- Cognos filterset flags (soft): 1 = row matches the Cognos WHERE condition.
    -- Slice Flag = 1 on all five to reproduce the Cognos population; none drop rows.
    CASE WHEN (QuantityOrdered * ConversionFactorLB * SalesFactor) > 0 THEN 1 ELSE 0 END AS [Flag Positive Volume],
    CASE WHEN LineType = 'S' THEN 1 ELSE 0 END AS [Flag Line Type S],
    CASE WHEN LTRIM(RTRIM(UserID)) <> 'SCHED' THEN 1 ELSE 0 END AS [Flag Not Sched],
    CASE WHEN UpdatedDate BETWEEN '2024-01-01' AND '2025-02-24' THEN 1 ELSE 0 END AS [Flag Updated In Cognos Window],
    CASE WHEN LTRIM(RTRIM(ItemNum2nd)) NOT IN ('IGST','CGST','SGST','CVD','ADD') THEN 1 ELSE 0 END AS [Flag Not India Tax]
FROM dbo.FactSalesDetail f
LEFT JOIN (
    SELECT ItemSKey,
           LTRIM(RTRIM([Business Unit]))                    AS BU,
           MIN(LTRIM(RTRIM([Master Planning Family])))      AS MasterPlanningFamily,
           MIN(LTRIM(RTRIM([Master Planning Family Desc]))) AS MasterPlanningFamilyDesc
    FROM BIQL.TbItemBranch
    GROUP BY ItemSKey, LTRIM(RTRIM([Business Unit]))
) ib ON ib.ItemSKey = f.ItemSKey
    AND ib.BU       = LTRIM(RTRIM(f.BusinessUnit))
WHERE (GLDate >= '2024-01-01' OR StatusCodeNext <> '999')
  AND (RecordType IS NULL OR RecordType <> 'GL Detail')
"]
    ),
    Typed = Table.TransformColumnTypes(
        Source,
        {
            {"GL Date", type date},
            {"Actual Ship Date", type date},
            {"Order Date", type date},
            {"Promised Delivery Date", type date},
            {"Requested Date", type date},
            {"Promised Shipment Date", type date},
            {"Original Promised Delivery Date", type date},
            {"Scheduled Pick Date", type date},
            {"Cancel Date", type date},
            {"Invoice Date", type date},
            {"Updated Date", type date}
        },
        "en-US"
    )
in
    Typed
