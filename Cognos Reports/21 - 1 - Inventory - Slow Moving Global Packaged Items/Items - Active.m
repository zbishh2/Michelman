let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT DISTINCT
            LTRIM(RTRIM(ib.[Business Unit]))             AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            ib.[Item Num 2nd]                            AS [2nd Item Number],
            LTRIM(RTRIM(ib.[Stocking Type]))             AS [Stock Type Code]
        FROM BIQL.TbItemBranch ib WITH (NOLOCK)
        WHERE LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
          AND LTRIM(RTRIM(ib.[Stocking Type])) NOT IN ('O')
          AND LTRIM(RTRIM(ib.[Business Unit])) IN ('CINC', 'CIN2', 'CIN4', 'AUBA', 'AUB2', 'SING', 'SNG4')
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
