// ============================================================================
// Report 11 - BOM WERCS Integrity Check   ->   list "List1" (page "Page1")
// QUERY: Report  ->  Cognos query object "Report" = "JDE" LEFT JOIN "WERCS"
//        (Cognos "Data Warehouse" package / DW_LEGACY Oracle star schema).
//
// ****************************************************************************
// *  REBUILT OFF ODSPROD / PRODDTA (base JDE tables) in T-SQL.  The Cognos   *
// *  original reads the DW_LEGACY Oracle warehouse; we have no DW_LEGACY      *
// *  connection (same call as reports 08/10, 2026-07-05), so every DW column  *
// *  is reverse-mapped to its underlying JDE F-table field.  See BUILD.md.    *
// ****************************************************************************
//
// 🟡 BLOCKER PARTIALLY RESOLVED 2026-07-14 (David Bubash): WERCS lives in ODS
//    as PRODDTA.T_* (T_PRODUCTS / T_PROD_COMP / T_COMP_DATA / T_PROD_DATA /
//    T_PROD_TEXT / T_TEXT_DETAILS / T_PDF_MSDS).  Likely map: T_PROD_COMP =
//    composition rows (PERCENT), T_PRODUCTS = product master (item code ->
//    F4101.IMLITM), T_COMP_DATA = component identity.  The "w" derived table
//    below is still a PLACEHOLDER -- exact column names pending the
//    00_verify_tables.sql §4 column dump (run on jumpbox).  BUILD.md §2/§11.
//
// WHAT IT DOES (integrity check):
//   For each manufactured BOM, compare the JDE component percentages to WERCS,
//   matched on (Parent 2nd Item Number, Component 2nd Item Number).
//   Difference = ABS(JDE% - ISNULL(WERCS%,0)); show a parent only if
//   SUM(Difference) over that parent <> 0.  In the rendered report every WERCS
//   column is blank -> the discrepancies are JDE BOMs with NO WERCS record.
//
// DW -> JDE FIELD MAP (F3002 bom = Bill of Material, F4101 im = Item Master,
//                      F0006 org = Business Unit; WERCS = T_* pending columns).
// NOTE 2026-07-14: F3002's real ODS prefix is IX*, not IB* (IB is F4102's) --
// confirmed by a live TOP 5 dump; all F3002 names corrected.  F3002 also
// carries the 2nd item numbers directly (IXKITL parent / IXLITM component);
// the F4101 joins are kept because IMSTKT (stock type) is needed anyway.
//   Parent Second Item Number  ITEM.ITEM_NUMBER_2ND (parent) -> F4101(pim).IMLITM  (= bom.IXKITL)
//   2nd Item Number (JDE Raw)  ITEM.ITEM_NUMBER_2ND (comp)   -> F4101(cim).IMLITM  (= bom.IXLITM)
//   Quantity  (JDE Percent)    round(BOM.QUANTITY*100,4)      -> ROUND(bom.IXQNTY/10000.0,4)  -- SEE FLAG 1
//   Branch Plant               BILL_OF_MATERIAL.BRANCH_PLANT  -> bom.IXMMCU
//   Stock Type Code (filter M) ITEM.STOCK_TYPE_CODE (parent)  -> pim.IMSTKT   -- SEE FLAG 2
//   Type of Bill    (filter M) BILL_OF_MATERIAL.TYPE_OF_BILL  -> bom.IXTBM
//   Branch Type  (filter <>LAB) ORGANIZATION.BRANCH_TYPE       -> org.MCSTYL
//   WERCS Percent              BILL_OF_MATERIAL_WERCS.PERCENT               -> T_PROD_COMP.F_PERCENT
//   WERCS Parent               BILL_OF_MATERIAL_WERCS.ITEM_NUMBER_2ND_PARENT    -> T_PROD_COMP.F_PRODUCT
//   WERCS Raw (component)      BILL_OF_MATERIAL_WERCS.ITEM_NUMBER_2ND_COMPONENT -> T_PROD_COMP.F_COMPONENT_ID (tentative -- see 'w' note)
//
// PORTING FLAGS (validate before sign-off -- full detail in BUILD.md §4):
//   1. IXQNTY SCALING -- CONFIRMED on ODS 2026-07-14: live F3002 sample (parent
//      171195PX.E @ AUBA) has IXQNTY 997500 + 2500 -> /10000 = 99.75 + 0.25 =
//      exactly 100%.  ROUND(IXQNTY/10000.0,4) stands; final tie-out still via
//      DIH2O = 55.4802 at validation.
//   2. STOCK-TYPE GRAIN: ported as master F4101.IMSTKT; if the DW ITEM dim is
//      branch-grain the true source is F4102.IBSTKT (usually equal).
//   3. count(distinct ... ) over () (the "Count Distinct(JDE Parent)" footer) is
//      NOT portable to T-SQL -> dropped here, done as a DAX measure (BUILD.md §7).
//   4. Difference filter partitions by PARENT ONLY (per the generated SQL), even
//      though the Cognos summaryFilter lists (Parent, Branch).  Faithful choice.
//   5. No expired date literal anywhere.  Only Julian logic is in Branch.m.
//
// SOURCE: ODSPROD / ODS, SQL Server.  Native T-SQL, folds.  House pattern =
//   01 - RM Staging at Shell Road 2026 (ODS)\RM_Requirements.m.
//   INLINE DERIVED TABLES only (no CTE): Power BI wraps as SELECT * FROM (...),
//   and a leading WITH cannot be wrapped.  No ORDER BY (sort in the visual).
//
// OUTPUT COLUMNS (visual order): JDE Parent | Branch Plant (hidden) | JDE Raw |
//   JDE Percent | WERCS Percent | WERCS Raw | WERCS Parent | Difference (hidden)
// ============================================================================
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
                -- ==== query object 'JDE' : F3002 + F4101(parent) + F4101(comp) + F0006 ====
                -- REWORKED 2026-07-14 after first data validation vs the Cognos
                -- render (three defects found live):
                --   1. LAB exclusion: ODS F0006.MCSTYL is NOT the DW's
                --      ORGANIZATION.BRANCH_TYPE -- LABA/LABO/LABC/LABS all passed
                --      MCSTYL <> 'LAB' (14.5k of 27.6k rows) yet LAB-only parents
                --      (1314EU@LABO, 151012PX@LABS) are absent from the Cognos
                --      render.  Evidence-based port: exclude branches named LAB*.
                --      (Real BRANCH_TYPE source column = open probe, verify SQL 5b.)
                --   2. NULL-safety: NULL MCSTYL <> 'LAB' is UNKNOWN -> row silently
                --      dropped (suspected cause of 1%CAR934 vanishing).  Org join
                --      now LEFT + ISNULL so only explicit 'LAB' style excludes.
                --   3. Branch grain: DW BILL_OF_MATERIAL carries ONE branch per
                --      BOM (render shows each component once; ODS has 181139INT
                --      at CINC AND CIN2 w/ identical percents).  DENSE_RANK picks
                --      the alphabetically-first surviving branch per parent --
                --      deterministic; DW's actual pick is hidden in the render.
                -- REWORK #2 same day: stock type moved F4101(master) -> F4102
                -- (branch grain).  Second validation pass showed 1%CAR934 still
                -- missing (it IS in Cognos) while AUBA .E parents (151165PX.E,
                -- 161107PX.E) appeared that Cognos provably skips -- both
                -- explained if DW ITEM.STOCK_TYPE_CODE is branch-grain, and the
                -- DW SQL agrees: its ITEM dim carries BRANCH_PLANT (= F4102).
                -- Bonus: F4102.IBLITM + F3002.IXLITM supply the 2nd item numbers
                -- directly, so both F4101 joins are gone.
                -- REWORK #3 same day: the DENSE_RANK one-branch-per-parent pick
                -- REMOVED.  The full Cognos xlsx export settled the grain: the
                -- DW keeps ALL surviving branches (NYS3205 + the SX family list
                -- at BOTH CIN2 and CINC; DPE3500 has CIN2's -T2 transfer BOM AND
                -- USCM's real 16-component formula).  Most parents are stocked
                -- 'M' at exactly one branch, which is why pass 3 saw zero
                -- multi-branch parents.  Natural F4102-filtered grain = Cognos
                -- grain; JDE percents tie 0-diff on all 4,982 common keys.
                SELECT
                    LTRIM(RTRIM(pib.IBLITM))              AS Parent_Second_Item_Number,
                    LTRIM(RTRIM(bom.IXLITM))              AS Component_2nd_Item_Number,
                    LTRIM(RTRIM(bom.IXMMCU))              AS Branch_Plant,
                    SUM(ROUND(bom.IXQNTY / 10000.0, 4))   AS Quantity     -- FLAG 1: scaling CONFIRMED
                FROM PRODDTA.F3002 bom
                    INNER JOIN PRODDTA.F4102 pib
                        ON pib.IBITM = bom.IXKIT
                       AND LTRIM(RTRIM(pib.IBMCU)) = LTRIM(RTRIM(bom.IXMMCU)) -- parent item @ BOM branch
                    LEFT JOIN PRODDTA.F0006 org
                        ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU)) -- branch business unit
                WHERE pib.IBSTKT = 'M'                                       -- FLAG 2: BRANCH stock type (F4102)
                  AND bom.IXTBM = 'M'
                  AND ISNULL(LTRIM(RTRIM(org.MCSTYL)), '') <> 'LAB'
                  AND LTRIM(RTRIM(bom.IXMMCU)) NOT LIKE 'LAB%'
                GROUP BY
                    LTRIM(RTRIM(pib.IBLITM)),
                    LTRIM(RTRIM(bom.IXLITM)),
                    LTRIM(RTRIM(bom.IXMMCU))
            ) j
            LEFT JOIN (
                -- ==== query object 'WERCS' : DW_LEGACY.BILL_OF_MATERIAL_WERCS ====
                -- Source = PRODDTA.T_PROD_COMP (Dave + 4b/4c/4d dumps 2026-07-14):
                -- F_PRODUCT = parent product code (= JDE 2nd item), F_PERCENT =
                -- composition percent (decimal(20,10), no scaling), F_COMPONENT_ID
                -- = component key.  KEY FINDING (4d-2): WERCS stores a CHEMICAL
                -- rollup -- component IDs are mostly CAS-linked codes ('2893' =
                -- water, hybrids like '9005-00-9 - BRIJS2.E'), and raw materials
                -- are decomposed (JDE GLUT50 0.113 -> CAS 111-30-8 at 0.0565 =
                -- x50% solution strength).  Those rows never equal a JDE item
                -- code, never match the LEFT JOIN, and drop out -- which is
                -- exactly why the Cognos render shows blank WERCS columns.  Only
                -- components that are themselves registered products (e.g.
                -- 2020NPR.E) can match.  DECISIONS: exact-equality join (the DW
                -- did NOT split hybrid IDs -- a split would have rendered
                -- NEO2512 non-blank); NO F_UNITS filter (mixed ''/PPH bases only
                -- reach the output on exact-match pairs, where PPH ~ percent).
                -- alias is WercsPercent, NOT 'Percent' -- PERCENT is a T-SQL
                -- reserved keyword (TOP n PERCENT) and errors unbracketed
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
