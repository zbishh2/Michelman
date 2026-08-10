// ============================================================================
// Report 08 - Ivan SK 2023 Forecast   ->   PAGE "Forecast"
// (structural CLONE of report 10 - Ivan FC 2023 Forecast; differs ONLY in the
//  item whitelist + the branch-plant filter, both taken from 08's raw Cognos SQL)
// QUERY: Forecast  ->  Cognos "Forecast" query (raw SQL block 1,
//        DW_LEGACY.INVENTORY_DEMAND / INVENTORY_DEMAND_MEASURES star schema,
//        TABLE_TYPE like '%3460%' + FORECAST_TYPE='SA').
//
// ############################################################################
// #  !!!  UNVALIDATED  -  BEST EFFORT  -  READ BEFORE SHIPPING  !!!          #
// #                                                                          #
// #  The validation export (Ivan Reports\Ivan SK 2023 Forecast.xlsx, sheet   #
// #  "Forecast_1") is EMPTY (A1:A1) - there is NOTHING to tie this query to. #
// #                                                                          #
// #  DW_LEGACY.INVENTORY_DEMAND (TABLE_TYPE '%3460%') = the JDE FORECAST FILE #
// #  F3460.  We rebuilt it best-effort on PRODDTA.F3460.  SEVERAL F3460 FIELD #
// #  NAMES AND THE QUANTITY SCALING ARE UNCONFIRMED - every uncertain field   #
// #  carries a  -- TODO verify  comment.  A human with JDE access MUST check  #
// #  the F3460 aliases (FTFQT, FTDRQJ, FTAN8), the /10000 scaling, and the    #
// #  Revenue-Business-Unit / Company-Code derivations before this page is     #
// #  trusted.  See BUILD.md -> "ASSUMPTIONS & VALIDATION RISKS".              #
// ############################################################################
//
// SOURCE: ODSPROD / ODS, SQL Server.  Native T-SQL, folds.  House pattern =
//   05 - CM Inventory on Hand\CM_Inventory_on_Hand.m.
//
// COLUMNS (Report XML "Forecast" list order, 19):
//   Company Code | Branch Plant | Global Bulk Item | Bulk Item |
//   2nd Item Number | Year | Month | Week | Requested Date |
//   Current Forecast KG | Revenue Business Unit | Customer Code |
//   Customer Name | Global Parent | Global Parent Name | TM Name |
//   Current Forecast | Primary UOM | Current Forecast LB
//
// DW -> JDE FIELD MAP (F3460 = ft, F554101 item-tag = tag, F4101 item-master = im):
//   Company Code           COMPANY.COMPANY_CODE (excl 00024/00025) -> F0006.MCCO of branch   -- TODO verify
//   Branch Plant           COMPANYBRANCH_PLANT      -> ft.MFMCU
//   Global Bulk Item       ITEM.GLOBAL_BULK_ITEM    -> tag.IMGBLK
//   Bulk Item              ITEM.BULK_ITEM           -> tag.IMBULK
//   2nd Item Number        ITEM.ITEM_NUMBER_2ND     -> ft.MFLITM
//   Requested Date         REQUESTED_DATE__GREG     -> ft.MFDRQJ (Julian)                     -- TODO verify (FTDRQJ vs FTRQDJ)
//   Current Forecast       sum(CURRENT_FORECAST)    -> sum(ft.MFFQT)                          -- TODO verify field + /10000 scaling
//   Current Forecast KG    sum(CURRENT_FORECAST*CONV_KG) -> KG CASE on primary UOM im.IMUOM1
//   Current Forecast LB    sum(CURRENT_FORECAST*CONV_LB) -> LB CASE on primary UOM im.IMUOM1
//   Revenue Business Unit  ORGANIZATION_RBU.CODE     -> ft.MFMCU (placeholder; F3460 has no distinct RBU) -- TODO verify
//   Customer Code          CUSTOMER.CUSTOMER_CODE    -> ft.MFAN8 (forecast address #)         -- TODO verify populated
//   Customer Name          CUSTOMER.CUSTOMER_NAME    -> F0101(cust).ABALPH
//   Global Parent          CUSTOMER.GLOBAL_REPORTING -> F0101(cust).ABAN86
//   Global Parent Name     CUSTOMER(GP).CUSTOMER_NAME-> F0101(gp).ABALPH
//   TM Name                VENDOR.MAILING_NAME/SALES_REP -> GTM rep via F0006+F42140+F0101 (as Sales_History.m)
//   Primary UOM            UNIT_OF_MEASURE__PRIMARY  -> im.IMUOM1
//
// KG/LB CONVERSION: same house CASE as Sales_History.m (keyed on primary UOM
//   im.IMUOM1; KG->LB factor 2.2045992).
//
// DW FILTERS -> F3460 equivalents:
//   FORECAST_TYPE = 'SA'                 -> ft.MFTYPF = 'SA'
//   TABLE_TYPE like '%3460%'             -> (no-op: we ARE on F3460)
//   CURRENT_FORECAST > 0                 -> ft.MFFQT > 0                                       -- TODO verify scaling
//   RELOAD_KEY = 'N'                     -> (no F3460 equivalent; omitted - document)
//   REQUESTED_DATE between first-of-this-month and 2026-06-30
//                                        -> converted MFDRQJ BETWEEN DATEADD(DAY,1,EOMONTH(GETDATE(),-1)) AND EOMONTH(GETDATE())   [end made dynamic 2026-07-05; Cognos hard-coded 2026-06-30]
//   Bulk Item in (whitelist)            -> tag.IMBULK IN (...)   (SK item family)
//   COMPANYBRANCH_PLANT in (SK branch list) -> ft.MFMCU IN ('AUBA','AUB2','SING','SNG4','MUM3','SHAN','CINC','CIN2','CIN4')
//        (NOTE: report 10/FC excludes CINC/CIN2; SK 08 uses a POSITIVE include list
//         that DOES include CINC/CIN2 - taken verbatim from 08's raw Cognos SQL)
//   (COMPANY exclusion 00024/00025)      -> ISNULL(bu.MCCO,'') NOT IN ('00024','00025')       -- TODO verify
//
// FOLDING: no leading WITH, no ORDER BY (sort set in the VISUAL:
//   Requested Date ascending). Nested derived table only. See BUILD.md.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            b.CompanyCode                                    AS [Company Code],
            b.Branch                                         AS [Branch Plant],
            b.GlobalBulkItem                                 AS [Global Bulk Item],
            b.BulkItem                                       AS [Bulk Item],
            b.SecondItem                                     AS [2nd Item Number],
            DATEPART(YEAR,     b.RequestedDate)              AS [Year],
            DATEPART(MONTH,    b.RequestedDate)              AS [Month],
            DATEPART(ISO_WEEK, b.RequestedDate)              AS [Week],
            b.RequestedDate                                  AS [Requested Date],
            CASE WHEN MIN(b.PrimUOM) = 'LB' THEN SUM(b.q) * 0.453593
                 WHEN MIN(b.PrimUOM) = 'KG' THEN SUM(b.q)
                 WHEN MIN(b.PrimUOM) = 'EA' THEN SUM(b.q) * 20
                 ELSE SUM(b.q)
            END                                              AS [Current Forecast KG],
            b.RevBU                                          AS [Revenue Business Unit],
            b.CustCode                                       AS [Customer Code],
            b.CustName                                       AS [Customer Name],
            b.GlobalParent                                   AS [Global Parent],
            b.GlobalParentName                               AS [Global Parent Name],
            b.TMName                                         AS [TM Name],
            SUM(b.q)                                         AS [Current Forecast],
            b.PrimUOM                                        AS [Primary UOM],
            CASE WHEN MIN(b.PrimUOM) = 'LB' THEN SUM(b.q)
                 WHEN MIN(b.PrimUOM) = 'KG' THEN SUM(b.q) * 2.2045992
                 WHEN MIN(b.PrimUOM) = 'EA' THEN SUM(b.q) * 44
                 ELSE SUM(b.q)
            END                                              AS [Current Forecast LB]
        FROM (
            SELECT
                ISNULL(LTRIM(RTRIM(bu.MCCO)), '')            AS CompanyCode,             -- TODO verify company-code source
                LTRIM(RTRIM(ft.MFMCU))                       AS Branch,
                LTRIM(RTRIM(tag.IMGBLK))                     AS GlobalBulkItem,
                LTRIM(RTRIM(tag.IMBULK))                     AS BulkItem,
                LTRIM(RTRIM(ft.MFLITM))                      AS SecondItem,
                CASE WHEN ft.MFDRQJ > 0                                                    -- TODO verify FTDRQJ is the forecast/requested date
                     THEN DATEADD(DAY, (ft.MFDRQJ % 1000) - 1, DATEFROMPARTS(1900 + (ft.MFDRQJ / 1000), 1, 1))
                     ELSE NULL
                END                                          AS RequestedDate,
                ft.MFFQT / 10000.0                           AS q,                        -- TODO verify FTFQT name AND /10000 scaling
                LTRIM(RTRIM(im.IMUOM1))                       AS PrimUOM,
                LTRIM(RTRIM(ft.MFMCU))                        AS RevBU,                    -- TODO verify RBU (F3460 has no distinct revenue BU)
                LTRIM(RTRIM(CAST(ft.MFAN8 AS varchar(20))))  AS CustCode,                 -- TODO verify FTAN8
                LTRIM(RTRIM(cust.ABALPH))                    AS CustName,
                cust.ABAN86                                  AS GlobalParent,
                LTRIM(RTRIM(gp.ABALPH))                      AS GlobalParentName,
                ISNULL(NULLIF(LTRIM(RTRIM(srn.ABALPH)), ''), 'Not Available') AS TMName
            FROM PRODDTA.F3460 ft
            INNER JOIN PRODDTA.F554101 tag ON tag.IMITM = ft.MFITM
            INNER JOIN PRODDTA.F4101 im    ON im.IMITM = ft.MFITM
            LEFT  JOIN PRODDTA.F0006 bu    ON bu.MCMCU = ft.MFMCU
            LEFT  JOIN PRODDTA.F0101 cust  ON cust.ABAN8 = ft.MFAN8
            LEFT  JOIN PRODDTA.F0101 gp    ON gp.ABAN8 = cust.ABAN86
            LEFT  JOIN PRODDTA.F42140 sr   ON sr.CMAN8 = ft.MFAN8
                                          AND LTRIM(RTRIM(sr.CMRTYPE)) = LTRIM(RTRIM(ISNULL(bu.MCRP01, '-'))) + 'GTM'
            LEFT  JOIN PRODDTA.F0101 srn   ON srn.ABAN8 = sr.CMSLSM
            WHERE LTRIM(RTRIM(ft.MFTYPF)) = 'SA'
              AND ft.MFFQT > 0
              AND ISNULL(LTRIM(RTRIM(bu.MCCO)), '') NOT IN ('00024', '00025')
              AND LTRIM(RTRIM(ft.MFMCU)) IN ('AUBA', 'AUB2', 'SING', 'SNG4', 'MUM3', 'SHAN', 'CINC', 'CIN2', 'CIN4')
              AND LTRIM(RTRIM(tag.IMBULK)) IN ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960')
        ) b
        WHERE b.RequestedDate >= DATEADD(DAY, 1, EOMONTH(CAST(GETDATE() AS date), -1))
          AND b.RequestedDate <= EOMONTH(CAST(GETDATE() AS date))
        GROUP BY
            b.CompanyCode,
            b.Branch,
            b.GlobalBulkItem,
            b.BulkItem,
            b.SecondItem,
            DATEPART(YEAR,     b.RequestedDate),
            DATEPART(MONTH,    b.RequestedDate),
            DATEPART(ISO_WEEK, b.RequestedDate),
            b.RequestedDate,
            b.RevBU,
            b.CustCode,
            b.CustName,
            b.GlobalParent,
            b.GlobalParentName,
            b.TMName,
            b.PrimUOM
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Company Code", type text},
            {"Branch Plant", type text},
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Year", Int64.Type},
            {"Month", Int64.Type},
            {"Week", Int64.Type},
            {"Requested Date", type date},
            {"Current Forecast KG", type number},
            {"Revenue Business Unit", type text},
            {"Customer Code", type text},
            {"Customer Name", type text},
            {"Global Parent", Int64.Type},
            {"Global Parent Name", type text},
            {"TM Name", type text},
            {"Current Forecast", type number},
            {"Primary UOM", type text},
            {"Current Forecast LB", type number}
        },
        "en-US"
    )
in
    Typed
