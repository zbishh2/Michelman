// ============================================================================
// Report 08 - Ivan SK 2023 Forecast   ->   PAGE "Sales History"
// (structural CLONE of report 10 - Ivan FC 2023 Forecast; differs ONLY in the
//  item whitelist + the DUE_DATE start date, both taken from 08's raw Cognos SQL)
// QUERY: Sales_History  ->  Cognos "Sales History" query (raw SQL block 2,
//        DW_LEGACY.ORDER_ACTIVITY / ORDER_ACTIVITY_MEASURES star schema).
//
// ****************************************************************************
// *  THIS REPORT WAS REBUILT OFF ODSPROD / PRODDTA (base JDE tables) in     *
// *  T-SQL.  The Cognos original reads the DW_LEGACY Oracle data warehouse   *
// *  (dimensional star schema); we do NOT have a DW_LEGACY connection, so    *
// *  every DW column is reverse-mapped to its underlying JDE F-table field.  *
// *  See BUILD.md -> "DW -> JDE MAPPING" and "ASSUMPTIONS & VALIDATION RISKS"*
// ****************************************************************************
//
// VALIDATION TARGET: Ivan Reports\Ivan SK 2023 Forecast.xlsx, sheet
//   "Sales History_2" = 881 data rows, 25 columns (headers below).
//   SCOPE (2026-07-06): the F4211-only build came back at 113 rows because
//   completed/closed lines (next status 999) back to Mar-2026 have been PURGED
//   from F4211 into the sales-history file F42119.  Per BUILD.md risk #2 (and
//   exactly as already applied to report 10) we now read
//   F4211 UNION ALL F42119 so the query sees both open and purged history.
//   Row count will be near -- not exactly -- 881, since the export was a
//   point-in-time snapshot.
//
// SOURCE: ODSPROD / ODS, SQL Server.  Native T-SQL, folds.  House pattern =
//   05 - CM Inventory on Hand\CM_Inventory_on_Hand.m and the F4211 rebuild in
//   09 - Ivan FC 2023\Generated SQL (Cognos - raw).sql (block 3).
//
// COLUMNS (export/render order, 25):
//   Order Company | Branch Plant | Global Bulk Item | Bulk Item |
//   2nd Item Number | Order Number | Next Status | Year | Month | Week |
//   Promised Ship Date | Ordered Quantity KGs | Revenue Business Unit |
//   Customer Code | Customer Name | Global Parent | Global Parent Name |
//   TM Name | Country Name | Order Number(dup) | Ordered Quantity |
//   Ordering Unit of Measure | Ordered Quantity LBs | Open Indicator | DATE
//   NOTE: the Cognos list prints "Order Number" TWICE (cols 6 and 20).  Power
//   Query cannot hold two columns of the same name, so we emit it ONCE here and
//   the visual repeats the field.  See BUILD.md.
//
// DW -> JDE FIELD MAP (F4211 = sd, F554101 item-tag = tag):
//   Order Company            substr(ORDER_LINE_ID,1,5)      -> sd.SDKCOO
//   Branch Plant             ORGANIZATION_ID                -> sd.SDMCU
//   Global Bulk Item         ITEM.GLOBAL_BULK_ITEM          -> tag.IMGBLK
//   Bulk Item                ITEM.BULK_ITEM                 -> tag.IMBULK
//   2nd Item Number          ITEM_NUMBER_2ND                -> sd.SDLITM
//   Order Number             ORDER_NUMBER                   -> sd.SDDOCO
//   Next Status              NEXT_STATUS                    -> sd.SDNXTR
//   Promised Ship Date       DUE_DATE                       -> sd.SDPDDJ (Julian)
//   Revenue Business Unit    REVENUE_BUSINESS_UNIT          -> sd.SDEMCU
//   Customer Code            CUSTOMER_SHIP_TO.CUSTOMER_CODE -> sd.SDSHAN (ship-to A/B #)
//   Customer Name            CUSTOMER_SHIP_TO.CUSTOMER_NAME -> F0101(shipto).ABALPH
//   Global Parent            CUSTOMER_SHIP_TO.GLOBAL_REPORTING -> F0101(shipto).ABAN86
//   Global Parent Name       CUSTOMER(GP).CUSTOMER_NAME     -> F0101(gp).ABALPH  (ABAN8=ABAN86)
//   TM Name                  VENDOR.MAILING_NAME/SALES_REP  -> GTM sales rep via F0006+F42140+F0101 (see below)
//   Country Name             CATEGORY_CODES_UDC.DESCRIPTION -> F0005 decode of F0116.ALCTR (00/CN)
//   Ordered Quantity         sum(ORDERED_QTY*SALES_FACTOR)  -> sum(sd.SDPQOR/10000)
//   Ordering Unit of Measure ORDERING_UNIT_OF_MEASURE       -> sd.SDUOM (transaction UOM, e.g. 'TO')
//   Ordered Quantity KGs     sum(ORDERED_QTY*CONV_KG*SF)    -> KG CASE on primary UOM sd.SDUOM1
//   Ordered Quantity LBs     sum(ORDERED_QTY*CONV_LB*SF)    -> LB CASE on primary UOM sd.SDUOM1
//   Open Indicator           OPEN_INDICATOR                 -> derived from next status (see below)
//   DATE                     current_timestamp              -> GETDATE()
//
// KG/LB CONVERSION (house pattern; keyed on PRIMARY UOM = sd.SDUOM1, applied to
//   the summed primary quantity sd.SDPQOR/10000):
//     KG:  LB -> q*0.453593   KG -> q          EA -> q*20   else q
//     LB:  LB -> q            KG -> q*2.2045992 EA -> q*44   else q
//   The KG->LB factor 2.2045992 (NOT 1/0.453593 = 2.204598) is used because the
//   Cognos export ties EXACTLY on it: row1 10000 KG -> 22045.992 LB.  Verified
//   against sheet "Sales History_2" sample rows.  See BUILD.md.
//
// DW FILTERS -> F4211 equivalents (each documented in BUILD.md):
//   LINE_TYPE not like '%F%'          -> sd.SDLNTY NOT LIKE '%F%'  (exclude freight/free)
//   CANCELLED_INDICATOR <> 'Y'        -> sd.SDCNDJ = 0             (no cancel date = not cancelled)
//   ORDERED_QTY*CONV_KG*SALES_FACTOR>0-> sd.SDPQOR/10000.0 > 0     (SALES_FACTOR treated = 1; sign lives in SDPQOR)
//   BUDGET_FACTOR <> 1                -> (no-op: F4211 holds only actual SO lines, no budget pseudo-lines)
//   DUE_DATE between 2026-03-01 and EOM(sysdate+180) -> converted SDPDDJ range (outer WHERE)
//        (NOTE: report 10/FC starts 2025-11-01; SK 08 starts 2026-03-01 - verbatim from 08's raw SQL)
//   Bulk Item in (whitelist)          -> tag.IMBULK IN (...)
//   decode(GLOBAL_BULK_ITEM,'-',2ND,GBI) not in India-GST codes -> reproduced CASE
//
// TM NAME (GTM sales rep) reproduces report 09's F4211 derivation:
//   region prefix = F0006.MCRP01 of the revenue BU (sd.SDEMCU); rep-type = region||'GTM';
//   look up F42140 (CMAN8 = ship-to, CMRTYPE = that) -> CMSLSM -> F0101.ABALPH.
//   Default 'Not Available' when no GTM rep (matches the export's blank rows).
//
// FOLDING: no leading WITH, no ORDER BY (sort set in the VISUAL:
//   Promised Ship Date ascending). Nested derived table only. See BUILD.md.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            b.OrderCompany                                   AS [Order Company],
            b.Branch                                         AS [Branch Plant],
            b.GlobalBulkItem                                 AS [Global Bulk Item],
            b.BulkItem                                       AS [Bulk Item],
            b.SecondItem                                     AS [2nd Item Number],
            b.OrderNumber                                    AS [Order Number],
            b.NextStatus                                     AS [Next Status],
            DATEPART(YEAR,     b.PromisedDate)               AS [Year],
            DATEPART(MONTH,    b.PromisedDate)               AS [Month],
            DATEPART(ISO_WEEK, b.PromisedDate)               AS [Week],
            b.PromisedDate                                   AS [Promised Ship Date],
            CASE WHEN MIN(b.PrimUOM) = 'LB' THEN SUM(b.q) * 0.453593
                 WHEN MIN(b.PrimUOM) = 'KG' THEN SUM(b.q)
                 WHEN MIN(b.PrimUOM) = 'EA' THEN SUM(b.q) * 20
                 ELSE SUM(b.q)
            END                                              AS [Ordered Quantity KGs],
            b.RevBU                                          AS [Revenue Business Unit],
            b.CustCode                                       AS [Customer Code],
            b.CustName                                       AS [Customer Name],
            b.GlobalParent                                   AS [Global Parent],
            b.GlobalParentName                               AS [Global Parent Name],
            b.TMName                                         AS [TM Name],
            b.CountryName                                    AS [Country Name],
            SUM(b.q)                                         AS [Ordered Quantity],
            b.OrderingUOM                                    AS [Ordering Unit of Measure],
            CASE WHEN MIN(b.PrimUOM) = 'LB' THEN SUM(b.q)
                 WHEN MIN(b.PrimUOM) = 'KG' THEN SUM(b.q) * 2.2045992
                 WHEN MIN(b.PrimUOM) = 'EA' THEN SUM(b.q) * 44
                 ELSE SUM(b.q)
            END                                              AS [Ordered Quantity LBs],
            b.OpenIndicator                                  AS [Open Indicator],
            GETDATE()                                        AS [DATE]
        FROM (
            SELECT
                LTRIM(RTRIM(sd.SDKCOO))                      AS OrderCompany,
                LTRIM(RTRIM(sd.SDMCU))                       AS Branch,
                LTRIM(RTRIM(tag.IMGBLK))                     AS GlobalBulkItem,
                LTRIM(RTRIM(tag.IMBULK))                     AS BulkItem,
                LTRIM(RTRIM(sd.SDLITM))                      AS SecondItem,
                sd.SDDOCO                                    AS OrderNumber,
                LTRIM(RTRIM(sd.SDNXTR))                      AS NextStatus,
                CASE WHEN sd.SDPDDJ > 0
                     THEN DATEADD(DAY, (sd.SDPDDJ % 1000) - 1, DATEFROMPARTS(1900 + (sd.SDPDDJ / 1000), 1, 1))
                     ELSE NULL
                END                                          AS PromisedDate,
                sd.SDPQOR / 10000.0                          AS q,
                LTRIM(RTRIM(sd.SDUOM1))                      AS PrimUOM,
                LTRIM(RTRIM(sd.SDUOM))                       AS OrderingUOM,
                LTRIM(RTRIM(sd.SDEMCU))                      AS RevBU,
                LTRIM(RTRIM(CAST(sd.SDSHAN AS varchar(20)))) AS CustCode,
                LTRIM(RTRIM(shipto.ABALPH))                  AS CustName,
                shipto.ABAN86                                AS GlobalParent,
                LTRIM(RTRIM(gp.ABALPH))                      AS GlobalParentName,
                ISNULL(NULLIF(LTRIM(RTRIM(srn.ABALPH)), ''), 'Not Available') AS TMName,
                LTRIM(RTRIM(ctry.DRDL01))                    AS CountryName,
                CASE WHEN LTRIM(RTRIM(sd.SDNXTR)) = '999' THEN 'N' ELSE 'Y' END AS OpenIndicator
            FROM (
                -- Open / recent lines still in F4211 ...
                SELECT SDKCOO, SDMCU, SDLITM, SDDOCO, SDNXTR, SDPDDJ, SDPQOR,
                       SDUOM1, SDUOM, SDEMCU, SDSHAN, SDITM, SDLNTY, SDCNDJ
                FROM PRODDTA.F4211
                UNION ALL
                -- ... plus completed lines already purged into sales history F42119.
                -- On THIS ODSPROD instance F42119 mirrors F4211 with the SAME SD* column
                -- names (NOT the JDE-standard SH prefix) -- confirmed by ssasprod.bim
                -- (Sales fact = F4211|F42119 on F4211/F42119.SDDGL, SDAN8, SDPA8, SDSHAN).
                SELECT SDKCOO, SDMCU, SDLITM, SDDOCO, SDNXTR, SDPDDJ, SDPQOR,
                       SDUOM1, SDUOM, SDEMCU, SDSHAN, SDITM, SDLNTY, SDCNDJ
                FROM PRODDTA.F42119
            ) sd
            INNER JOIN PRODDTA.F554101 tag ON tag.IMITM = sd.SDITM
            LEFT  JOIN PRODDTA.F0101 shipto ON shipto.ABAN8 = sd.SDSHAN
            LEFT  JOIN PRODDTA.F0101 gp     ON gp.ABAN8 = shipto.ABAN86
            LEFT  JOIN PRODDTA.F0116 addr   ON addr.ALAN8 = sd.SDSHAN
            LEFT  JOIN PRODCTL.F0005 ctry   ON LTRIM(RTRIM(ctry.DRKY)) = LTRIM(RTRIM(addr.ALCTR))
                                           AND ctry.DRSY = '00  '
                                           AND ctry.DRRT = 'CN'
            LEFT  JOIN PRODDTA.F0006 bu     ON bu.MCMCU = sd.SDEMCU
            LEFT  JOIN PRODDTA.F42140 sr    ON sr.CMAN8 = sd.SDSHAN
                                           AND LTRIM(RTRIM(sr.CMRTYPE)) = LTRIM(RTRIM(ISNULL(bu.MCRP01, '-'))) + 'GTM'
            LEFT  JOIN PRODDTA.F0101 srn    ON srn.ABAN8 = sr.CMSLSM
            WHERE sd.SDLNTY NOT LIKE '%F%'
              AND sd.SDCNDJ = 0
              AND sd.SDPQOR / 10000.0 > 0
              AND LTRIM(RTRIM(tag.IMBULK)) IN ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S', 'DPI8600.E', 'PH00007E.E', '201250PX.E', 'DPI8200.E', 'MF4915.E', 'MFHS1130.E', 'MFP1857.E', 'MP3000.E', 'MP48525R.E', 'MP4932.E', 'MP498340R.E', 'PH00017E.E', 'MFP1853R.E', 'MP498345P.E', 'MP4983RHSA.E', '201081CX', '241083PX.S', '241088PX.S', '241089PX.S', '241199PX.S', '241252PX.S', '251095NX.S', '251142PX.S', '251144PX.S', '251194NX.S', '251268PX.S', 'MF1204.S', 'MF1306D.S', 'MF1406.S', 'MFHS1881.S', 'MFP1853R.S', 'MFP1883.S', 'MP4982SC.S', 'MP498340R.S', 'MP498345N.S', 'MP4983R.S', 'MP4983RHS.S', 'PH00017E.S', 'PI8545.S', '241253PX.S', '241168PX', '241201FX', 'DP040', 'DPI8600', 'HSCF280', 'ILP040', 'KHI205', 'KHI340', 'MED310', 'MED800', 'MFHS168', 'MFHS268', 'MFP1853R', 'MP04422R', 'MP3000', 'MP48525R', 'MP498340D', 'MP498340R', 'MP498345N', 'MP4983RHS', 'MT242AF', 'PA845H', 'PH00015E', 'PH00017E', 'UBD211', 'UBD268', 'UTS610', '251379PX.E', 'MFP1883.E', 'MP4983RAM.E', 'PH00001A.E', '251095NX.E', '251194NX.E', 'MD7900.E', 'MP4983R.E', '251246NX.E', '251095NX', '251194NX', '261044NX', '261074NX', '605000007', 'MFP1883', 'MP4983R', 'MP4983RN', 'RM108', 'UPR420', '221247PX.E', 'MP2960.E', '221247PX', '231093FX', 'MP2960')
              AND CASE WHEN LTRIM(RTRIM(tag.IMGBLK)) = '-' THEN LTRIM(RTRIM(sd.SDLITM)) ELSE LTRIM(RTRIM(tag.IMGBLK)) END NOT IN ('IGST', 'CGST', 'SGST', 'CVD', 'ADD')
        ) b
        WHERE b.PromisedDate >= '2026-03-01'
          AND b.PromisedDate <= EOMONTH(DATEADD(DAY, 180, CAST(GETDATE() AS date)))
        GROUP BY
            b.OrderCompany,
            b.Branch,
            b.GlobalBulkItem,
            b.BulkItem,
            b.SecondItem,
            b.OrderNumber,
            b.NextStatus,
            DATEPART(YEAR,     b.PromisedDate),
            DATEPART(MONTH,    b.PromisedDate),
            DATEPART(ISO_WEEK, b.PromisedDate),
            b.PromisedDate,
            b.RevBU,
            b.CustCode,
            b.CustName,
            b.GlobalParent,
            b.GlobalParentName,
            b.TMName,
            b.CountryName,
            b.OrderingUOM,
            b.OpenIndicator
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order Company", type text},
            {"Branch Plant", type text},
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"Order Number", Int64.Type},
            {"Next Status", type text},
            {"Year", Int64.Type},
            {"Month", Int64.Type},
            {"Week", Int64.Type},
            {"Promised Ship Date", type date},
            {"Ordered Quantity KGs", type number},
            {"Revenue Business Unit", type text},
            {"Customer Code", type text},
            {"Customer Name", type text},
            {"Global Parent", Int64.Type},
            {"Global Parent Name", type text},
            {"TM Name", type text},
            {"Country Name", type text},
            {"Ordered Quantity", type number},
            {"Ordering Unit of Measure", type text},
            {"Ordered Quantity LBs", type number},
            {"Open Indicator", type text},
            {"DATE", type datetime}
        },
        "en-US"
    )
in
    Typed
