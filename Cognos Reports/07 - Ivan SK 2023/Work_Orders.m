// ============================================================================
// Report 07 - Ivan SK 2023   (page 2 of 5: "Work Order")   [structural clone of report 09; SK filter literals]
// QUERY: Work Orders  ->  Cognos list "List4", query object "Work Orders"
//
// Columns (RENDERED order, 22): REGION | STATE | Branch Plant | WO Number |
//   Global Bulk Item | Bulk Item | 2nd Item Number | WO Status | Start Date |
//   Completed Date | Quantity Requested | Quantity Completed |
//   Component 2nd Item Number | Component UOM | REQUEST KG | COMPLETE KG |
//   P7 ISSUED KG | P7 ORDERED KG | P7 ISSUED LB | P7 ORDERED LB | P7 REMAINING | DATE
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//
// SHAPE (faithful to the Cognos window-fn FAN-OUT - statement 2 of the raw SQL):
//   TWO-LEVEL query (kept exactly as Cognos emitted it):
//     inner "FO" = a flat SELECT over 5 PRODDTA tables with NO GROUP BY, carrying
//       SUM()/AVG() window functions OVER a big PARTITION (the WO x component grain).
//       This is the Cognos fan-out: one output row per source (WO-line x part) row,
//       each row carrying the partition-level aggregates. Reproduced verbatim.
//     outer "OUT" = SELECT computing the rendered columns from FO, with the outer
//       filter  WHERE FO.QtyRequested > 0  (Cognos' "WHERE T0.C20 > 0", where
//       T0.C20 = avg(WAUORG) = the model's [Quantity Requested]; see MAPPING).
//   Tables: F4801 wa (WO Header), F3111 wp (WO Parts), F554101 tag (Item Tag),
//           F4101 im (Item Master), F4102 ib (Item Branch).
//   Row-level filters: Component 2nd item in ('PR3460','PR3460.E','PR5980I','PR5980I.E',
//     'PR5980I.S','PR5985','PR5985.E','PR5985.S'); Issued+Ordered > 0; Start Date >= 2026-03-01; 2nd Item not
//     like '%-%'; WAUOM in ('LB','KG'); WASRST not in ('MM').
//
// MAPPING (raw generated SQL used opaque T0.Cn aliases; decoded via the Report XML
//   dataItem order + the detail filters). Key facts, verified against the xlsx:
//     [Quantity Requested] = AVG(WAUORG/10000) OVER P   (filter >0 is on this)
//     [Quantity Completed] = AVG(WASOQS/10000) OVER P
//     [Issued Quantity]    = SUM(WMTRQT/10000) OVER P   (component issued)
//     [Ordered Quantity]   = SUM(WMUORG/10000) OVER P   (component ordered)
//   (Cognos emitted sum+count columns to form the two averages; using AVG() OVER
//    is mathematically identical and still a legal window fn. Numbers tie 1:1 -
//    checked vs xlsx rows: P7 ISSUED LB = Issued/0.453593 when Comp UOM='KG', etc.)
//
// Oracle -> T-SQL conversions:
//   decode(...,'ERROR')                    -> CASE ... ELSE 'ERROR' END
//   trim(both from x)                      -> LTRIM(RTRIM(x))
//   PRODDTA.JUL2DATE(col) w/ >0 guard      -> CASE WHEN col>0 THEN
//       DATEADD(DAY,(col%1000)-1,DATEFROMPARTS(1900+(col/1000),1,1)) END
//   DATE '2026-03-01'                      -> '2026-03-01'
//   current_timestamp                      -> GETDATE()   ("DATE")
//   x/10000                                -> x/10000.0
//   not like '%-%' / not in (...)          -> kept
//   order by ... nulls last                -> OMITTED (folding). Cognos sort was
//       REGION, Start Date, Completed Date -> set in the visual. See BUILD.md.
//
// PARITY QUIRKS reproduced on purpose (documented in BUILD.md):
//   * The double window-aggregate fan-out (SUM + AVG OVER the same big partition).
//   * Cognos-computed columns re-derived here from the base aggregates so the table
//     has all 22 rendered columns typed:
//       STATE       = OPEN when QtyCompleted=0 AND WO Status in ('20','30','90')
//                     AND [P7 ISSUED KG]=0, else COMPLETE.
//       REQUEST KG  = LB? Qty*0.453593 : Qty     (on [Quantity Requested])
//       COMPLETE KG = LB? Qty*0.453593 : Qty     (on [Quantity Completed])
//       P7 ISSUED/ORDERED KG = CompUOM='LB'? qty*0.453593 : qty
//       P7 ISSUED/ORDERED LB = CompUOM='KG'? qty/0.453593 : qty
//       P7 REMAINING = P7 ORDERED LB - P7 ISSUED LB.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            FO.REGION                               AS [REGION],
            CASE WHEN FO.QtyCompleted = 0
                  AND FO.WO_Status IN ('20', '30', '90')
                  AND (CASE WHEN FO.Comp_UOM = 'LB' THEN FO.IssuedQty * 0.453593 ELSE FO.IssuedQty END) = 0
                 THEN 'OPEN' ELSE 'COMPLETE'
            END                                     AS [STATE],
            FO.Branch_Plant                         AS [Branch Plant],
            FO.WO_Number                            AS [WO Number],
            FO.Global_Bulk_Item                     AS [Global Bulk Item],
            FO.Bulk_Item                            AS [Bulk Item],
            FO.Item2                                AS [2nd Item Number],
            FO.WO_Status                            AS [WO Status],
            FO.Start_Date                           AS [Start Date],
            FO.Completed_Date                       AS [Completed Date],
            FO.QtyRequested                         AS [Quantity Requested],
            FO.QtyCompleted                         AS [Quantity Completed],
            FO.Comp_Item2                           AS [Component 2nd Item Number],
            FO.Comp_UOM                             AS [Component UOM],
            CASE WHEN FO.UOM = 'LB' THEN FO.QtyRequested * 0.453593 ELSE FO.QtyRequested END          AS [REQUEST KG],
            CASE WHEN FO.UOM = 'LB' THEN FO.QtyCompleted * 0.453593 ELSE FO.QtyCompleted END          AS [COMPLETE KG],
            CASE WHEN FO.Comp_UOM = 'LB' THEN FO.IssuedQty * 0.453593 ELSE FO.IssuedQty END           AS [P7 ISSUED KG],
            CASE WHEN FO.Comp_UOM = 'LB' THEN FO.OrderedQty * 0.453593 ELSE FO.OrderedQty END         AS [P7 ORDERED KG],
            CASE WHEN FO.Comp_UOM = 'KG' THEN FO.IssuedQty / 0.453593 ELSE FO.IssuedQty END           AS [P7 ISSUED LB],
            CASE WHEN FO.Comp_UOM = 'KG' THEN FO.OrderedQty / 0.453593 ELSE FO.OrderedQty END         AS [P7 ORDERED LB],
            (CASE WHEN FO.Comp_UOM = 'KG' THEN FO.OrderedQty / 0.453593 ELSE FO.OrderedQty END)
              - (CASE WHEN FO.Comp_UOM = 'KG' THEN FO.IssuedQty / 0.453593 ELSE FO.IssuedQty END)     AS [P7 REMAINING],
            GETDATE()                               AS [DATE]
        FROM (
            SELECT
                CASE LTRIM(RTRIM(wa.WAMMCU))
                     WHEN 'SING' THEN 'Singapore'
                     WHEN 'CINC' THEN 'Americas'
                     WHEN 'AUBA' THEN 'Aubange'
                     WHEN 'CIN2' THEN 'Americas'
                     ELSE 'ERROR'
                END                                                 AS REGION,
                LTRIM(RTRIM(wa.WAMMCU))                             AS Branch_Plant,
                wa.WADOCO                                           AS WO_Number,
                LTRIM(RTRIM(tag.IMGBLK))                            AS Global_Bulk_Item,
                tag.IMBULK                                          AS Bulk_Item,
                LTRIM(RTRIM(wa.WALITM))                             AS Item2,
                wa.WASRST                                           AS WO_Status,
                CASE WHEN wa.WASTRT > 0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END AS Start_Date,
                CASE WHEN wa.WASTRX > 0 THEN DATEADD(DAY,(wa.WASTRX%1000)-1,DATEFROMPARTS(1900+(wa.WASTRX/1000),1,1)) END AS Completed_Date,
                wa.WAUOM                                            AS UOM,
                LTRIM(RTRIM(wp.WMCPIL))                             AS Comp_Item2,
                wp.WMUM                                             AS Comp_UOM,
                AVG(wa.WAUORG/10000.0) OVER (PARTITION BY LTRIM(RTRIM(wa.WAMMCU)), wa.WADOCO, LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wa.WALITM)), wa.WASRST, CASE WHEN wa.WATRDJ>0 THEN DATEADD(DAY,(wa.WATRDJ%1000)-1,DATEFROMPARTS(1900+(wa.WATRDJ/1000),1,1)) END, CASE WHEN wa.WASTRT>0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END, CASE WHEN wa.WADRQJ>0 THEN DATEADD(DAY,(wa.WADRQJ%1000)-1,DATEFROMPARTS(1900+(wa.WADRQJ/1000),1,1)) END, CASE WHEN wa.WASTRX>0 THEN DATEADD(DAY,(wa.WASTRX%1000)-1,DATEFROMPARTS(1900+(wa.WASTRX/1000),1,1)) END, wa.WAUOM, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM) AS QtyRequested,
                AVG(wa.WASOQS/10000.0) OVER (PARTITION BY LTRIM(RTRIM(wa.WAMMCU)), wa.WADOCO, LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wa.WALITM)), wa.WASRST, CASE WHEN wa.WATRDJ>0 THEN DATEADD(DAY,(wa.WATRDJ%1000)-1,DATEFROMPARTS(1900+(wa.WATRDJ/1000),1,1)) END, CASE WHEN wa.WASTRT>0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END, CASE WHEN wa.WADRQJ>0 THEN DATEADD(DAY,(wa.WADRQJ%1000)-1,DATEFROMPARTS(1900+(wa.WADRQJ/1000),1,1)) END, CASE WHEN wa.WASTRX>0 THEN DATEADD(DAY,(wa.WASTRX%1000)-1,DATEFROMPARTS(1900+(wa.WASTRX/1000),1,1)) END, wa.WAUOM, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM) AS QtyCompleted,
                SUM(wp.WMTRQT/10000.0) OVER (PARTITION BY LTRIM(RTRIM(wa.WAMMCU)), wa.WADOCO, LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wa.WALITM)), wa.WASRST, CASE WHEN wa.WATRDJ>0 THEN DATEADD(DAY,(wa.WATRDJ%1000)-1,DATEFROMPARTS(1900+(wa.WATRDJ/1000),1,1)) END, CASE WHEN wa.WASTRT>0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END, CASE WHEN wa.WADRQJ>0 THEN DATEADD(DAY,(wa.WADRQJ%1000)-1,DATEFROMPARTS(1900+(wa.WADRQJ/1000),1,1)) END, CASE WHEN wa.WASTRX>0 THEN DATEADD(DAY,(wa.WASTRX%1000)-1,DATEFROMPARTS(1900+(wa.WASTRX/1000),1,1)) END, wa.WAUOM, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM) AS IssuedQty,
                SUM(wp.WMUORG/10000.0) OVER (PARTITION BY LTRIM(RTRIM(wa.WAMMCU)), wa.WADOCO, LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wa.WALITM)), wa.WASRST, CASE WHEN wa.WATRDJ>0 THEN DATEADD(DAY,(wa.WATRDJ%1000)-1,DATEFROMPARTS(1900+(wa.WATRDJ/1000),1,1)) END, CASE WHEN wa.WASTRT>0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END, CASE WHEN wa.WADRQJ>0 THEN DATEADD(DAY,(wa.WADRQJ%1000)-1,DATEFROMPARTS(1900+(wa.WADRQJ/1000),1,1)) END, CASE WHEN wa.WASTRX>0 THEN DATEADD(DAY,(wa.WASTRX%1000)-1,DATEFROMPARTS(1900+(wa.WASTRX/1000),1,1)) END, wa.WAUOM, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM) AS OrderedQty
            FROM PRODDTA.F4801 wa, PRODDTA.F554101 tag, PRODDTA.F3111 wp, PRODDTA.F4101 im, PRODDTA.F4102 ib
            WHERE LTRIM(RTRIM(wp.WMCPIL)) IN ('PR3460', 'PR3460.E', 'PR5980I', 'PR5980I.E', 'PR5980I.S', 'PR5985', 'PR5985.E', 'PR5985.S')
              AND wp.WMTRQT/10000.0 + wp.WMUORG/10000.0 > 0
              AND CASE WHEN wa.WASTRT > 0 THEN DATEADD(DAY,(wa.WASTRT%1000)-1,DATEFROMPARTS(1900+(wa.WASTRT/1000),1,1)) END >= '2026-03-01'
              AND LTRIM(RTRIM(wa.WALITM)) NOT LIKE '%-%'
              AND wa.WAUOM IN ('LB', 'KG')
              AND wa.WASRST NOT IN ('MM')
              AND wa.WADOCO = wp.WMDOCO
              AND wa.WAITM = ib.IBITM
              AND wa.WAMMCU = ib.IBMCU
              AND ib.IBITM = im.IMITM
              AND im.IMITM = tag.IMITM
        ) FO
        WHERE FO.QtyRequested > 0
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"REGION", type text},
            {"STATE", type text},
            {"Branch Plant", type text},
            {"WO Number", Int64.Type},
            {"Global Bulk Item", type text},
            {"Bulk Item", type text},
            {"2nd Item Number", type text},
            {"WO Status", type text},
            {"Start Date", type date},
            {"Completed Date", type date},
            {"Quantity Requested", type number},
            {"Quantity Completed", type number},
            {"Component 2nd Item Number", type text},
            {"Component UOM", type text},
            {"REQUEST KG", type number},
            {"COMPLETE KG", type number},
            {"P7 ISSUED KG", type number},
            {"P7 ORDERED KG", type number},
            {"P7 ISSUED LB", type number},
            {"P7 ORDERED LB", type number},
            {"P7 REMAINING", type number},
            {"DATE", type datetime}
        },
        "en-US"
    )
in
    Typed
