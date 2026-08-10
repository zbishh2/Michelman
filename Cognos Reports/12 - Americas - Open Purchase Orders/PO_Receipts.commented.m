// Report 12 lookup: 'PO Receipts' - last receipt date per PO line.
// MAX(F43121.PRRCDJ) per 4-part line key, scoped to the report's PO population
// (OP/OD, Americas branches). Stands in for DW PO_DETAIL_CLOSED_DATE
// ("Receipt Date") - PDRCDJ does not exist on this F4311 (proven 2026-07-14).
// [Line Key] = KCOO|DOCO|DCTO|LNID -> m:1 relationship from PO[Line Key];
// PO[Receipt Date] = RELATED('PO Receipts'[Receipt Date]).
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(r.PRKCOO)) + '|' + CAST(r.PRDOCO AS varchar(20)) + '|' + LTRIM(RTRIM(r.PRDCTO)) + '|' + CAST(r.PRLNID AS varchar(20)) AS [Line Key],
            MAX(CASE WHEN r.PRRCDJ>0 THEN DATEADD(DAY,(r.PRRCDJ%1000)-1,DATEFROMPARTS(1900+(r.PRRCDJ/1000),1,1)) END) AS [Receipt Date]
        FROM PRODDTA.F43121 r
        WHERE EXISTS (SELECT 1 FROM PRODDTA.F4311 d
                      WHERE d.PDKCOO = r.PRKCOO AND d.PDDOCO = r.PRDOCO
                        AND d.PDDCTO = r.PRDCTO AND d.PDLNID = r.PRLNID
                        AND LTRIM(RTRIM(d.PDMCU)) IN ('CINC','CIN2','CIN4')
                        AND LTRIM(RTRIM(d.PDDCTO)) IN ('OP','OD'))
        GROUP BY LTRIM(RTRIM(r.PRKCOO)), r.PRDOCO, LTRIM(RTRIM(r.PRDCTO)), r.PRLNID
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Line Key", type text},
            {"Receipt Date", type date}
        },
        "en-US"
    )
in
    Typed
