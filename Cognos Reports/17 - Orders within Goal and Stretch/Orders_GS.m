let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        ------------------------------------------------------------------------------
        -- STEP 1: ELIGIBLE ORDER LINES (#ord)
        -- Sales-order lines from F4211 (open) plus F42119 (purged history, so
        -- completed lines stay visible after JDE's nightly purge). F0006 turns the
        -- branch into a company; the CASE decodes the region that drives the Goal
        -- target. Filters: no S5/ST order types, no cancelled lines (980), rolling
        -- 12-month window on order entry date, companies 00024/00025 excluded.
        ------------------------------------------------------------------------------
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

        ------------------------------------------------------------------------------
        -- STEP 2: FIRST PICK-CONFIRM EVENT (#l525)
        -- Sales ledger F42199 = the audit trail of every status change. Keep the
        -- 525 records, rebuild the real timestamp from JDE's Julian date + time,
        -- and take the EARLIEST per order line.
        ------------------------------------------------------------------------------
        SELECT l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID,
               MIN(DATEADD(SECOND,(l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                           CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))) AS Date525
        INTO #l525
        FROM PRODDTA.F42199 l
        JOIN #ord o ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        WHERE l.SLNXTR = '525' AND l.SLUPMJ > 0
        GROUP BY l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ix5 ON #l525 (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        ------------------------------------------------------------------------------
        -- STEP 3: FIRST SHIP EVENT (#l540)
        -- Same thing for status 540.
        ------------------------------------------------------------------------------
        SELECT l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID,
               MIN(DATEADD(SECOND,(l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                           CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))) AS Date540
        INTO #l540
        FROM PRODDTA.F42199 l
        JOIN #ord o ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        WHERE l.SLNXTR = '540' AND l.SLUPMJ > 0
        GROUP BY l.SLKCOO, l.SLDOCO, l.SLDCTO, l.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ix4 ON #l540 (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        ------------------------------------------------------------------------------
        -- STEP 4: PAIR THE TWO EVENTS (#metric)
        -- Inner join = the report's definition of a row: a line must have BOTH a
        -- 525 and a 540 event. The only join in the query that removes rows.
        ------------------------------------------------------------------------------
        SELECT b.SLKCOO, b.SLDOCO, b.SLDCTO, b.SLLNID, b.Date525, c.Date540
        INTO #metric
        FROM #l525 b
        JOIN #l540 c ON b.SLKCOO = c.SLKCOO AND b.SLDOCO = c.SLDOCO AND b.SLDCTO = c.SLDCTO AND b.SLLNID = c.SLLNID;
        CREATE UNIQUE CLUSTERED INDEX ixm ON #metric (SLKCOO, SLDOCO, SLDCTO, SLLNID);

        ------------------------------------------------------------------------------
        -- STEP 5: UNIT CONVERSION FACTORS (#uom)
        -- F41002 converts the line's transaction UOM to the item's primary UOM.
        -- De-duplicated (MAX per item/from/to) because the table holds duplicate
        -- rows on this server.
        ------------------------------------------------------------------------------
        SELECT u.UMITM, LTRIM(RTRIM(u.UMUM)) AS UMUM, LTRIM(RTRIM(u.UMRUM)) AS UMRUM, MAX(u.UMCONV) AS UMCONV
        INTO #uom
        FROM PRODDTA.F41002 u
        WHERE EXISTS (SELECT 1 FROM #ord o WHERE o.SDITM = u.UMITM)
        GROUP BY u.UMITM, LTRIM(RTRIM(u.UMUM)), LTRIM(RTRIM(u.UMRUM));
        CREATE UNIQUE CLUSTERED INDEX ixu ON #uom (UMITM, UMUM, UMRUM);

        ------------------------------------------------------------------------------
        -- STEP 6: CSR PER SHIP-TO (#csr)
        -- One CSR per ship-to customer from F42140.
        ------------------------------------------------------------------------------
        SELECT c.CMAN8, MIN(c.CMSLSM) AS CSR_AN8
        INTO #csr
        FROM PRODDTA.F42140 c
        WHERE LTRIM(RTRIM(c.CMRTYPE)) = 'CSR'
        GROUP BY c.CMAN8;
        CREATE UNIQUE CLUSTERED INDEX ixc ON #csr (CMAN8);

        ------------------------------------------------------------------------------
        -- FINAL ASSEMBLY
        -- Inner select: order lines + the event pair, decorated with name/code
        -- lookups (all LEFT JOINs -- none remove rows). Quantity is converted to the
        -- item's primary UOM. Last two filters: intercompany ship-tos and GST/duty
        -- tax items excluded. Cognos label quirks preserved for parity:
        -- [Order Date] shows the 525 event, [Confirmation Date] shows the 540
        -- event, and the Ship To columns display the sold-to.
        -- Outer GROUP BY: where Cognos shows identical display rows it groups them
        -- and sums quantity -- this reproduces that display grain.
        ------------------------------------------------------------------------------
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
