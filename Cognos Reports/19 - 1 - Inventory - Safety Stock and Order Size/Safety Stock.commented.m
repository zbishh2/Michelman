// ============================================================================
// Report 19 - "1 - Inventory - Safety Stock and Order Size" - QUERY 1 of 2
// COMMENTED MASTER. The shipped file is "Safety Stock.m" (comment-free, repo
// rule CLAUDE.md §1). Maintain the two in parallel.
//
// Cognos native source (BUILD.md §3.1), DW_LEGACY Oracle star:
//     select distinct ITEM.BRANCH_PLANT, ITEM.BULK_ITEM, ITEM.ITEM_NUMBER_2ND,
//            ITEM.STOCK_TYPE_CODE, ITEM.MASTER_PLANNING_FAMILY__IMPR,
//            ITEM.LEADTIME_MFG, ITEM.PLANNER_NUMBER,
//            VENDOR_ALIAS_PLANNER.VENDOR_NAME, ITEM.SAFETY_STOCK,
//            ITEM.UNIT_OF_MEASURE__PRIMARY
//       from DW_LEGACY.ITEM, DW_LEGACY.VENDOR VENDOR_ALIAS_PLANNER
//      where ITEM.BRANCH_PLANT in (CINC,CIN2,AUBA,AUB2,SING,SNG4)
//        and ITEM.SAFETY_STOCK > 1
//        and ITEM.STOCK_TYPE_CODE not in ('O')
//        and ITEM.MASTER_PLANNING_FAMILY__IMPR like '%F%'
//        and ITEM.PLANNER_NUMBER = VENDOR_ALIAS_PLANNER.VENDOR_DIM_ID
//
// TIES AT 177 / 177 against the tight capture (BUILD.md V18), with 8 of 10
// columns exact. Re-measured against the local SQL mirror at build time
// (BUILD.md V31): 177 rows, branch split CIN2 129 / AUBA 24 / SNG4 11 /
// AUB2 9 / CINC 4 / SING 0 - identical to the capture.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            -- [Business Unit] is nchar(12); the trim is what makes the IN list
            -- below and the export's rendering agree. 0 mismatches / 177.
            LTRIM(RTRIM(ib.[Business Unit]))            AS [Branch Plant],

            -- [Item Bulk] and [Item Num Bulk] are IDENTICAL on all 116,002
            -- TbItemBranch rows (BUILD.md V10), so the COLLECTION_NOTES
            -- 'which one' ambiguity is moot. 0 mismatches / 177.
            ib.[Item Bulk]                              AS [Bulk Item],
            ib.[Item Num 2nd]                           AS [2nd Item Number],
            LTRIM(RTRIM(ib.[Stocking Type]))            AS [Stock Type Code],
            LTRIM(RTRIM(ib.[Master Planning Family]))   AS [Master Planning Family],

            -- Cognos LEADTIME_MFG = F4102.IBLTMF = EDW [Lead Time MFG_BP].
            -- NOT [Lead time Level] (= IBLTLV), which is a different field and
            -- disagrees on real rows (item 844318: 12 vs 0) - BUILD.md V13.
            -- This column is also the single blocker on the SSAS live route
            -- (§1.1): it is exposed in ZERO of the 34 perspectives.
            ib.[Lead Time MFG_BP]                       AS [Lead Time Order to Ship],
            ib.[Planner Num]                            AS [Planner Number],

            -- RAW EDW name, kept only as the fallback arm of the DAX
            -- [Planner Name] calculated column. EDW renders 'First Last'
            -- where Cognos renders 'Last, First', on ALL 177 rows, and EDW
            -- also keeps the diaeresis Cognos drops ('Joel Bertrand' vs
            -- 'Joel Bertrand'). The displayed name comes from
            -- ODS.PRODDTA.F0101.ABALPH via the 'Planner Names' table - see
            -- Planner Names.commented.m and BUILD.md §3.4 trap 3 / V32.
            LTRIM(RTRIM(ib.[Planner Name]))             AS [Planner Name (EDW)],

            -- SafetyStock = F4102.IBSAFE / 10000 (JDE 4 implied decimals).
            -- [Safety Stock SAFE] is byte-identical over all 116,002 rows
            -- (693 non-null each, 0 differ) so the choice is free - V2.
            -- Expressed in the item's PRIMARY UOM and NOT converted: the
            -- export shows 840 beside KG and 9500 beside LB (§3.2).
            ib.SafetyStock                              AS [Safety Stock],
            LTRIM(RTRIM(ib.[UOM Primary]))              AS [Unit of Measure Primary],

            -- Not displayed. Carries the many-to-one relationship to
            -- Shipments[ItemBranchSKey] argued for in BUILD.md §2. Unique on
            -- all 116,002 TbItemBranch rows, and on all 177 here with no
            -- NULLs (V31), so the relationship cannot fan out.
            -- ItemSKey + [Business Unit] is NOT unique (13 collisions) - V8.
            ib.ItemBranchSKey                           AS [ItemBranchSKey]

        -- The Cognos VENDOR join disappears: EDW denormalises the planner
        -- name onto TbItemBranch. One table, no joins.
        FROM BIQL.TbItemBranch ib WITH (NOLOCK)

        -- BUILD.md §3.3. This exact set reproduces 177.
        -- Stepwise: 116,002 -> branch6 44,330 -> SafetyStock>1 509
        --           -> Stocking Type <> 'O' 502 -> MPF LIKE '%F%' 177.
        WHERE LTRIM(RTRIM(ib.[Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')

          -- EDW writes NULL where IBSAFE = 0, and '> 1' excludes NULL in
          -- T-SQL exactly as it does in Oracle. DO NOT add ISNULL - it would
          -- change the row set. Threshold is sharp: '> 1' -> 177, '> 0' -> 178.
          AND ib.SafetyStock > 1

          -- 'O' = Obsolete (37,155 rows across the six branches).
          AND LTRIM(RTRIM(ib.[Stocking Type])) NOT IN ('O')

          -- Substring match = 'finished goods'. Admits exactly FBW (2),
          -- FCB (97), FEC (33), FRC (45) = 177 (V6). No current code carries
          -- an embedded F, so '%F%' is equivalent to 'F%' TODAY - keep '%F%'
          -- verbatim for parity, and note that a future code such as 'TFL'
          -- would silently join the report (open question Q6, §11).
          AND ib.[Master Planning Family] LIKE '%F%'

        -- DELIBERATELY ABSENT, both verified no-ops:
        --  1. SELECT DISTINCT. The Cognos query has one, but the 10-column
        --     projection already yields 177 distinct tuples from 177 rows
        --     (V4). A stray DISTINCT would mask future fan-out.
        --  2. A defensive WHERE [Planner Name] <> ''. The predicted
        --     'EDW over-includes by the number of unresolvable planners' gap
        --     is EXACTLY ZERO (V4/V18): all 177 rows carry a non-zero planner
        --     number and a non-blank name. Adding it changes nothing today
        --     and would diverge from Cognos if a planner were ever unnamed.
        --
        -- No ORDER BY: Power BI wraps this in SELECT * FROM ( ... ), which
        -- rejects it. The Cognos sort (Bulk Item, 2nd Item Number, Branch
        -- Plant) lives in the table visual instead - BUILD.md §7.
        ",
        null,
        [EnableFolding = false]
    )
in
    Data

// ----------------------------------------------------------------------------
// KNOWN VARIANCE, disclosed rather than engineered around (BUILD.md V18):
// exactly one item-branch differs from the 2026-08-06 capture - Cognos shows
// Planner Number 291244 / Safety Stock 9000, EDW shows 340941 / 8550. It was
// edited between the mirror load (2026-08-05) and the Cognos run (2026-08-06).
// This is snapshot staleness, not a logic error; expect it to disappear on a
// live refresh.
// ----------------------------------------------------------------------------
