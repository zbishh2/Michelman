// ============================================================================
// Report 14  ·  Query object: Escor Lot Info   (feeds Escor Lot Details list)
// Route: EDW  ·  BIQL.DimLot x BIQL.DimItem  (lot master — NO snapshot, NO date)
// Cognos origin: DW_LEGACY (Escor Lot Info.3.sql), SELECT DISTINCT over ITEM_LOT_NUMBERS x ITEM.
//
// DATE-INDEPENDENT: this list does not take the AsOfDate parameter and does not
// change with the prompt. Expect ~1,663 rows.
// SELECT DISTINCT kept (Cognos SQL has it) — the lot x item join otherwise fans out.
// Sort (visual): On Hand Date ascending (null/1900-01-01 placeholders sort first).
// TODO verify: DimLot holds all historical lots for the ESC5200 family (target 1,663).
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),   // TODO verify EDW server name
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
