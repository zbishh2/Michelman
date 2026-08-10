// ============================================================================
// Report 11 - BOM WERCS Integrity Check   ->   prompt value list
// QUERY: Branch  ->  Cognos query object "Branch" (feeds the Branch Plant
//        single-select dropdown; parameter ?Branch?, optional/autoSubmit).
//        Generated SQL: Branch.0.sql.
//
// Distinct branch/plants that currently own a manufactured BOM.  Note this
// prompt list carries an EXTRA filter the list query does NOT: the BOM must be
// currently effective (Effective Thru Date > today).  Preserve that asymmetry.
//
// DW -> JDE FIELD MAP (F3002 bom, F4101 pim = parent item master, F0006 org).
// NOTE 2026-07-14: F3002's real ODS prefix is IX*, not IB* (IB is F4102's) --
// confirmed by a live TOP 5 dump; all IB* names below corrected to IX*.
//   Branch Plant            BILL_OF_MATERIAL.BRANCH_PLANT       -> bom.IXMMCU
//   Type of Bill  (= 'M')   BILL_OF_MATERIAL.TYPE_OF_BILL       -> bom.IXTBM
//   Stock Type    (= 'M')   ITEM.STOCK_TYPE_CODE (parent)       -> pim.IMSTKT
//   Effective Thru (> now)  BILL_OF_MATERIAL.EFFETIVE_THROUGH_DATE -> bom.IXEFFT (Julian CYYDDD; 140366 = "never expires" convention)
//   Branch Type   (<> LAB)  ORGANIZATION.BRANCH_TYPE            -> org.MCSTYL
//
// SYSDATE -> CAST(GETDATE() AS date).  Julian -> date via
//   DATEADD(DAY,(x%1000)-1, DATEFROMPARTS(1900+(x/1000),1,1)).
// SOURCE: ODSPROD / ODS, SQL Server.  Native T-SQL, folds.  No CTE, no ORDER BY.
// ============================================================================
let
    Source = Sql.Database("ODSPROD", "ODS"),
    Data = Value.NativeQuery(
        Source,
        "
        SELECT DISTINCT
            LTRIM(RTRIM(bom.IXMMCU)) AS [Branch Plant]
        FROM PRODDTA.F3002 bom
            -- REWORK #2 2026-07-14: stock type = F4102 branch grain (see
            -- Report.commented.m); F4101 master join dropped.
            INNER JOIN PRODDTA.F4102 pib
                ON pib.IBITM = bom.IXKIT
               AND LTRIM(RTRIM(pib.IBMCU)) = LTRIM(RTRIM(bom.IXMMCU))
            LEFT JOIN PRODDTA.F0006 org
                ON LTRIM(RTRIM(org.MCMCU)) = LTRIM(RTRIM(bom.IXMMCU))
        WHERE bom.IXTBM = 'M'
          AND pib.IBSTKT = 'M'
          -- LAB exclusion reworked 2026-07-14 (see Report.commented.m): NULL-safe
          -- style filter + LAB* branch-name exclusion; MCSTYL is not the DW's
          -- BRANCH_TYPE and NULL <> 'LAB' silently dropped rows.
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
