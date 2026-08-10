let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            m.C0  AS [Branch Plant],
            m.C1  AS [Global Bulk Item],
            m.C2  AS [Bulk Item],
            m.C3  AS [2nd Item Number],
            m.C4  AS [WO Number],
            m.C5  AS [WO Status],
            m.C6  AS [Order Date],
            m.C7  AS [Start Date],
            m.C8  AS [Completed Date],
            SUM(m.sumReq)  OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11)
                / NULLIF(SUM(m.cntReq) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11),0)  AS [Quantity Requested],
            SUM(m.sumComp) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11)
                / NULLIF(SUM(m.cntComp) OVER (PARTITION BY m.C0,m.C1,m.C2,m.C3,m.C4,m.C5,m.C6,m.C7,m.C8,m.C11),0) AS [Quantity Completed],
            m.C11 AS [Unit of Measure],
            m.C12 AS [Component Branch],
            m.C13 AS [Component 2nd Item Number],
            m.OrderedQty AS [Ordered Quantity],
            m.IssuedQty  AS [Issued Quantity],
            m.C14 AS [Component UOM],
            m.C15 AS [Requested Date]
        FROM
        (
            SELECT
                LTRIM(RTRIM(wo.WAMMCU))  AS C0,
                LTRIM(RTRIM(tag.IMGBLK)) AS C1,
                tag.IMBULK               AS C2,
                LTRIM(RTRIM(wo.WALITM))  AS C3,
                wo.WADOCO                AS C4,
                wo.WASRST                AS C5,
                wo.WATRDJ                AS C6,
                wo.WASTRT                AS C7,
                wo.WASTRX                AS C8,
                wo.WAUOM                 AS C11,
                wp.WMCMCU                AS C12,
                LTRIM(RTRIM(wp.WMCPIL))  AS C13,
                wp.WMUM                  AS C14,
                wp.WMDRQJ                AS C15,
                SUM(wo.WAUORG/10000.0)   AS sumReq,
                COUNT(wo.WAUORG/10000.0) AS cntReq,
                SUM(wo.WASOQS/10000.0)   AS sumComp,
                COUNT(wo.WASOQS/10000.0) AS cntComp,
                SUM(wp.WMUORG/10000.0)   AS OrderedQty,
                SUM(wp.WMTRQT/10000.0)   AS IssuedQty
            FROM
            (
                SELECT
                    WADOCO, WAMMCU, WASRST, WAITM, WALITM, WAUORG, WASOQS, WAUOM,
                    CASE WHEN WATRDJ>0 THEN DATEADD(DAY,(WATRDJ%1000)-1,DATEFROMPARTS(1900+(WATRDJ/1000),1,1)) ELSE NULL END AS WATRDJ,
                    CASE WHEN WASTRT>0 THEN DATEADD(DAY,(WASTRT%1000)-1,DATEFROMPARTS(1900+(WASTRT/1000),1,1)) ELSE NULL END AS WASTRT,
                    CASE WHEN WASTRX>0 THEN DATEADD(DAY,(WASTRX%1000)-1,DATEFROMPARTS(1900+(WASTRX/1000),1,1)) ELSE NULL END AS WASTRX
                FROM PRODDTA.F4801
            ) wo
            JOIN
            (
                SELECT
                    WMDOCO, WMCPIL, WMCMCU, WMUORG, WMTRQT, WMUM,
                    CASE WHEN WMDRQJ>0 THEN DATEADD(DAY,(WMDRQJ%1000)-1,DATEFROMPARTS(1900+(WMDRQJ/1000),1,1)) ELSE NULL END AS WMDRQJ
                FROM PRODDTA.F3111
            ) wp ON wo.WADOCO = wp.WMDOCO
            JOIN PRODDTA.F4102 ib  ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
            JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
            JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
            WHERE wo.WASRST NOT IN ('95','96','97','98','99','MM','CD')
              AND wo.WASTRT >= DATEADD(DAY,-30,CAST(GETDATE() AS date))
              AND (wp.WMUORG/10000.0 + wp.WMTRQT/10000.0) > 0
            GROUP BY
                LTRIM(RTRIM(wo.WAMMCU)), LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wo.WALITM)),
                wo.WADOCO, wo.WASRST, wo.WATRDJ, wo.WASTRT, wo.WASTRX, wo.WAUOM,
                wp.WMCMCU, LTRIM(RTRIM(wp.WMCPIL)), wp.WMUM, wp.WMDRQJ
            HAVING AVG(wo.WASOQS/10000.0) = 0
        ) m
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Branch Plant", type text}, {"Global Bulk Item", type text}, {"Bulk Item", type text},
            {"2nd Item Number", type text}, {"WO Number", Int64.Type}, {"WO Status", type text},
            {"Order Date", type date}, {"Start Date", type date}, {"Completed Date", type date},
            {"Quantity Requested", type number}, {"Quantity Completed", type number},
            {"Unit of Measure", type text}, {"Component Branch", type text},
            {"Component 2nd Item Number", type text}, {"Ordered Quantity", type number},
            {"Issued Quantity", type number}, {"Component UOM", type text}, {"Requested Date", type date}
        },
        "en-US"
    )
in
    Typed
