let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            z.[JDE Parent],
            z.[Branch Plant],
            z.[JDE Raw],
            z.[JDE Percent],
            z.[WERCS Percent],
            z.[WERCS Raw],
            z.[WERCS Parent],
            z.[Difference]
        FROM (
            SELECT
                j.Parent_Second_Item_Number                  AS [JDE Parent],
                j.Branch_Plant                               AS [Branch Plant],
                j.Component_2nd_Item_Number                  AS [JDE Raw],
                j.Quantity                                   AS [JDE Percent],
                w.WercsPercent                               AS [WERCS Percent],
                w.Component_2nd_item_Number                  AS [WERCS Raw],
                w.Parent_2nd_Item_Number                     AS [WERCS Parent],
                ABS(j.Quantity - ISNULL(w.WercsPercent, 0))  AS [Difference],
                SUM(ABS(j.Quantity - ISNULL(w.WercsPercent, 0)))
                    OVER (PARTITION BY j.Parent_Second_Item_Number) AS ParentDiffTotal
            FROM (
                SELECT
                    LTRIM(RTRIM(pib.IBLITM))              AS Parent_Second_Item_Number,
                    LTRIM(RTRIM(bom.IXLITM))              AS Component_2nd_Item_Number,
                    LTRIM(RTRIM(bom.IXMMCU))              AS Branch_Plant,
                    SUM(ROUND(bom.IXQNTY / 10000.0, 4))   AS Quantity
                FROM PRODDTA.F3002 bom
                    INNER JOIN PRODDTA.F4102 pib
                        ON pib.IBITM = bom.IXKIT
                       AND LTRIM(RTRIM(pib.IBMCU)) = LTRIM(RTRIM(bom.IXMMCU))
                    LEFT JOIN PRODDTA.F0006 org
                        ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU))
                WHERE pib.IBSTKT = 'M'
                  AND bom.IXTBM = 'M'
                  AND ISNULL(LTRIM(RTRIM(org.MCSTYL)), '') <> 'LAB'
                  AND LTRIM(RTRIM(bom.IXMMCU)) NOT LIKE 'LAB%'
                GROUP BY
                    LTRIM(RTRIM(pib.IBLITM)),
                    LTRIM(RTRIM(bom.IXLITM)),
                    LTRIM(RTRIM(bom.IXMMCU))
            ) j
            LEFT JOIN (
                SELECT
                    ROUND(SUM(werc.F_PERCENT), 4)      AS WercsPercent,
                    LTRIM(RTRIM(werc.F_COMPONENT_ID))  AS Component_2nd_item_Number,
                    LTRIM(RTRIM(werc.F_PRODUCT))       AS Parent_2nd_Item_Number
                FROM PRODDTA.T_PROD_COMP werc
                GROUP BY
                    LTRIM(RTRIM(werc.F_COMPONENT_ID)),
                    LTRIM(RTRIM(werc.F_PRODUCT))
            ) w
                ON j.Parent_Second_Item_Number = w.Parent_2nd_Item_Number
               AND j.Component_2nd_Item_Number = w.Component_2nd_item_Number
        ) z
        WHERE z.ParentDiffTotal <> 0
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"JDE Parent", type text},
            {"Branch Plant", type text},
            {"JDE Raw", type text},
            {"JDE Percent", type number},
            {"WERCS Percent", type number},
            {"WERCS Raw", type text},
            {"WERCS Parent", type text},
            {"Difference", type number}
        }
    )
in
    Typed
