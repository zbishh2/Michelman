let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(lot.BusinessUnit))   AS [Branch Plant],
            it.ItemBulk                      AS [Bulk Item],
            it.ItemNum2nd                    AS [2nd Item Number],
            lot.ItemNumShort                 AS [Item Short ID],
            LTRIM(RTRIM(lot.LotNum))         AS [Lot Number],
            lot.SupplierLotNum               AS [Supplier Lot Number],
            lot.MemoLot1                     AS [Memo Lot 1],
            lot.MemoLot2                     AS [Memo Lot 2],
            lot.OnHandDate                   AS [On Hand Date]
        FROM BIQL.DimLot lot
            INNER JOIN BIQL.DimItem it ON it.ItemSKey = lot.ItemSKey
        WHERE it.ItemBulk IN ('ESC5200','ESC5200.E','ESC5200.S')
        ",
        null,
        [EnableFolding = true]
    )
in
    Data
