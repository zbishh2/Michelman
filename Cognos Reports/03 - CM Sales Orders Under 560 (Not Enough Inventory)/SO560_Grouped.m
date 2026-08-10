// ============================================================================
// Report 03 - CM Sales Orders < 560 (Not Enough Inventory to Ship)
// QUERY: SO560_Grouped  ->  ONE combined "grouped list" table that reproduces the
//        Cognos List1 render EXACTLY: the SO x Inventory x WO fan-out, the
//        row-span suppression, and the inline blue "<item> - Total" footer rows.
//
// WHY THIS EXISTS (2026-07-10, user-directed):
//   The page originally shipped as four cross-filtered flat tableEx visuals
//   (decision of 2026-07-09, PARITY_TODO.md section 2). The report owner asked for
//   the Cognos grouped-grid look back ("create this pivot table in the visual").
//   A real Power BI matrix still cannot do it (it would destroy the conditional
//   formatting and cross-join the three sibling grains) -- so this is Option A
//   from BUILD.md section 4, upgraded: the Cognos stitch is rebuilt in SQL and one
//   tableEx renders it. The 2026-07-09 matrix rejection stands; this supersedes
//   the four-table layout by a different route.
//
// HOW COGNOS'S RENDER IS REPRODUCED:
//   * FAN-OUT: Cognos "Not Shipping" = Open Orders (1:N) left-joined to Inventory
//     On Hand (0:N) and Work Orders (0:N), both on trimmed 2nd item number. Rows
//     per item = #SO-lines x max(#lots,1) x max(#WOs,1). Reproduced verbatim.
//   * ROW-SPAN: Cognos hides repeated cells with visibility:hidden driven by
//     running counts. Here window functions emit _SuppSO / _SuppInv / _SuppWO
//     flags; DAX font-colour measures paint flagged cells white-on-white (the
//     same trick Cognos itself uses for the Inv/WO Item columns).
//       _SuppSO  : not the first fan-out row of its (Item, Order#, Line#) group
//                  -> hide SO cells. NOTE: Order Date is deliberately EXEMPT in
//                  the visual (Cognos re-renders it on every row -- verified in
//                  the reference screenshot; match the render, not the theory).
//       _SuppInv : 2nd+ SO line of the item (Cognos "Order Count > 1") OR repeat
//                  of the same lot within a line -> hide the 8 inventory cells.
//       _SuppWO  : 2nd+ SO line OR 2nd+ inventory lot (Cognos "Lot Number
//                  Count > 1") -> hide the 8 work-order cells.
//   * FOOTER ROWS: the per-item <listFooter> becomes real UNION ALL rows:
//       Item        = <item> + ' - Total'          (the label Cognos shows)
//       Line#       = COUNT(DISTINCT Order#)        (footer cell 1)
//       Primary Qty = SUM(Primary Qty)              (footer cell 2)
//       Inv Item    = COUNT(DISTINCT AVAIL) as text (footer cell 3 -- Cognos's
//                     Count Distinct(AVAILABLE), quirk preserved, see PARITY_TODO 8-1)
//       AVAIL       = SUM(AVAIL)                    (footer cell 4)
//       WO Item     = COUNT(DISTINCT WO#) as text   (footer cell 5)
//       WO Qty      = SUM(WO Qty)                   (footer cell 6)
//     _IsTotal = 1 drives the blue background + white font in DAX.
//   * ORDER: _Sort = Item + '|0|' + zero-padded row number (details) or
//     Item + '|1|' (total row) -- projected HIDDEN in the visual and used as the
//     only sort, so the total row lands right under its item's rows.
//   * GATE: the Cognos summaryFilter (ordered > available OR available 0/null)
//     is applied in SQL (WHERE on the detail branch, HAVING on the totals
//     branch), so the visual needs no Show Item filter.
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Flat SELECT (UNION ALL of two branches, subqueries only -- no WITH/CTE, which
//   would break the folding wrapper), NO ORDER BY. The three source subqueries
//   are verbatim copies of SO_Not_Shipping.m / Inventory_Availability.m /
//   WorkOrder_Detail.m (whitelist, statuses, +21/+31 day windows, status-gated
//   AVAIL, AVAILABLE CHECK -- see those files for the line-by-line Cognos notes).
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            so.[Plant], so.[Item], so.[Order Date], so.[Order#], so.[Line#],
            so.[Promised Ship], so.[Customer], so.[Next Status], so.[Qty],
            so.[Primary Qty], so.[Lot#],
            inv.[Inv Plant], inv.[Inv Item], inv.[On Hand], inv.[Commit],
            inv.[AVAIL], inv.[Location], inv.[Inv Lot#], inv.[Inv Status],
            wo.[WO Item], wo.[WO Plant], wo.[WO#], wo.[Start], wo.[Requested],
            wo.[WO Qty], wo.[WO Lot#], wo.[WO Status],
            so.[Item] + '|0|' + RIGHT('000000' + CAST(ROW_NUMBER() OVER (
                PARTITION BY so.[Item]
                ORDER BY so.[Order#], so.[Line#], inv.[Location], inv.[Inv Lot#], inv.[Inv Plant], wo.[WO#]
            ) AS varchar(6)), 6)                                     AS [_Sort],
            0                                                        AS [_IsTotal],
            (CASE WHEN ROW_NUMBER() OVER (
                    PARTITION BY so.[Item], so.[Order#], so.[Line#]
                    ORDER BY inv.[Location], inv.[Inv Lot#], inv.[Inv Plant], wo.[WO#]) > 1
                  THEN 1 ELSE 0 END)                                 AS [_SuppSO],
            (CASE WHEN DENSE_RANK() OVER (
                    PARTITION BY so.[Item]
                    ORDER BY so.[Order#], so.[Line#]) > 1
                    OR ROW_NUMBER() OVER (
                    PARTITION BY so.[Item], so.[Order#], so.[Line#], inv.[Location], inv.[Inv Lot#]
                    ORDER BY wo.[WO#]) > 1
                  THEN 1 ELSE 0 END)                                 AS [_SuppInv],
            (CASE WHEN DENSE_RANK() OVER (
                    PARTITION BY so.[Item]
                    ORDER BY so.[Order#], so.[Line#]) > 1
                    OR DENSE_RANK() OVER (
                    PARTITION BY so.[Item], so.[Order#], so.[Line#]
                    ORDER BY inv.[Location], inv.[Inv Lot#]) > 1
                  THEN 1 ELSE 0 END)                                 AS [_SuppWO]
        FROM (
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
        ) so
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(ib.IBMCU))                                   AS [Inv Plant],
                LTRIM(RTRIM(ib.IBLITM))                                  AS [Inv Item],
                il.LIPQOH / 10000.0                                      AS [On Hand],
                il.LIHCOM / 10000.0                                      AS [Commit],
                (CASE WHEN (il.LILOTS IS NULL OR LTRIM(RTRIM(il.LILOTS)) = '')
                      THEN (il.LIPQOH - il.LIHCOM) / 10000.0
                      ELSE 0 END)                                        AS [AVAIL],
                il.LILOCN                                                AS [Location],
                LTRIM(RTRIM(il.LILOTN))                                  AS [Inv Lot#],
                il.LILOTS                                                AS [Inv Status]
            FROM PRODDTA.F4102 ib
            INNER JOIN PRODDTA.F41021 il  ON ib.IBMCU = il.LIMCU AND ib.IBITM = il.LIITM
            INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
            INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('CINC','CIN2','CIN4')
              AND il.LIPQOH / 10000.0 > 0
              AND ( LTRIM(RTRIM(il.LILOTS)) <> '' OR (il.LIPQOH - il.LIHCOM) / 10000.0 > 0 )
        ) inv ON so.[Item] = inv.[Inv Item]
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(wo.WALITM))                                  AS [WO Item],
                LTRIM(RTRIM(wo.WAMMCU))                                  AS [WO Plant],
                wo.WADOCO                                                AS [WO#],
                (CASE WHEN wo.WASTRT > 0
                      THEN DATEADD(DAY, (wo.WASTRT % 1000) - 1, DATEFROMPARTS(1900 + (wo.WASTRT / 1000), 1, 1))
                 END)                                                    AS [Start],
                (CASE WHEN wo.WADRQJ > 0
                      THEN DATEADD(DAY, (wo.WADRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wo.WADRQJ / 1000), 1, 1))
                 END)                                                    AS [Requested],
                wo.WAUORG / 10000.0                                      AS [WO Qty],
                LTRIM(RTRIM(wo.WALOTN))                                  AS [WO Lot#],
                wo.WASRST                                                AS [WO Status]
            FROM PRODDTA.F4801 wo
            INNER JOIN PRODDTA.F4102 ib   ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
            INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
            INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE wo.WASRST IN ('20','30','32','35','40','45','50','90')
              AND wo.WAUORG / 10000.0 > 0
              AND (CASE WHEN wo.WADRQJ > 0
                        THEN DATEADD(DAY, (wo.WADRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wo.WADRQJ / 1000), 1, 1))
                   END) <= DATEADD(DAY, 31, CAST(GETDATE() AS date))
              AND LTRIM(RTRIM(wo.WAMMCU)) IN ('CINC','CIN2','CIN4')
        ) wo ON so.[Item] = wo.[WO Item]
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(ib.IBLITM))                                  AS [Item],
                SUM(CASE WHEN (il.LILOTS IS NULL OR LTRIM(RTRIM(il.LILOTS)) = '')
                         THEN (il.LIPQOH - il.LIHCOM) / 10000.0
                         ELSE 0 END)                                     AS [AvailPerItem]
            FROM PRODDTA.F4102 ib
            INNER JOIN PRODDTA.F41021 il  ON ib.IBMCU = il.LIMCU AND ib.IBITM = il.LIITM
            INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
            INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('CINC','CIN2','CIN4')
              AND il.LIPQOH / 10000.0 > 0
              AND ( LTRIM(RTRIM(il.LILOTS)) <> '' OR (il.LIPQOH - il.LIHCOM) / 10000.0 > 0 )
            GROUP BY LTRIM(RTRIM(ib.IBLITM))
        ) ia ON so.[Item] = ia.[Item]
        WHERE ( so.[Qty Ordered Per Item] > ia.[AvailPerItem]
                OR ia.[AvailPerItem] = 0
                OR ia.[AvailPerItem] IS NULL )

        UNION ALL

        SELECT
            NULL, so2.[Item] + ' - Total', NULL, NULL,
            CAST(COUNT(DISTINCT so2.[Order#]) AS float), NULL, NULL, NULL, NULL,
            SUM(so2.[Primary Qty]), NULL,
            NULL, CAST(ISNULL(MAX(ia2.[LotCnt]), 0) AS varchar(12)), NULL, NULL,
            MAX(ia2.[AvailPerItem]), NULL, NULL, NULL,
            CAST(ISNULL(MAX(wa2.[WOCnt]), 0) AS varchar(12)), NULL, NULL, NULL, NULL,
            MAX(wa2.[WOQtySum]), NULL, NULL,
            so2.[Item] + '|1|', 1, 0, 0, 0
        FROM (
            SELECT
                LTRIM(RTRIM(so.SDLITM))                                  AS [Item],
                so.SDDOCO                                                AS [Order#],
                so.SDPQOR / 10000.0                                      AS [Primary Qty]
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
        ) so2
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(ib.IBLITM))                                  AS [Item],
                SUM(CASE WHEN (il.LILOTS IS NULL OR LTRIM(RTRIM(il.LILOTS)) = '')
                         THEN (il.LIPQOH - il.LIHCOM) / 10000.0
                         ELSE 0 END)                                     AS [AvailPerItem],
                COUNT(DISTINCT (CASE WHEN (il.LILOTS IS NULL OR LTRIM(RTRIM(il.LILOTS)) = '')
                         THEN (il.LIPQOH - il.LIHCOM) / 10000.0
                         ELSE 0 END))                                    AS [LotCnt]
            FROM PRODDTA.F4102 ib
            INNER JOIN PRODDTA.F41021 il  ON ib.IBMCU = il.LIMCU AND ib.IBITM = il.LIITM
            INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
            INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('CINC','CIN2','CIN4')
              AND il.LIPQOH / 10000.0 > 0
              AND ( LTRIM(RTRIM(il.LILOTS)) <> '' OR (il.LIPQOH - il.LIHCOM) / 10000.0 > 0 )
            GROUP BY LTRIM(RTRIM(ib.IBLITM))
        ) ia2 ON so2.[Item] = ia2.[Item]
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(wo.WALITM))                                  AS [Item],
                COUNT(DISTINCT wo.WADOCO)                                AS [WOCnt],
                SUM(wo.WAUORG / 10000.0)                                 AS [WOQtySum]
            FROM PRODDTA.F4801 wo
            INNER JOIN PRODDTA.F4102 ib   ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
            INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
            INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE wo.WASRST IN ('20','30','32','35','40','45','50','90')
              AND wo.WAUORG / 10000.0 > 0
              AND (CASE WHEN wo.WADRQJ > 0
                        THEN DATEADD(DAY, (wo.WADRQJ % 1000) - 1, DATEFROMPARTS(1900 + (wo.WADRQJ / 1000), 1, 1))
                   END) <= DATEADD(DAY, 31, CAST(GETDATE() AS date))
              AND LTRIM(RTRIM(wo.WAMMCU)) IN ('CINC','CIN2','CIN4')
            GROUP BY LTRIM(RTRIM(wo.WALITM))
        ) wa2 ON so2.[Item] = wa2.[Item]
        GROUP BY so2.[Item]
        HAVING ( SUM(so2.[Primary Qty]) > MAX(ia2.[AvailPerItem])
                 OR MAX(ia2.[AvailPerItem]) = 0
                 OR MAX(ia2.[AvailPerItem]) IS NULL )
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
            {"Inv Plant", type text},
            {"Inv Item", type text},
            {"On Hand", type number},
            {"Commit", type number},
            {"AVAIL", type number},
            {"Location", type text},
            {"Inv Lot#", type text},
            {"Inv Status", type text},
            {"WO Item", type text},
            {"WO Plant", type text},
            {"WO#", Int64.Type},
            {"Start", type date},
            {"Requested", type date},
            {"WO Qty", type number},
            {"WO Lot#", type text},
            {"WO Status", type text},
            {"_Sort", type text},
            {"_IsTotal", Int64.Type},
            {"_SuppSO", Int64.Type},
            {"_SuppInv", Int64.Type},
            {"_SuppWO", Int64.Type}
        }
    )
in
    Typed
