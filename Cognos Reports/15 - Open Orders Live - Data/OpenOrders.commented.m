// ============================================================================
// Report 15 - Open Orders - Live Data   |   TABLE: "Open Orders"
//
// ONE table feeds ALL FIVE Cognos pages (Tammy / Nae / Kim / Shannon / Other).
// The five Cognos query objects are IDENTICAL open-sales-order lists that differ
// ONLY by a hard-coded CSR-name filter (and Kim's extra Promised-Ship+30 filter).
// Instead of five near-duplicate tables (four of which are permanently empty
// under parity - see DEFECT below) this is ONE base population plus a derived
// [CSR Page] column; the build agent puts a page-level filter [CSR Page]=<name>
// on each of the five report pages. See BUILD.md sec.1 and sec.6 for the
// single-vs-five rationale and the one documented grain deviation.
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   House pattern = report 04 (CM Open Sales Orders Live) - same F4211 + F42140
//   (CSR) + F0101 chain, same Julian decode, same derived-table nesting.
//   No CTE (a leading WITH breaks folding: PBI wraps as "SELECT * FROM (<q>)").
//   No ORDER BY inside the folded query (illegal in SQL Server) -> sort in visual
//   (Promised Ship asc, then Order asc; Cognos NULLs-last == PBI blanks-last asc).
//
//   SSAS (BIQLTabular_v2) was REJECTED: v2.xmla has no "Open Orders" fact and 0
//   hits for CSR Name / Pricing Quantity / Next Status at this grain, and a Live
//   Connection can add neither the weight-decode measure nor the [CSR Page]
//   logic. EDW has FactSalesDetail (F4211) but not the F4201-header attributes
//   (Hold / MOT / Delivery Instructions) pre-joined here. ODS covers 100%.
//
// COGNOS SOURCE DEFECT (reproduced, not fixed - same family as defect C1):
//   The four named pages filter on hard-coded CSR names 'Runyan, Tammy' /
//   'McCrary, Nae' / 'Benjamin, Kim' / 'Garner, Shannon'. All four are still
//   valid F42140 CMRTYPE='CSR' assignments, but (probed 2026-07-16) no ship-to
//   with a currently-open order maps to them - the active books belong to six
//   other reps - so all four pages return ZERO rows and every order lands on
//   "Other". We reproduce the names verbatim in [CSR Page]; the recommended fix
//   (expose live CSR Name as a slicer / repoint to current names) is a disclosed
//   recommendation in BUILD.md, NOT applied here.
//
// COLUMN ORDER (Cognos listColumns, left->right; header = dataItem label=):
//   Order | Customer | Next | BP | Requested | Promised Ship | Qty | UOM |
//   Weight | Item | Hold | Carrier | MOT | DI1 | DI2
//   ([CSR Name] and [CSR Page] are EXTRA, non-Cognos helper columns; hide [CSR
//   Name], use [CSR Page] only for the page filters.)
//
// COGNOS FILTERS (verbatim, from every query's WHERE - Tammy.0.sql etc.):
//   SDNXTR < '570'                 open orders only (next status under 570)
//   SDKCOO = '00010'               order company 00010
//   SDLNTY NOT IN ('FS','T')       exclude freight / text lines
//   SDDCTO <> 'SQ'                 exclude quote order type
//   CSR ABALPH = <name> / not in   -> reproduced as [CSR Page]; the LEFT JOIN in
//                                     Cognos is effectively INNER (every page's
//                                     filter drops NULL CSR), so CSR is INNER
//                                     JOINed here -> orders whose ship-to has NO
//                                     CSR-type F42140 row are excluded from ALL
//                                     pages. This is faithful to Cognos.
//   Kim ONLY: SDPDDJ < sysdate+30  -> materialized as the [Kim Window] 0/1 helper
//                                     column below, NOT a PBI relative-date filter.
//                                     PBI relative-date ("next 30 days") is a TWO-
//                                     sided window that would wrongly drop overdue
//                                     (past promised-ship) orders, which Cognos
//                                     KEEPS (it is a one-sided < sysdate+30). So the
//                                     Kim page filters [CSR Page]='Kim' AND
//                                     [Kim Window]=1. NULL promised-ship -> 0 (SQL
//                                     NULL < date is unknown -> ELSE 0), matching
//                                     Oracle's NULL-comparison exclusion. (Orchestrator
//                                     decision 2026-07-15, supersedes the earlier
//                                     "page-level relative-date filter" note.)
//   This is OPEN orders (NXTR<570); no F42119 history union is needed.
//
// JULIAN CYYDDD -> date: CASE WHEN j>0 THEN DATEADD(DAY,(j%1000)-1,
//   DATEFROMPARTS(1900+(j/1000),1,1)) END. sysdate -> CAST(GETDATE() AS date).
//   Rolling windows (Kim +30) fix at REFRESH time -> schedule a daily refresh.
//
// JDE IMPLIED DECIMALS: SDUORG/10000, SDPQOR/10000, SDSQOR/10000 (qty x10000);
//   F41002 UMCONV/10000000 (conversion factor x10,000,000). SDDOCO order # raw.
//
// [Weight] = Pricing Quantity = Oracle decode(SDUOM4, SDUOM1,SDPQOR, SDUOM2,
//   SDSQOR, SDUOM,SDUORG, default nvl(UMCONV*SDUORG,0)) -> the CASE below. It
//   expresses the ordered qty in the PRICING unit of measure (SDUOM4 / F41002
//   UMRUM).
//
// UNTRIMMED display columns (PARITY): the Cognos generated SQL does NOT trim, so
//   the rendered xlsx shows JDE storage padding - BP right-justified
//   ('        CIN2'), Item / Customer / Carrier / Hold / MOT / DI left- or
//   space-padded. We preserve that here for byte parity with the xlsx. Trimming
//   is a one-line change (LTRIM(RTRIM())) if the business prefers clean values -
//   flagged as an open decision in BUILD.md. [CSR Name] IS trimmed (helper only).
//
// GRAIN / DOCUMENTED DEVIATION: Cognos groups by {Promised Ship, Order, Customer,
//   BP, Next, Requested, Carrier, Item, Hold, MOT, DI1, DI2, UOM} and SUMs Qty +
//   Weight; CSR is NOT in that group-by (it is filter-only). To page a single
//   table we add [CSR Name] to the grain (one extra GROUP BY column). In practice
//   CSR is a function of the order's ship-to, so this never splits a row; the only
//   edge is a customer with 2+ CSR-type F42140 rows (see FAN-OUT probe, block 3).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            o.SDDOCO                                   AS [Order],
            sold.ABALPH                                AS [Customer],
            o.SDNXTR                                   AS [Next],
            o.SDMCU                                    AS [BP],
            o.Requested_Date                           AS [Requested],
            o.Promised_Ship_Date                       AS [Promised Ship],
            SUM(o.SDUORG / 10000.0)                    AS [Qty],
            o.SDUOM                                    AS [UOM],
            SUM(CASE
                    WHEN o.SDUOM4 = o.SDUOM1 THEN o.SDPQOR / 10000.0
                    WHEN o.SDUOM4 = o.SDUOM2 THEN o.SDSQOR / 10000.0
                    WHEN o.SDUOM4 = o.SDUOM  THEN o.SDUORG / 10000.0
                    ELSE ISNULL((conv.UMCONV / 10000000.0 * o.SDUORG) / 10000.0, 0)
                END)                                   AS [Weight],
            o.SDLITM                                   AS [Item],
            hdr.SHHOLD                                 AS [Hold],
            carr.ABALPH                                AS [Carrier],
            hdr.SHMOT                                  AS [MOT],
            hdr.SHDEL1                                 AS [DI1],
            hdr.SHDEL2                                 AS [DI2],
            csr.ABALPH                                 AS [CSR Name],
            CASE
                WHEN csr.ABALPH = 'Runyan, Tammy'   THEN 'Tammy'
                WHEN csr.ABALPH = 'McCrary, Nae'    THEN 'Nae'
                WHEN csr.ABALPH = 'Benjamin, Kim'   THEN 'Kim'
                WHEN csr.ABALPH = 'Garner, Shannon' THEN 'Shannon'
                ELSE 'Other'
            END                                        AS [CSR Page],
            /* [Kim Window] = Kim-page-only Promised-Ship < sysdate+30, as a 0/1 flag
               (see filter note above). Grouped column Promised_Ship_Date drives it,
               so no extra GROUP BY entry is needed. NULL date -> 0. */
            CASE WHEN o.Promised_Ship_Date < DATEADD(DAY, 30, CAST(GETDATE() AS date)) THEN 1 ELSE 0 END AS [Kim Window]
        FROM (
            /* ---- open F4211 lines with the two Julian dates decoded ---- */
            SELECT
                SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDMCU, SDAN8, SDSHAN, SDITM, SDLITM,
                SDLNTY, SDNXTR, SDUOM, SDUORG, SDCARS, SDUOM1, SDPQOR, SDUOM2, SDSQOR, SDUOM4,
                CASE WHEN SDDRQJ > 0 THEN DATEADD(DAY,(SDDRQJ % 1000)-1,DATEFROMPARTS(1900+(SDDRQJ/1000),1,1)) END AS Requested_Date,
                CASE WHEN SDPDDJ > 0 THEN DATEADD(DAY,(SDPDDJ % 1000)-1,DATEFROMPARTS(1900+(SDPDDJ/1000),1,1)) END AS Promised_Ship_Date
            FROM PRODDTA.F4211
        ) o
        INNER JOIN PRODDTA.F0101 sold ON o.SDAN8 = sold.ABAN8
        INNER JOIN PRODDTA.F4201 hdr  ON o.SDKCOO = hdr.SHKCOO
                                     AND o.SDDOCO = hdr.SHDOCO
                                     AND o.SDDCTO = hdr.SHDCTO
                                     AND o.SDSFXO = hdr.SHSFXO
        LEFT JOIN PRODDTA.F41002 conv ON o.SDMCU  = conv.UMMCU
                                     AND o.SDITM  = conv.UMITM
                                     AND o.SDUOM  = conv.UMUM
                                     AND o.SDUOM4 = conv.UMRUM
        /* CSR: Cognos LEFT JOIN is effectively INNER (all pages drop NULL CSR).
           F42140 CMRTYPE='CSR' -> CMSLSM -> F0101 rep name. Filter-only in Cognos;
           here promoted to a grain column to page the single table. */
        INNER JOIN (
            SELECT c.CMAN8, LTRIM(RTRIM(n.ABALPH)) AS ABALPH
            FROM PRODDTA.F42140 c
            INNER JOIN PRODDTA.F0101 n ON c.CMSLSM = n.ABAN8
            WHERE c.CMRTYPE = 'CSR'
        ) csr ON o.SDSHAN = csr.CMAN8
        LEFT JOIN PRODDTA.F0101 carr ON o.SDCARS = carr.ABAN8
        WHERE o.SDNXTR < '570'
          AND o.SDKCOO = '00010'
          AND o.SDLNTY NOT IN ('FS','T')
          AND o.SDDCTO <> 'SQ'
        GROUP BY
            o.SDDOCO, sold.ABALPH, o.SDNXTR, o.SDMCU,
            o.Requested_Date, o.Promised_Ship_Date, o.SDUOM, o.SDLITM,
            hdr.SHHOLD, carr.ABALPH, hdr.SHMOT, hdr.SHDEL1, hdr.SHDEL2,
            csr.ABALPH
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order", Int64.Type},
            {"Customer", type text},
            {"Next", type text},
            {"BP", type text},
            {"Requested", type date},
            {"Promised Ship", type date},
            {"Qty", type number},
            {"UOM", type text},
            {"Weight", type number},
            {"Item", type text},
            {"Hold", type text},
            {"Carrier", type text},
            {"MOT", type text},
            {"DI1", type text},
            {"DI2", type text},
            {"CSR Name", type text},
            {"CSR Page", type text},
            {"Kim Window", Int64.Type}
        },
        "en-US"
    )
in
    Typed
