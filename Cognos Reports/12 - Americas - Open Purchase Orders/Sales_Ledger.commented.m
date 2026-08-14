// ============================================================================
// Report 12 - Americas - Open Purchase Orders  |  PAGE 3 : "Sales Ledger_3"
// QUERY OBJECT: "Sales Ledger"  ->  Cognos list on page 3
//   (10 columns, ~91,613 rendered rows) -- the largest page.
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Sales Order Detail Ledger = PRODDTA.F42199, joined to F4211 (order activity).
//
// COLUMN PREFIX — RESOLVED 2026-07-14: F42199 on this instance uses SL* names
//   (SLDOCO, SLLNID, SLUPMJ, ...). Proven two ways: the first refresh threw
//   "Invalid column name 'SH*'" for every SH column, and the repo's validated
//   `edw_schema\F42199_ledger.sql` reads F42199 with SL* throughout.
//   (JDE-standard SH* was the original guess; F4201 header owns SH*.)
//
// FIELD MAPPING NOTES (post-fix):
//   Ordered Date  -> o.SDTRDJ from the joined F4211 (proven column; the order
//                    date is invariant per line so ledger-vs-order source is
//                    equivalent). F42199 shows no TRDJ in the validated query.
//   Date Created  -> l.SLUPMJ (date part). A ledger row is written once, so its
//                    create date = its update date; the DW exposed both a date
//                    (DATE_CREATED) and a datetime (ORDER_LINE_LAST_UPDATED)
//                    view of the same audit stamp. NOTE: SLADDJ was the old
//                    guess but SLADDJ = Actual Ship Date in JDE — wrong field.
//                    -- TODO verify vs xlsx: if Date Created <> date(Last
//                    Updated) on some rows, revisit this mapping.
//
// Cognos applies SELECT DISTINCT explicitly (Sales Ledger.2.sql) -> kept here.
//
// COGNOS FILTERS (Sales Ledger.2.sql WHERE):
//   Ordered Date >= 2024-01-01                       -> SDTRDJ decoded >= '2024-01-01'
//   Order Company = '00010'                           -> SLKCOO = '00010'
//   Next Status in ('520','525','530')                -> SLNXTR in (...)
//   Order Line Last Updated By NOT IN ('SCHED')       -> SLUSER <> 'SCHED'   (this is the
//        report's "prohibited"/enabled detail filter — its expression was in the
//        truncated part of Report XML.xml but is preserved verbatim in the SQL)
//   decode(GLOBAL_BULK_ITEM,'-',2nd Item,GLOBAL_BULK_ITEM) NOT IN
//        ('IGST','CGST','SGST','CVD','ADD')            -> tax-item exclusion via F554101
//
// JOIN: F42199 -> F4211 on the JDE order key (company+order+type+line). The DW
//   joined SALES_ORDER_LEDGER.ORDER_LINE_ID = ORDER_ACTIVITY.JDE_ORDER_LINE_ID;
//   the JDE-native equivalent is the 4-part order key below.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(l.SLKCOO))            AS [Order Company],
            l.SLDOCO                          AS [Order Number],
            l.SLLNID / 1000.0                 AS [Line Number],
            LTRIM(RTRIM(l.SLLITM))            AS [2nd Item Number],
            CASE WHEN o.SDTRDJ>0 THEN DATEADD(DAY,(o.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(o.SDTRDJ/1000),1,1)) END AS [Ordered Date],
            CASE WHEN l.SLUPMJ>0 THEN DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) END AS [Date Created],
            l.SLLTTR                          AS [Last Status],
            l.SLNXTR                          AS [Next Status],
            CASE WHEN l.SLUPMJ>0 THEN
                DATEADD(SECOND,
                        (l.SLTDAY/10000)*3600 + ((l.SLTDAY/100)%100)*60 + (l.SLTDAY%100),
                        CAST(DATEADD(DAY,(l.SLUPMJ%1000)-1,DATEFROMPARTS(1900+(l.SLUPMJ/1000),1,1)) AS datetime2))
            END                               AS [Order Line Last Updated],
            LTRIM(RTRIM(l.SLUSER))            AS [Order Line Last Updated By]
        FROM PRODDTA.F42199 l
        JOIN (
            -- FIX 2026-07-14 (refresh #3): order activity = F4211 UNION F42119.
            -- Refreshed model had 3,463 ledger rows vs 91,613 in the Cognos xlsx:
            -- shipped/closed lines purge from F4211 into history F42119, and the
            -- DW's ORDER_ACTIVITY covered both (same gotcha as reports 08/10).
            -- F42119 mirrors F4211's SD* column names on this instance (proven
            -- in 10 - Ivan SFC2023 Forecast\Sales_History.m). NOT EXISTS guards
            -- the rare dual-resident line so the join can't fan out.
            SELECT SDKCOO, SDDOCO, SDDCTO, SDLNID, SDMCU, SDLITM, SDTRDJ
            FROM PRODDTA.F4211
            UNION ALL
            SELECT h.SDKCOO, h.SDDOCO, h.SDDCTO, h.SDLNID, h.SDMCU, h.SDLITM, h.SDTRDJ
            FROM PRODDTA.F42119 h
            WHERE NOT EXISTS (SELECT 1 FROM PRODDTA.F4211 c
                              WHERE c.SDKCOO = h.SDKCOO AND c.SDDOCO = h.SDDOCO
                                AND c.SDDCTO = h.SDDCTO AND c.SDLNID = h.SDLNID)
        ) o   ON o.SDKCOO = l.SLKCOO AND o.SDDOCO = l.SLDOCO
             AND o.SDDCTO = l.SLDCTO AND o.SDLNID = l.SLLNID
        JOIN PRODDTA.F4102 it ON LTRIM(RTRIM(o.SDMCU))  = LTRIM(RTRIM(it.IBMCU))
                            AND LTRIM(RTRIM(o.SDLITM)) = LTRIM(RTRIM(it.IBLITM))
        LEFT JOIN PRODDTA.F4101 im   ON it.IBITM = im.IMITM
        LEFT JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE CASE WHEN o.SDTRDJ>0 THEN DATEADD(DAY,(o.SDTRDJ%1000)-1,DATEFROMPARTS(1900+(o.SDTRDJ/1000),1,1)) END >= '2024-01-01'
          AND LTRIM(RTRIM(l.SLKCOO)) = '00010'
          AND LTRIM(RTRIM(l.SLNXTR)) IN ('520','525','530')
          AND LTRIM(RTRIM(l.SLUSER)) <> 'SCHED'
          AND CASE WHEN ISNULL(LTRIM(RTRIM(tag.IMGBLK)),'-')='-'
                   THEN LTRIM(RTRIM(o.SDLITM)) ELSE LTRIM(RTRIM(tag.IMGBLK)) END
              NOT IN ('IGST','CGST','SGST','CVD','ADD')
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Order Company", type text},
            {"Order Number", Int64.Type},
            {"Line Number", type number},
            {"2nd Item Number", type text},
            {"Ordered Date", type date},
            {"Date Created", type date},
            {"Last Status", type text},
            {"Next Status", type text},
            {"Order Line Last Updated", type datetime},
            {"Order Line Last Updated By", type text}
        },
        "en-US"
    )
in
    Typed
