let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(bom.IXMMCU)) AS [Branch Plant]
        FROM PRODDTA.F3002 bom
            INNER JOIN PRODDTA.F4102 pib
                ON pib.IBITM = bom.IXKIT
               AND LTRIM(RTRIM(pib.IBMCU)) = LTRIM(RTRIM(bom.IXMMCU))
            LEFT JOIN PRODDTA.F0006 org
                ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU))
        WHERE bom.IXTBM = 'M'
          AND pib.IBSTKT = 'M'
          AND ISNULL(LTRIM(RTRIM(org.MCSTYL)), '') <> 'LAB'
          AND LTRIM(RTRIM(bom.IXMMCU)) NOT LIKE 'LAB%'
          AND (CASE WHEN bom.IXEFFT > 0
                    THEN DATEADD(DAY, (bom.IXEFFT % 1000) - 1,
                                 DATEFROMPARTS(1900 + (bom.IXEFFT / 1000), 1, 1))
               END) > CAST(GETDATE() AS date)
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(Data, {{"Branch Plant", type text}})
in
    Typed
