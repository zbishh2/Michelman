// ============================================================================
// Report 16 - LTL report over 20k lbs  |  "LTL Shipments over 20,000 lbs."
// QUERY OBJECT: "Report" (Cognos SQL name "Report7") -> the ONLY data the visible
//   page needs. The page's list is bound to "Query1", but Query1 = Report LEFT
//   JOIN "CAM ID" purely to attach a burst recipient (CAMID); none of the CAM ID /
//   USER_DETAILS columns are displayed. So the PBI rebuild = the Report query alone.
//   (See BUILD.md "Burst analysis".)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   CHOSEN over SSAS/EDW because this reproduces the DEPLOYED Cognos SQL exactly
//   (same F42140 CMRTYPE='CSR' CSR derivation, same per-row >20k filter, same
//   carrier exclusion list) -> guaranteed parity. Same table shape as report 04
//   (F4211 + F42140-CSR + F0101), which is validated. Route eval in BUILD.md sec 1.
//
// NO CTEs (a leading WITH breaks folding: PBI wraps as "SELECT * FROM (<q>)").
// NO ORDER BY inside the folded query (illegal in SQL Server) -> sort in the visual.
//
// PORTED FROM the deployed generated SQL (Report.0.sql). Oracle -> T-SQL changes:
//   - "PRODDTA".JUL2DATE(SDPDDJ)  ->  CASE WHEN SDPDDJ>0 THEN DATEADD/DATEFROMPARTS
//   - SDPQOR/10000  ->  SDPQOR/10000.0   (JDE quantity implied 4 decimals)
//   - SDLNID/1000   ->  SDLNID/1000.0    (JDE line number implied 3 decimals)
//   - carrier NOT IN ('...')  ->  numeric literals (SDCARS is a numeric AddressNum)
//   - LTRIM(RTRIM(...)) added on JDE CHAR string attributes (trailing-space parity,
//     report 04 pattern). Does not change the grouped grain.
//
// GRAIN = order line. The Cognos GROUP BY carries SDLNID/1000 + every identity
//   column, so SUM(SDPQOR/10000) is cosmetic at this grain (one row per group).
//
// >20,000 FILTER - DEPLOYED SEMANTICS: applied PER ROW in the WHERE
//   (SDPQOR/10000 > 20000), BEFORE aggregation. This is what the live report does.
//   Lilly's 2026-07-06 rewrite instead uses HAVING SUM(...) > 20000 (post-group) -
//   a BEHAVIOR CHANGE that only differs if a single (order,line) has >1 F4211 row.
//   We port the DEPLOYED per-row WHERE. Probe 00_verify_tables.sql block 5 measures
//   whether any (order,line) actually has >1 row; if none, WHERE == HAVING here.
//   Which semantics the business wants is an OPEN DECISION (BUILD.md sec 8).
//
// CSR NAME: F42140 filtered to CMRTYPE='CSR', joined F0101 on CMSLSM=ABAN8, then
//   LEFT JOIN on ship-to (SDSHAN = CMAN8). Resolves CSR by SHIP-TO ADDRESS only -
//   no order-company / line qualifier -> if a ship-to has >1 'CSR' row in F42140,
//   the LEFT JOIN FANS OUT and duplicates the order line (Cognos does the same;
//   reproduced faithfully). Probe block 4 measures CSR multiplicity per CMAN8.
//
// CSR AB Number (CMSLSM) is carried HIDDEN - it is the key the Cognos burst grouped
//   on (burstGroup=[AB Number]). Kept so the burst can be replaced by a CSR slicer
//   or RLS in PBI (BUILD.md sec 6). It is NOT a displayed column.
//
// COLUMNS emitted in PAGE display order (List1), then the hidden CSR AB Number:
//   Scheduled Pick Date | Carrier AB Number | Customer Name | Order Number |
//   Next Status | Order Type | Order Line | Carrier Name | CSR Name |
//   Primary Quantity Ordered | Primary UOM | [CSR AB Number, hidden]
//
// NOTE: the deployed SQL also emits Order Company (SDKCOO, constant '00010', a
//   filter) and a DUPLICATE quantity column "c13" (= C6 output twice, a Cognos
//   artifact). Neither is displayed on the page -> both OMITTED here.
//
// FILTERS baked in (all static detailFilters - no Cognos prompts, no slicers,
//   no date literals => genuinely LIVE, schedule a daily refresh):
//   SDKCOO = '00010'; SDDCTO IN (S4,S5,SZ,SC,ST);
//   SDNXTR IN (560,550,545,540,535,530,525);
//   SDCARS NOT IN (22 hard-coded AddressNums) AND SDCARS <> 308636 (23rd);
//   SDPQOR/10000 > 20000.
//   *** The 23 hard-coded carrier exclusions are a maintenance landmine (a new
//   carrier is silently included until someone edits this list). Flag to business
//   (BUILD.md sec 7 / open decisions). ***
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            base.Scheduled_Pick_Date              AS [Scheduled Pick Date],
            base.Carrier_AB_Number                AS [Carrier AB Number],
            base.Customer_Name                    AS [Customer Name],
            base.Order_Number                     AS [Order Number],
            base.Next_Status                      AS [Next Status],
            base.Order_Type                       AS [Order Type],
            base.Order_Line                       AS [Order Line],
            base.Carrier_Name                     AS [Carrier Name],
            base.CSR_Name                         AS [CSR Name],
            SUM(base.Primary_Quantity_Ordered)    AS [Primary Quantity Ordered],  /* cosmetic sum at line grain */
            base.Primary_UOM                      AS [Primary UOM],
            base.CSR_AB_Number                    AS [CSR AB Number]              /* hidden: burst key / slicer */
        FROM (
            SELECT
                o.SDDOCO                          AS Order_Number,
                o.SDDCTO                          AS Order_Type,
                o.SDCARS                          AS Carrier_AB_Number,
                LTRIM(RTRIM(carr.ABALPH))         AS Carrier_Name,
                LTRIM(RTRIM(csr.ABALPH))          AS CSR_Name,     /* F42140 CMRTYPE='CSR' -> F0101 */
                o.SDPQOR / 10000.0                AS Primary_Quantity_Ordered,
                LTRIM(RTRIM(o.SDUOM1))            AS Primary_UOM,
                o.SDNXTR                          AS Next_Status,
                LTRIM(RTRIM(shipto.ABALPH))       AS Customer_Name,
                o.SDLNID / 1000.0                 AS Order_Line,
                CASE WHEN o.SDPDDJ > 0            /* JDE Julian CYYDDD -> date (JUL2DATE port) */
                     THEN DATEADD(DAY, (o.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (o.SDPDDJ / 1000), 1, 1))
                END                               AS Scheduled_Pick_Date,
                csr.CMSLSM                        AS CSR_AB_Number
            FROM PRODDTA.F4211 o
            INNER JOIN PRODDTA.F0101 shipto
                ON o.SDSHAN = shipto.ABAN8                        /* ship-to customer name */
            LEFT OUTER JOIN (
                SELECT c.CMAN8, c.CMSLSM, a.ABALPH
                FROM PRODDTA.F42140 c
                INNER JOIN PRODDTA.F0101 a
                    ON c.CMSLSM = a.ABAN8
                WHERE c.CMRTYPE = 'CSR'
            ) csr
                ON o.SDSHAN = csr.CMAN8                           /* CSR resolved by ship-to; fan-out risk */
            LEFT OUTER JOIN PRODDTA.F0101 carr
                ON o.SDCARS = carr.ABAN8                          /* carrier name */
            WHERE o.SDKCOO = '00010'
              AND o.SDDCTO IN ('S4','S5','SZ','SC','ST')
              AND o.SDNXTR IN ('560','550','545','540','535','530','525')
              AND o.SDCARS NOT IN (293371,29671,288676,26185,293492,98725,301322,195487,136656,293919,304977,309791,301333,309741,27710,26171,283919,26175,301761,292099,309757,316502)
              AND o.SDPQOR / 10000.0 > 20000                      /* DEPLOYED: per-row, pre-aggregation */
              AND o.SDCARS <> 308636
        ) base
        GROUP BY
            base.Scheduled_Pick_Date,
            base.Carrier_AB_Number,
            base.Customer_Name,
            base.Order_Number,
            base.Next_Status,
            base.Order_Type,
            base.Order_Line,
            base.Carrier_Name,
            base.CSR_Name,
            base.Primary_UOM,
            base.CSR_AB_Number
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Scheduled Pick Date", type date},
            {"Carrier AB Number", Int64.Type},
            {"Customer Name", type text},
            {"Order Number", Int64.Type},
            {"Next Status", type text},
            {"Order Type", type text},
            {"Order Line", type number},
            {"Carrier Name", type text},
            {"CSR Name", type text},
            {"Primary Quantity Ordered", type number},
            {"Primary UOM", type text},
            {"CSR AB Number", Int64.Type}
        },
        "en-US"
    )
in
    Typed
