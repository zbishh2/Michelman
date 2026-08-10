// ============================================================================
// Report 03 - CM Sales Orders < 560 (Not Enough Inventory to Ship)
// QUERY: Inventory_Availability  ->  the INVENTORY on-hand detail (MIDDLE block
//        of the master-detail panel). Cognos query object "Inventory On Hand"
//        (raw block B).
//
// Columns (rendered, middle block): Plant | Item | On Hand | Commit | AVAIL |
//        Location | Lot# | Status   (+ Bulk carried, not shown)
//
// SOURCE: ODSPROD / ODS / PRODDTA (JDE), SQL Server. Native T-SQL, folds.
//   Flat SELECT, no WITH/CTE, no ORDER BY (sort in the visual). See BUILD.md.
//
// LOGIC (faithful to Cognos "Inventory On Hand"):
//   On-hand item-location balances (F41021) for the Cincinnati plants where
//   quantity-on-hand > 0. Item Branch (F4102) supplies the 2nd item number
//   (IBLITM) that JOINS this block to the sales orders. Item Tag (F554101) +
//   Item Master (F4101) supply the Bulk flag. NOT whitelist-filtered on item --
//   Cognos leaves inventory wide open and lets the join to the SO list pick the
//   relevant items; we reproduce that (the PBI relationship does the filtering).
//
//   AVAIL (Cognos data item "AVAILABLE") is STATUS-GATED, not a plain QOH-Commit:
//       AVAILABLE = CASE WHEN lot status is blank THEN (QtyOnHand - HardCommit)
//                        ELSE 0 END
//   i.e. only APPROVED (blank-status) stock counts as available; held/quarantine
//   lots (any non-blank status) show AVAIL = 0. This gated AVAILABLE is what feeds
//   the per-item "Available" total and the not-enough-inventory gate in BUILD.md.
//
//   Cognos "AVAILABLE CHECK" row filter (reproduced): show a lot when it has
//   available approved stock OR it is a non-blank-status lot; hide only blank-status
//   lots that are fully hard-committed (AVAILABLE <= 0). Simplifies to:
//       LTRIM(RTRIM(LILOTS)) <> '' OR (LIPQOH - LIHCOM)/10000.0 > 0
//
// ORACLE -> T-SQL conversions:
//   trim(both from x) -> LTRIM(RTRIM(x));  x/10000 -> x/10000.0 (drop the numeric trim).
//   Cognos SQL double-trims IBLITM ( trim(trim(IBLITM)) ) -- a no-op; single LTRIM/RTRIM here.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT
            LTRIM(RTRIM(ib.IBMCU))                                   AS [Plant],
            LTRIM(RTRIM(ib.IBLITM))                                  AS [Item],
            il.LIPQOH / 10000.0                                      AS [On Hand],
            il.LIHCOM / 10000.0                                      AS [Commit],
            (CASE WHEN (il.LILOTS IS NULL OR LTRIM(RTRIM(il.LILOTS)) = '')
                  THEN (il.LIPQOH - il.LIHCOM) / 10000.0
                  ELSE 0 END)                                        AS [AVAIL],
            il.LILOCN                                                AS [Location],
            LTRIM(RTRIM(il.LILOTN))                                  AS [Lot#],
            il.LILOTS                                                AS [Status],
            LTRIM(RTRIM(tag.IMBULK))                                 AS [Bulk]
        FROM PRODDTA.F4102 ib
        INNER JOIN PRODDTA.F41021 il  ON ib.IBMCU = il.LIMCU AND ib.IBITM = il.LIITM
        INNER JOIN PRODDTA.F4101 im   ON ib.IBITM = im.IMITM
        INNER JOIN PRODDTA.F554101 tag ON im.IMITM = tag.IMITM
        WHERE LTRIM(RTRIM(ib.IBMCU)) IN ('CINC','CIN2','CIN4')
          AND il.LIPQOH / 10000.0 > 0
          AND ( LTRIM(RTRIM(il.LILOTS)) <> '' OR (il.LIPQOH - il.LIHCOM) / 10000.0 > 0 )
        ",
        null,
        [EnableFolding = true]
    ),
    Typed = Table.TransformColumnTypes(
        Data,
        {
            {"Plant", type text},
            {"Item", type text},
            {"On Hand", type number},
            {"Commit", type number},
            {"AVAIL", type number},
            {"Location", type text},
            {"Lot#", type text},
            {"Status", type text},
            {"Bulk", type text}
        }
    )
in
    Typed
