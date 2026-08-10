// ============================================================================
// Report 17 - Orders within Goal and Stretch  |  Cognos "Orders within Goal and Stretch"
// Migration tracker ID 137. Prior owner Lilly -> Zack 2026-07-14.
//
// This is the COMMENTED MASTER of the production partition (Orders_GS.tmdl).
// The shipped PBIP carries a comment-free copy (house rule). Keep the two in sync.
//
// ARCHITECTURE (since 2026-07-21 simplification - BUILD.md sec 12.8):
//   SQL (this file)  = FETCH ONLY. Order lines, the two ledger event datetimes,
//                      quantity converted to the item primary UOM, and the
//                      slicer columns. No business logic lives here.
//   DAX (the model)  = ALL business logic, readable in the field list:
//                      [Business Days]  - business days from first 525 to first 540
//                                         (Cognos floored-week formula, WEEKDAY(..,2),
//                                         TRUNC toward zero for T-SQL parity)
//                      [Goal]           - RAME <= 1 bd; REUR/RASI <= 2 bd
//                      [Stretch]        - <= 1 bd
//                      [>48h]           - > 2 bd   (hour labels = business-day thresholds)
//                      [<72h]           - < 3 bd
//                      [>72h]           - > 3 bd
//   The DAX versions were verified cell-identical to the retired SQL CASEs on all
//   1,030 rows of the validated 2026-07-21 tight capture before the swap.
//
// PROMPTS RETIRED (2026-07-21): FromDate/ToDate/BusinessGroup/CSR PQ parameters
//   are gone. The import now carries a ROLLING 365-DAY window on the JDE order
//   entry date (SDTRDJ), and the page filters instead:
//     [Order Entry Date] - Between date slicer (the true order date; the displayed
//                          "Order Date" column is the 525 confirm event - Cognos label quirk)
//     [Business Group]   - dropdown slicer (F0006.MCRP03)
//     [CSR Name]         - dropdown slicer (#csr: earliest F42140 type-'CSR' rep per
//                          TRUE ship-to, mailing name from F0111.WWMLNM; deduped
//                          one-row-per-ship-to so it cannot fan out the grain)
//   The three columns enter the final SELECT as MIN() aggregates so the validated
//   Cognos display grain is UNCHANGED (they are not part of the GROUP BY).
//
// WHAT THE REPORT IS: one row per sales-order LINE that reached BOTH pick-confirm
//   (next status 525) AND ship (next status 540), scored on business days between
//   the earliest 525 and earliest 540 ledger events.
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, batch mode.
//   The 525/540 status EVENTS live only in the sales-order ledger F42199 (ODS-only);
//   that is why this report cannot route via SSAS/EDW.
//
// BATCH / #temp SHAPE (BUILD.md sec 7.2): folding OFF (multi-statement batch).
//   Earliest-event per line = GROUP BY ... MIN(...) - never OUTER APPLY / ROW_NUMBER
//   (those re-evaluate per row on this SQL Server and have hung refreshes - report 14).
//   Ledger extracts are SCOPED to the windowed order set (#ord).
//   #uom is DEDUPED (F41002 has up to 18 rows per (item,from,to) on this ODS; a raw
//   join fanned SUM(qty) 2.3x - BUILD.md sec 12.7). MAX(UMCONV): 23/1048 triples vary.
//
// KEY GRAIN: Cognos display tuple (RULE B group-and-sum). SUM(factored qty),
//   MIN(JDE key) as representative line id.
//
// QUIRKS PORTED VERBATIM (disclose to business - BUILD.md sec 6):
//   - "Ship To" columns display the SOLD-TO code/name (Cognos reuses the sold-to).
//     The TRUE ship-to (SDSHAN) drives the AC01 intercompany filter, the AC06
//     segmentation, and the CSR lookup.
//   - "Order Date" column = earliest 525 (confirm) datetime; "Confirmation Date"
//     column = earliest 540 (ship) datetime. Label overrides faithful to Cognos.
//   - Eligibility: order types S5/ST excluded; cancelled lines excluded on BOTH
//     SDNXTR and SDLTTR = 980 (RULE A - covers cancel-after-complete); companies
//     00024/00025 excluded; AC01='INT' intercompany ship-tos excluded; GST/duty
//     items excluded via global bulk item fallback.
//   - Company Level 2 CASE is the empirically-derived company->region decode
//     (F0006.MCRP02/03 are empty on this ODS). New JDE company => extend the CASE.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        -- (1) #ord : F4211 (open) UNION ALL F42119 (purged history), NOT EXISTS-guarded,
        --     eligibility filters + ROLLING 365-day order-entry window on SDTRDJ.
        SELECT
            o.SDKCOO, o.SDDOCO, o.SDDCTO, o.SDLNID,
            LTRIM(RTRIM(o.SDMCU))                       AS Branch,
            LTRIM(RTRIM(o.SDFRTH))                      AS Freight,
            o.SDAN8, o.SDSHAN,
            LTRIM(RTRIM(o.SDLITM))                      AS Item2nd,
            o.SDITM, o.SDUORG, o.SDUOM, o.SDTRDJ, o.SDDRQJ, o.SDADDJ,
            LTRIM(RTRIM(bu.MCCO))                       AS CompanyCode,
            CASE LTRIM(RTRIM(bu.MCCO)) WHEN '00010' THEN 'RAME' WHEN '00020' THEN 'REUR'
                 WHEN '00030' THEN 'RASI' WHEN '00034' THEN 'RASI' WHEN '00035' THEN 'RASI'
                 ELSE '' END                            AS CompanyLevel2,
            LTRIM(RTRIM(bu.MCRP03))                     AS BusinessGroup
        INTO #ord
        FROM (
            SELECT SDKCOO, SDDOCO, SDDCTO, SDLNID, SDMCU, SDFRTH, SDAN8, SDSHAN, SDLITM, SDITM, SDUORG, SDUOM, SDTRDJ, SDDRQJ, SDADDJ, SDNXTR, SDLTTR
            FROM PRODDTA.F4211
            UNION ALL
            SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDLNID, h.SDMCU, h.SDFRTH, h.SDAN8, h.SDSHAN, h.SDLITM, h.SDITM, h.SDUORG, h.SDUOM, h.SDTRDJ, h.SDDRQJ, h.SDADDJ, h.SDNXTR, h.SDLTTR
            FROM PRODDTA.F42119 h
            WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                              WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID)
        ) o
        LEFT JOIN PRODDTA.F0006 bu ON LTRIM(RTRIM(bu.MCMCU)) = LTRIM(RTRIM(o.SDMCU))
        WHERE o.SDDCTO NOT IN ('S5','ST')
          AND o.SDNXTR <> '980'
          AND o.SDLTTR <> '980'
          AND o.SDTRDJ >= (YEAR(DATEADD(DAY,-365,GETDATE()))-1900)*1000 + DATEPART(DAYOFYEAR,DATEADD(DAY,-365,GETDATE()))
          AND LTRIM(RTRIM(bu.MCCO)) NOT IN ('00024','00025');
        CREATE UNIQUE CLUSTERED INDEX ixo ON #ord (SDKCOO, SDDOCO, SDDCTO, SDLNID);

        -- (2) #l525 : earliest 525 (pick-confirm) event per line, scoped to #ord.
        --     Event datetime = SLUPMJ (Julian date) + SLTDAY (HHMMSS) reconstruction.
        SELECT l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID,
               MIN(DATEADD(SECOND,(l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                           CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))) AS Date525
        INTO #l525
        FROM PRODDTA.F42199 l
        JOIN #ord o ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        WHERE l.SLNXTR = '525' AND l.SLUPMJ > 0
        GROUP BY l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ix5 ON #l525 (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        -- (3) #l540 : earliest 540 (ship) event per line. Same construct.
        SELECT l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID,
               MIN(DATEADD(SECOND,(l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                           CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))) AS Date540
        INTO #l540
        FROM PRODDTA.F42199 l
        JOIN #ord o ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        WHERE l.SLNXTR = '540' AND l.SLUPMJ > 0
        GROUP BY l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ix4 ON #l540 (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        -- (4) #metric : lines that confirmed AND shipped (INNER JOIN). The business-day
        --     math that used to live here is now the DAX [Business Days] column.
        SELECT b.SLKCOO, b.SLDOCO, b.SLDCTO, b.SLLNID, b.Date525, c.Date540
        INTO #metric
        FROM #l525 b
        JOIN #l540 c ON b.SLKCOO = c.SLKCOO AND b.SLDOCO = c.SLDOCO AND b.SLDCTO = c.SLDCTO AND b.SLLNID = c.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ixm ON #metric (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        -- (5) #uom : DEDUPED item pack->primary conversions (sec 12.6/12.7).
        SELECT u.UMITM, LTRIM(RTRIM(u.UMUM)) AS UMUM, LTRIM(RTRIM(u.UMRUM)) AS UMRUM, MAX(u.UMCONV) AS UMCONV
        INTO #uom
        FROM PRODDTA.F41002 u
        WHERE EXISTS (SELECT 1 FROM #ord o WHERE o.SDITM = u.UMITM)
        GROUP BY u.UMITM, LTRIM(RTRIM(u.UMUM)), LTRIM(RTRIM(u.UMRUM));
        CREATE UNIQUE CLUSTERED INDEX ixu ON #uom (UMITM, UMUM, UMRUM);

        -- (6) #csr : earliest type-'CSR' rep per ship-to, one row per CMAN8 (no fan-out).
        SELECT c.CMAN8, MIN(c.CMSLSM) AS CSR_AN8
        INTO #csr
        FROM PRODDTA.F42140 c
        WHERE LTRIM(RTRIM(c.CMRTYPE)) = 'CSR'
        GROUP BY c.CMAN8;
        CREATE UNIQUE CLUSTERED INDEX ixc ON #csr (CMAN8);

        -- (7) FINAL : #ord INNER JOIN #metric + enrichment, grouped to the Cognos
        --     display tuple (RULE B). The three slicer columns are MIN() aggregates,
        --     NOT grain members. Ordered Quantity = order units x SALES_FACTOR
        --     (F41002.UMCONV/1e7, line SDUOM -> item primary IMUOM1; 1 when equal).
        SELECT
            g.[Company Code], g.[Company Name], g.[Branch Plant], g.[Freight Handling Code], g.[Order Number],
            SUM(g.[Ordered Quantity]) AS [Ordered Quantity],
            g.[2nd Item Number],
            g.[Sold To Customer Code], g.[Sold To Customer Name], g.[Ship To Customer Code], g.[Ship To Customer Name],
            g.[Customer Segmentation], g.[Customer Segmentation Description],
            g.[Order Date], g.[Confirmation Date], g.[Shipped Date], g.[Requested Date],
            g.[Company Level 2],
            MIN(g.[JDE Order Line ID]) AS [JDE Order Line ID],
            MIN(g.[Order Entry Date]) AS [Order Entry Date],
            MIN(g.[Business Group]) AS [Business Group],
            MIN(g.[CSR Name]) AS [CSR Name]
        FROM (
        SELECT
            o.CompanyCode                              AS [Company Code],
            LTRIM(RTRIM(co.CCNAME))                    AS [Company Name],
            o.Branch                                   AS [Branch Plant],
            o.Freight                                  AS [Freight Handling Code],
            CAST(o.SDDOCO AS varchar(20))              AS [Order Number],
            (o.SDUORG / 10000.0)
              * CASE WHEN LTRIM(RTRIM(o.SDUOM)) = LTRIM(RTRIM(im.IMUOM1)) THEN 1.0
                     ELSE ISNULL(uom.UMCONV / 10000000.0, 1.0) END AS [Ordered Quantity],
            o.Item2nd                                  AS [2nd Item Number],
            o.SDAN8                                    AS [Sold To Customer Code],
            LTRIM(RTRIM(sold.ABALPH))                  AS [Sold To Customer Name],
            o.SDAN8                                    AS [Ship To Customer Code],
            LTRIM(RTRIM(sold.ABALPH))                  AS [Ship To Customer Name],
            LTRIM(RTRIM(ship.ABAC06))                  AS [Customer Segmentation],
            LTRIM(RTRIM(seg.DRDL01))                   AS [Customer Segmentation Description],
            m.Date525                                  AS [Order Date],
            m.Date540                                  AS [Confirmation Date],
            CASE WHEN o.SDADDJ > 0 THEN DATEADD(DAY,(o.SDADDJ%1000)-1,DATEFROMPARTS(1900+(o.SDADDJ/1000),1,1)) END AS [Shipped Date],
            CASE WHEN o.SDDRQJ > 0 THEN DATEADD(DAY,(o.SDDRQJ%1000)-1,DATEFROMPARTS(1900+(o.SDDRQJ/1000),1,1)) END AS [Requested Date],
            o.CompanyLevel2                            AS [Company Level 2],
            LTRIM(RTRIM(o.SDKCOO)) + '|' + CAST(o.SDDOCO AS varchar(20)) + '|' + LTRIM(RTRIM(o.SDDCTO)) + '|' + CAST(o.SDLNID AS varchar(20)) AS [JDE Order Line ID],
            CASE WHEN o.SDTRDJ > 0 THEN DATEADD(DAY,(o.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(o.SDTRDJ/1000),1,1)) END AS [Order Entry Date],
            o.BusinessGroup                            AS [Business Group],
            LTRIM(RTRIM(csrw.WWMLNM))                  AS [CSR Name]
        FROM #ord o
        JOIN #metric m ON m.SLKCOO = o.SDKCOO AND m.SLDOCO = o.SDDOCO AND m.SLDCTO = o.SDDCTO AND m.SLLNID = o.SDLNID
        LEFT JOIN PRODDTA.F0010 co   ON LTRIM(RTRIM(co.CCCO)) = o.CompanyCode
        LEFT JOIN PRODDTA.F0101 sold ON sold.ABAN8 = o.SDAN8
        LEFT JOIN PRODDTA.F0101 ship ON ship.ABAN8 = o.SDSHAN
        LEFT JOIN PRODCTL.F0005 seg  ON LTRIM(RTRIM(seg.DRSY)) = '01' AND LTRIM(RTRIM(seg.DRRT)) = '06'
                                    AND LTRIM(RTRIM(seg.DRKY)) = LTRIM(RTRIM(ship.ABAC06))
        LEFT JOIN PRODDTA.F554101 tag ON tag.IMITM = o.SDITM
        LEFT JOIN PRODDTA.F4101 im   ON im.IMITM = o.SDITM
        LEFT JOIN #uom uom ON uom.UMITM = o.SDITM
                          AND uom.UMUM  = LTRIM(RTRIM(o.SDUOM))
                          AND uom.UMRUM = LTRIM(RTRIM(im.IMUOM1))
        LEFT JOIN #csr cs ON cs.CMAN8 = o.SDSHAN
        LEFT JOIN PRODDTA.F0111 csrw ON csrw.WWAN8 = cs.CSR_AN8 AND csrw.WWIDLN = 0
        WHERE ISNULL(LTRIM(RTRIM(ship.ABAC01)),'') <> 'INT'
          AND CASE WHEN ISNULL(LTRIM(RTRIM(tag.IMGBLK)),'-') = '-' THEN o.Item2nd ELSE LTRIM(RTRIM(tag.IMGBLK)) END
              NOT IN ('IGST','CGST','SGST','CVD','ADD')
        ) g
        GROUP BY
            g.[Company Code], g.[Company Name], g.[Branch Plant], g.[Freight Handling Code], g.[Order Number],
            g.[2nd Item Number],
            g.[Sold To Customer Code], g.[Sold To Customer Name], g.[Ship To Customer Code], g.[Ship To Customer Name],
            g.[Customer Segmentation], g.[Customer Segmentation Description],
            g.[Order Date], g.[Confirmation Date], g.[Shipped Date], g.[Requested Date],
            g.[Company Level 2];
        ",
        null,
        [EnableFolding = false]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Company Code", type text},
            {"Company Name", type text},
            {"Branch Plant", type text},
            {"Freight Handling Code", type text},
            {"Order Number", type text},
            {"Ordered Quantity", type number},
            {"2nd Item Number", type text},
            {"Sold To Customer Code", Int64.Type},
            {"Sold To Customer Name", type text},
            {"Ship To Customer Code", Int64.Type},
            {"Ship To Customer Name", type text},
            {"Customer Segmentation", type text},
            {"Customer Segmentation Description", type text},
            {"Order Date", type datetime},
            {"Confirmation Date", type datetime},
            {"Shipped Date", type date},
            {"Requested Date", type date},
            {"Company Level 2", type text},
            {"JDE Order Line ID", type text},
            {"Order Entry Date", type date},
            {"Business Group", type text},
            {"CSR Name", type text}
        },
        "en-US"
    )
in
    Typed
