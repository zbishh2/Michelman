let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            ab.ABAN8                    AS [Planner Number],
            LTRIM(RTRIM(ab.ABALPH))     AS [Planner Name (JDE)]
        FROM PRODDTA.F0101 ab WITH (NOLOCK)
        WHERE ab.ABAN8 IN (
                  SELECT ibp.IBANPL
                  FROM PRODDTA.F4102 ibp WITH (NOLOCK)
                  WHERE LTRIM(RTRIM(ibp.IBMCU)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
              )
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
