// ============================================================================
// Report 03 - CM Sales Orders < 560 (Not Enough Inventory to Ship)
// QUERY: SO_Not_Shipping  ->  the SALES-ORDER master list (LEFT block of the
//        master-detail panel). Cognos query object "Open Orders" (raw block A,
//        the C0..C23 pivot with window functions).
//
// Columns (rendered, left block): Plant | Item | Order Date | Order # | Line # |
//        Promised Ship | Customer | Next Status | Qty | Qty (Primary) | Lot#
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Matches the house pattern in edw_model/JDE_Orders/Orders.m and reports 01/02.
//
// NOTE: written with a single flat SELECT (no WITH/CTE). With [EnableFolding=true]
//   Power BI wraps the query as "SELECT * FROM (<query>)"; a leading CTE cannot be
//   wrapped -> "Incorrect syntax near 'WITH'". A flat/derived-table form wraps fine
//   and keeps folding on. NO ORDER BY (illegal inside the folded subquery) -- the
//   sort lives in the visual (see BUILD.md).
//
// LOGIC (faithful to Cognos "Open Orders"):
//   Open F4211 sales-order lines in the Cincinnati plants for the next 21 days that
//   are still pre-shipping (Next Status 525..550, Line Type 'S'), whose 2nd item is
//   on Brent's CM whitelist, and that have no lot assigned yet. One row per order
//   line. The per-item ordered quantity (window SUM) drives the "not enough
//   inventory" gate that is applied in Power BI (see BUILD.md "Not-Enough-Inventory
//   gate" -- it compares this against the per-item AVAILABLE from Inventory_Availability).
//
// ORACLE -> T-SQL conversions:
//   PRODDTA.JUL2DATE(x)   -> CASE WHEN x>0 THEN DATEADD(DAY,(x%1000)-1,
//                             DATEFROMPARTS(1900+(x/1000),1,1)) END   (JDE CYYDDD)
//   sysdate+21            -> DATEADD(DAY,21,CAST(GETDATE() AS date))  (flat +21 CAL days)
//   trim(both from x)     -> LTRIM(RTRIM(x))
//   trim(x/10000)         -> x/10000.0        (Cognos "trims" a NUMBER -- a no-op quirk;
//                                              in T-SQL just divide, drop the trim)
//   SDLNID/1000           -> SDLNID/1000.0    (float so sub-lines like 1.5 survive)
//
// QUIRKS reproduced / dropped on purpose (see BUILD.md "Known Cognos quirks"):
//   * DAY_OF_WEEK / WEEKDAY / CALC_DAYS_FORWARD data items in Cognos are VESTIGIAL --
//     they are computed but never referenced by a filter. The real look-ahead is a
//     FLAT sysdate+21 (not a business-day window like report 01). Omitted here.
//   * The Cognos outer window count/sum "over (partition by C0..C19)" is list-render
//     plumbing (running counts for the group footer). Replaced by matrix subtotals /
//     DAX in Power BI. We keep only the meaningful per-item SUM (Qty Ordered Per Item).
//   * Whitelist contains 'UNYTEC201-FD' TWICE (verbatim from Cognos) -- harmless.
//   * Cognos also INNER-JOINs Sold-To (F0101 via SDAN8) and Order Company (F0010 via
//     SDKCOO=CCCO) and LEFT-JOINs CSR (F42140). Sold-To + Company are kept (they are
//     1:1 non-filtering, preserved for exact row-set parity); their columns are not
//     shown. The CSR left join is dropped (unused, cannot affect the row set).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(so.SDMCU))                                   AS [Plant],
            LTRIM(RTRIM(so.SDLITM))                                  AS [Item],
            (CASE WHEN so.SDTRDJ > 0
                  THEN DATEADD(DAY, (so.SDTRDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDTRDJ / 1000), 1, 1))
             END)                                                    AS [Order Date],
            so.SDDOCO                                                AS [Order#],
            so.SDLNID / 1000.0                                       AS [Line#],
            (CASE WHEN so.SDPDDJ > 0
                  THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
             END)                                                    AS [Promised Ship],
            shipto.ABALPH                                            AS [Customer],
            so.SDNXTR                                                AS [Next Status],
            so.SDUORG / 10000.0                                      AS [Qty],
            so.SDPQOR / 10000.0                                      AS [Primary Qty],
            LTRIM(RTRIM(so.SDLOTN))                                  AS [Lot#],
            SUM(so.SDPQOR / 10000.0)
                OVER (PARTITION BY LTRIM(RTRIM(so.SDLITM)))          AS [Qty Ordered Per Item]
        FROM PRODDTA.F4211 so
        INNER JOIN PRODDTA.F0101 shipto ON so.SDSHAN = shipto.ABAN8
        INNER JOIN PRODDTA.F0101 soldto ON so.SDAN8  = soldto.ABAN8
        INNER JOIN PRODDTA.F0010 comp   ON so.SDKCOO = comp.CCCO
        WHERE so.SDNXTR IN ('525','530','535','536','537','540','545','550')
          AND so.SDLNTY = 'S'
          AND LTRIM(RTRIM(so.SDLITM)) IN (
                '161017CX-FD','161017CX-OP','161190PX-T2','161190PX-T3','171143PX-T2',
                '191245PX-T2','APT10','APT10-T2','APT11','APT11-T2','BPADA','BTDA','BYK3565',
                'C2','CAN','CORNERB','CRTNCLEAR','CRTNDARK','CRTNWHITE','DMAEMA','DMEA',
                'DPE3500-T2','EMA3065','FERSUL7W','GEN926','HP1432AT-OP','HP1632','HP1632-T2',
                'HP1632-T2*OP10','IND139','KOH50','MD4020-C1','MD4020-C2','MD4020C-C2','MD4021',
                'MD4021-C1','MD4021-C2','MD4021C-C2','MD4022','MD4022C-C2','MD4023','MD4023-C2',
                'MD4023C-C2','MDU20-T2','MPD','MW40504','MW40504-C2','MW40514','MW40514-C2',
                'NS41-PL','PEG1450','PEG1450.S','PERSD','PTMG','STODSO','TC275','THERMOT','THF',
                'U1001-OP','U101-OP','U201-T2','U2022-OP','U2023-OP','U204-OP','U204-T2','U470-OP',
                'U501B','U501B-OP','U501-OP','U502.E','U502-OP','U601-OP','U701-OP','UNYTE201',
                'UNYTEC201-FD','WAH12MDI','WAV501','WD40','WD40-SP','WD40-UN','JS037-OP','HP401-OP',
                'HSCF410-PL','UNYTEC201-FD'
              )
          AND (so.SDLOTN IS NULL OR LTRIM(RTRIM(so.SDLOTN)) = '')
          AND (CASE WHEN so.SDPDDJ > 0
                    THEN DATEADD(DAY, (so.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (so.SDPDDJ / 1000), 1, 1))
               END) <= DATEADD(DAY, 21, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(so.SDMCU)) IN ('CINC','CIN2','CIN4')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Plant", type text},
            {"Item", type text},
            {"Order Date", type date},
            {"Order#", Int64.Type},
            {"Line#", type number},
            {"Promised Ship", type date},
            {"Customer", type text},
            {"Next Status", type text},
            {"Qty", type number},
            {"Primary Qty", type number},
            {"Lot#", type text},
            {"Qty Ordered Per Item", type number}
        }
    )
in
    Typed
