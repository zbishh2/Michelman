let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            LTRIM(RTRIM(snap.BusinessUnit))              AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            ib.[Item Num 2nd]                            AS [2nd Item Number],
            LTRIM(RTRIM(snap.CategoryGLF41021))          AS [GL Class Code],
            LTRIM(RTRIM(snap.Location))                  AS [Location],
            LTRIM(RTRIM(snap.LotNum))                    AS [Lot Number],
            LTRIM(RTRIM(snap.LotStatusCode))             AS [Lot Status],
            LTRIM(RTRIM(ib.[Master Planning Family]))    AS [Master Planning Family],
            SUM(snap.QuantityOnHandPrimaryUOM)           AS [Quantity on Hand],
            LTRIM(RTRIM(snap.UOMPrimary))                AS [Primary Unit of Measure],
            LTRIM(RTRIM(ib.[Stocking Type]))             AS [Stock Type Code],
            l.OnHandDate                                 AS [On Hand Date],
            l.LotExpirationDate                          AS [Lot Expiry Date],
            CAST(GETDATE() AS date)                      AS [DATE],
            MIN(k.KG)                                    AS [KG Factor]
        FROM BIQL.FactInventorySnapshot_History_Filtered snap WITH (NOLOCK)
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = snap.ItemBranchSKey
            LEFT  JOIN BIQL.DimLot l WITH (NOLOCK)
                    ON l.LotSKey = snap.LotSKey
            LEFT  JOIN BIQL.DimItemUOMConversionLBKG k WITH (NOLOCK)
                    ON k.ItemNumShort = ib.[Item Num Short]
                   AND LTRIM(RTRIM(k.BusinessUnit)) = LTRIM(RTRIM(ib.[Business Unit]))
                   AND LTRIM(RTRIM(k.UOM))          = LTRIM(RTRIM(k.UOMPrimary))
        WHERE snap.CalendarDate = DATEADD(DAY, -1, CAST(GETDATE() AS date))
          AND snap.QuantityOnHandPrimaryUOM > 0
          AND LTRIM(RTRIM(snap.CategoryGLF41021)) = 'IN32'
          AND LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC', 'CIN2', 'CIN4', 'AUBA', 'AUB2', 'SING', 'SNG4')
        GROUP BY
            LTRIM(RTRIM(snap.BusinessUnit)),
            ib.[Item Global Bulk],
            ib.[Item Bulk],
            ib.[Item Num 2nd],
            LTRIM(RTRIM(snap.CategoryGLF41021)),
            LTRIM(RTRIM(snap.Location)),
            LTRIM(RTRIM(snap.LotNum)),
            LTRIM(RTRIM(snap.LotStatusCode)),
            LTRIM(RTRIM(ib.[Master Planning Family])),
            LTRIM(RTRIM(snap.UOMPrimary)),
            LTRIM(RTRIM(ib.[Stocking Type])),
            l.OnHandDate,
            l.LotExpirationDate
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
