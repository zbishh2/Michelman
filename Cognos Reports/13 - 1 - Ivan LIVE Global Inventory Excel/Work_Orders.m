let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(wo.WAMMCU))     AS [Branch Plant],
            LTRIM(RTRIM(tag.IMGBLK))    AS [Global Bulk Item],
            tag.IMBULK                  AS [Bulk Item],
            LTRIM(RTRIM(wo.WALITM))     AS [2nd Item Number],
            wo.WADOCO                   AS [WO Number],
            wo.WASRST                   AS [WO Status],
            wo.WATRDJ                   AS [Order Date],
            wo.WASTRT                   AS [Start Date],
            wo.WASTRX                   AS [Completed Date],
            AVG(wo.WAUORG/10000.0)      AS [Quantity Requested],
            AVG(wo.WASOQS/10000.0)      AS [Quantity Completed],
            wo.WAUOM                    AS [Unit of Measure]
        FROM
        (
            SELECT
                WADOCO, WAMMCU, WASRST, WAITM, WALITM, WAUORG, WASOQS, WAUOM,
                CASE WHEN WATRDJ>0 THEN DATEADD(DAY,(WATRDJ%1000)-1,DATEFROMPARTS(1900+(WATRDJ/1000),1,1)) ELSE NULL END AS WATRDJ,
                CASE WHEN WASTRT>0 THEN DATEADD(DAY,(WASTRT%1000)-1,DATEFROMPARTS(1900+(WASTRT/1000),1,1)) ELSE NULL END AS WASTRT,
                CASE WHEN WASTRX>0 THEN DATEADD(DAY,(WASTRX%1000)-1,DATEFROMPARTS(1900+(WASTRX/1000),1,1)) ELSE NULL END AS WASTRX
            FROM PRODDTA.F4801
        ) wo
        JOIN PRODDTA.F4102 ib  ON wo.WAITM = ib.IBITM AND wo.WAMMCU = ib.IBMCU
        JOIN PRODDTA.F4101 im  ON ib.IBITM = im.IMITM
        JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE wo.WASRST NOT IN ('95','96','97','98','99','MM','CD')
          AND wo.WASTRT >= DATEADD(DAY,-30,CAST(GETDATE() AS date))
        GROUP BY
            LTRIM(RTRIM(wo.WAMMCU)), LTRIM(RTRIM(tag.IMGBLK)), tag.IMBULK, LTRIM(RTRIM(wo.WALITM)),
            wo.WADOCO, wo.WASRST, wo.WATRDJ, wo.WASTRT, wo.WASTRX, wo.WAUOM
        HAVING AVG(wo.WASOQS/10000.0) = 0
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
            {"Unit of Measure", type text}
        },
        "en-US"
    )
in
    Typed
