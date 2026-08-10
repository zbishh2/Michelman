// ============================================================================
// Report 19 - "1 - Inventory - Safety Stock and Order Size" - QUERY 2 of 2
// COMMENTED MASTER. The shipped file is "Shipments.m" (comment-free, repo rule
// CLAUDE.md §1). Maintain the two in parallel.
//
// Cognos: ORDER_ACTIVITY + ORDER_ACTIVITY_MEASURES + 9 dimension aliases,
// aggregated over a 15-key GROUP BY. Net grain = order x item.
//
// TIES AT 5,675 / 5,675 against the tight capture (BUILD.md V19), reached by
// three corrections to the naive port (V22 territory manager LEFT JOIN,
// V23 CANCELLED_INDICATOR = StatusCodeLast, V24 global parent = AddressNum5th).
//
// Re-measured against the local SQL mirror at build time (BUILD.md V31), at
// the capture's own boundary 2026-02-05: 7,209 lines -> 5,675 grouped rows;
// Sum Ordered Quantity 39,590,713.21 (capture: 39,590,713.21, +0.000%);
// branch split CIN2 3,229 / AUBA 1,567 / SNG4 653 / CINC 209 / SING 17 -
// exact on every branch; 4,155 distinct orders; span 2026-02-05 -> 2026-08-07.
//
// GRAIN: this query returns LINE grain (7,209 rows), NOT the 5,675 Cognos
// output rows. The 15-key GROUP BY + SUM is reproduced by the table visual,
// which groups by its displayed columns and sums the three measures
// (BUILD.md §6). That keeps the model drillable and lets the §2 relationship
// work. It also means every identifier / text / date column must be
// summarizeBy: none in the TMDL, and the three quantities must be surfaced as
// MEASURES, or the visual shows line grain.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            -- Cognos substr(ORDER_LINE_ID,1,5). f.OrderCompany = the same
            -- thing: LEFT(OrderLineID,5) with 0 mismatches / 869,741 (V9).
            -- nchar(5), and it carries LEADING ZEROS ('00010'), so it must
            -- stay TEXT in the model - Int64 would render 10.
            f.OrderCompany                              AS [Order Company],
            LTRIM(RTRIM(f.BusinessUnit))                AS [Branch Plant],
            f.OrderNum                                  AS [Order Number],

            -- Item-branch side (ITEM.BULK_ITEM in Cognos).
            ib.[Item Bulk]                              AS [Bulk Item],

            -- FACT side, deliberately - Cognos reads MEASURE.ITEM_NUMBER_2ND,
            -- not the item dimension's. Do not 'tidy' this to ib.[Item Num 2nd].
            f.ItemNum2nd                                AS [2nd Item Number],
            f.OrderDate                                 AS [Ordered Date],

            -- ##### THE MEASURE TRAP (BUILD.md §0.1 / V11 / V20) #####
            -- Cognos computes sum(ORDERED_QTY * SALES_FACTOR). FactSalesDetail
            -- HAS a column called SalesFactor and it is NOT the conversion:
            -- measured, it is 1.0000 on 977,203 rows and 0.0000 on 2,140 -
            -- every row. The UOM conversion lives in QuantityOrderedPrimaryUOM,
            -- whose ratio to QuantityOrdered reproduces F41002.UMCONV exactly
            -- (TO->LB 2500, TO->KG 1000, DR->KG 200, B1->LB 44, KG->LB 2.204619)
            -- and which differs from QuantityOrdered on 65.7% of in-window lines.
            -- SUM(QuantityOrderedPrimaryUOM) matches Cognos on 5,674 / 5,674
            -- rows - 100.00% exact, totals agreeing to the cent.
            f.QuantityOrderedPrimaryUOM                 AS [Ordered Quantity Primary UOM],
            LTRIM(RTRIM(f.UOMTransaction))              AS [Ordering Unit of Measure],

            -- ##### THE WEIGHT BASIS (BUILD.md V38 / V40) #####
            -- This is the column the two weight measures are actually built
            -- from. Despite the name, Unit_Weight_Adj is the LINE TOTAL
            -- weight, NOT a per-unit weight, expressed in the unit named by
            -- UOM_Weight_Adj (domain: exactly 'LB' and 'KG', 0 NULLs, 0 zeros
            -- over all 7,663 probe lines). Proven structurally, not on one
            -- row: Unit_Weight_Adj / QuantityOrderedPrimaryUOM is exactly
            -- 1.000000 for every UOM pair whose primary UOM is already a
            -- weight (DR/LB, TO/KG, KG/KG, TO/LB, PL/KG, LB/LB, PA/KG, B1/KG),
            -- and only diverges where the primary UOM is EA and a real
            -- per-item weight is needed (B1/EA -> 20 KG or 44 LB).
            --
            -- The arithmetic stays in DAX (§5.1) - the weight basis is a
            -- business rule, and keeping it visible is what made this fix a
            -- two-line edit rather than a query rewrite.
            f.Unit_Weight_Adj                           AS [Line Weight Adj],
            LTRIM(RTRIM(f.UOM_Weight_Adj))              AS [Line Weight Adj UOM],

            -- DIAGNOSTIC ONLY - these two no longer drive the weight measures.
            -- They are the OLD basis (qty x factor), kept projected so anyone
            -- auditing a number can reproduce the superseded value and see the
            -- discrepancy for themselves. They are wrong on ~5% of rows in an
            -- item-specific way (ratios 2.0, 1/22, 60, 0.9072 ...) and cost
            -- +0.376% on both weight totals. Do NOT reintroduce them into the
            -- measures.
            f.ConversionFactorLB                        AS [Conversion Factor LB],
            f.ConversionFactorKG                        AS [Conversion Factor KG],

            f.PromisedShipmentDate                      AS [Promised Ship Date],
            f.ScheduledPickDate                         AS [Scheduled Pick Date],

            -- CUSTOMER_SHIP_TO.CUSTOMER_CODE = JDE AN8. 0 mismatches / 5,674.
            f.AddressNumShipTo                          AS [Customer Code],

            -- The trim is load-bearing: DimAddress.AddressDesc carries a
            -- LEADING SPACE on some rows (' 3 Print Adriatik (X) Celje SI')
            -- which Cognos does not render. 12 mismatches before the trim,
            -- 4 after (V21). The 4 survivors are genuine source differences
            -- (case, and trailing tabs inside the Cognos value) = 0.07%.
            LTRIM(RTRIM(sa.AddressDesc))                AS [Customer Name],

            -- ##### THE GLOBAL PARENT TRAP (BUILD.md §0.3 / V24) #####
            -- Cognos walks CUSTOMER_SHIP_TO.GLOBAL_REPORTING -> CUSTOMERID ->
            -- CUSTOMER.CUSTOMER_NAME. The intuitive EDW port is the fact's own
            -- ParentCustomerSKey / ParentAddressSKey and it reproduces Cognos
            -- on only 20.4% of rows. The address book's FIFTH address number
            -- does it on 99.9% (5,655 / 5,661). All seven candidates were
            -- tested; AddressNumParent scores 0.0%.
            -- The tell that this is right rather than lucky: the self-parent
            -- share matches EXACTLY (1,076 rows both sides), where
            -- ParentAddressSKey gave EDW 2,406 against Cognos's 1,084 - and
            -- the values read correctly ('Henkel - Global Parent',
            -- 'Grafix - Global Parent', 'Barentz - Global Parent'), which the
            -- AN8 parent chain never surfaces.
            LTRIM(RTRIM(p5.AddressDesc))                AS [Global Parent Name],

            -- Cognos data item 'Customer Segmentation Description', aliased
            -- c16 in the IBM SQL. The EXPORT HEADER confirms it renders as the
            -- full name - do not ship 'c16'. AC06, and BIQL.DimCustomer names
            -- its first six address category codes rather than numbering them,
            -- so this is CustomerSegmentationDesc. 0 mismatches vs AddressCode06
            -- over all 22,227 rows AND 0 vs the export (V9/V21). This is also
            -- why BIQL.TbCustomerShipTo (absent from the mirror) is NOT needed.
            sc.CustomerSegmentationDesc                 AS [Customer Segmentation Description],

            -- ##### THE TERRITORY MANAGER TRAP (BUILD.md §0.4 / V22) #####
            -- See the LEFT JOIN below. ISNULL supplies Cognos's rendering for
            -- the SKeys EDW's dimension cannot resolve.
            ISNULL(tm.[Mailing Name], 'Not Available')  AS [TM Name],

            -- Cognos joins CATEGORY_CODES_UDC (00,CN) to decode the country.
            -- EDW pre-decodes it, so that whole join disappears. 0 mismatches.
            sa.MailAddressCountryDesc                   AS [Country Name],

            -- Cognos to_date(sysdate) - a refresh stamp, constant on every row
            -- (2026-08-06 in the export). NOT sysdate-1 like report 18.
            CAST(GETDATE() AS date)                     AS [DATE],

            -- Not displayed. Input to the DAX India-tax rule (§5.2) - the SQL
            -- projects it and nothing else; the rule itself lives in DAX.
            ib.[Item Global Bulk]                       AS [Item Global Bulk],

            -- Not displayed. The §2 relationship to Safety Stock[ItemBranchSKey].
            f.ItemBranchSKey                            AS [ItemBranchSKey]

        -- ##### SOURCE OBJECT (BUILD.md V38 / V40) #####
        -- BIQL.FactSalesDetail (194 columns) rather than dbo.FactSalesDetail
        -- (186) - but NOT for the reason §0.5/§1.2 give. Their premise was
        -- that the view carries corrected CONVERSION FACTORS; jumpbox probe J1
        -- disproved that outright: the ratio query listing every line where
        -- the two disagree returned ZERO rows, and [Fix U/M] is populated on 0
        -- of 15,823 in-scope lines, so BIQL.FactSalesDetail_UOM_Fix is a red
        -- herring for this report. The view is used ONLY because it exposes
        -- Unit_Weight_Adj / UOM_Weight_Adj, which the table does not.
        --
        -- LOCAL VERIFIABILITY IS PRESERVED, which is worth knowing before
        -- anyone 'simplifies' this back. The view is absent from the local SQL
        -- mirror, but dbo.FactSalesDetail carries UnitWeight / UOMWeight and
        -- those are byte-identical to Unit_Weight_Adj / UOM_Weight_Adj on ALL
        -- 7,663 probe lines. Swapping the FROM to dbo and the two columns to
        -- UnitWeight/UOMWeight reproduces this query's weights EXACTLY against
        -- the mirror - same 98.96% / 99.00% exact, same -0.0021% totals (V40).
        -- 00_verify_tables.sql uses that substitution so the weight rule stays
        -- testable without a jumpbox trip. Ship the _Adj columns, because that
        -- is where a future item-weight correction will land.
        FROM BIQL.FactSalesDetail f WITH (NOLOCK)

            -- Four INNER, two LEFT. Measured join drops on the pre-filter base
            -- (V5): item-branch 0, ship-to customer 0, ship-to address 0,
            -- parent 0, territory manager 387 raw / 17 lines in the final set.
            -- All four dimensions are UNIQUE on their SKey (DimCustomer
            -- 22,227 = 22,227; DimAddress 37,339 = 37,339; TbItemBranch
            -- 116,002 = 116,002; TbTerritoryManager 19,321 = 19,321), so
            -- NOTHING fans out (V8).
            INNER JOIN BIQL.TbItemBranch       ib WITH (NOLOCK) ON ib.ItemBranchSKey       = f.ItemBranchSKey

            -- DimCustomer / DimAddress carry SCD2 columns but are ALREADY
            -- collapsed to one row per SKey. Adding an effective-date
            -- predicate to a SKey join here would be a bug.
            INNER JOIN BIQL.DimCustomer        sc WITH (NOLOCK) ON sc.CustomerSKey         = f.ShipToCustomerSKey
            INNER JOIN BIQL.DimAddress         sa WITH (NOLOCK) ON sa.AddressSKey          = f.ShipToAddressSKey

            -- ...but THIS one joins by address NUMBER, not SKey, so it DOES
            -- need DWIsCurrent = 1.
            LEFT  JOIN BIQL.DimAddress         p5 WITH (NOLOCK) ON p5.AddressNum           = sa.AddressNum5th
                                                               AND p5.DWIsCurrent          = 1

            -- LEFT, not INNER. Cognos's SALES_REP_ID = VENDOR_DIM_ID is a
            -- comma-join and therefore an inner join, so the faithful port is
            -- INNER - and that is exactly what drops the last 13 output rows
            -- (17 lines). BIQL.TbTerritoryManager is INCOMPLETE: 22 distinct
            -- TerritoryManagerSKey values on the fact do not resolve in it,
            -- including the -1 unknown member, while Cognos's VENDOR dimension
            -- resolves all of them. This is the one place EDW's dimension is
            -- THINNER than Oracle's, so the usual 'EDW denormalises, therefore
            -- the naive port over-includes' logic runs BACKWARDS.
            -- Cost of the fix: 8 wrong TM names out of 5,674 (§11 Q8).
            LEFT  JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK) ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey

        -- ##### FILTERS - BUILD.md §4.5. THIS EXACT SET REPRODUCES 5,675. #####
        -- A dropped or reordered predicate silently changes the answer; each
        -- miss has a known magnitude in the §10 diagnostic ladder.

        -- Cognos's real budget carve-out. Its own three budget predicates
        -- (BUDGET_FACTOR <> 1 and two DESCRIPTION_1 account exclusions gated on
        -- SALES_OR_GL = 'Budget Detail') are ALL INERT on EDW, and porting
        -- BUDGET_FACTOR <> 1 *instead of* this would let 109,602 GL/budget rows
        -- in. Measured: FactSalesDetail.BudgetFactor is 0.0000 on ALL 979,343
        -- rows (V10). Three dead predicates that look protective are worse than
        -- one live one. Equivalently SalesTableSource <> 5.
        WHERE f.RecordType = 'Sales Detail'

          -- ##### Cognos OPEN_INDICATOR <> 'Y' (BUILD.md §4.3, CORRECTED V39) #####
          -- The native SQL confirms OPEN_INDICATOR is a PLAIN PHYSICAL COLUMN
          -- on DW_LEGACY.ORDER_ACTIVITY - a stored Y/N flag, not a derived
          -- expression - so the port is a stored discriminator.
          --
          -- §4.3 originally ported it as SalesTableSource <> 1, and that TIES.
          -- It ties for the WRONG REASON. Report 21's jumpbox probe settled
          -- what OPEN_INDICATOR actually is, cross-tabbed against its own
          -- Cognos export over all 17,259 rows with ZERO exceptions:
          --     Open Indicator = 'N'  <=>  StatusCodeNext  = '999'   (16,363)
          --     Open Indicator = 'Y'  <=>  StatusCodeNext in 540/530/
          --                                560/535/580/525/550/570      (896)
          -- and it positively DISPROVED SalesTableSource there: report 21's
          -- population holds 252 lines with SalesTableSource = 1 AND
          -- StatusCodeNext = '999', which the two rules classify oppositely.
          --
          -- In REPORT 19's window the two are exactly equivalent - measured on
          -- the mirror under this file's full filter set (V39): zero lines
          -- where SalesTableSource = 1 AND StatusCodeNext = '999', zero where
          -- SalesTableSource <> 1 AND StatusCodeNext <> '999'. Both yield the
          -- same 7,209 lines and the same 5,675 output rows, so the tie is
          -- untouched by this change.
          --
          -- Switched anyway, because that equivalence is a property of THIS
          -- WINDOW, not of the data model. Report 21 proves the two diverge in
          -- a wider one, so the old predicate was one scope change away from
          -- being silently wrong - and it would have STAYED silently wrong,
          -- because it currently produces a perfect tie. Same answer, correct
          -- reason.
          --
          -- Candidates eliminated along the way: Source (constant 1 on all
          -- 979,343 rows), QuantityOpen <> 0 (unpopulated - zero rows),
          -- Cancelled_Flag (that is CANCELLED_INDICATOR, and a bad port of it).
          --
          -- StatusCodeNext is nchar(3) - the TRIM is load-bearing. Without it
          -- the comparison silently matches nothing and the table loads EMPTY.
          AND LTRIM(RTRIM(f.StatusCodeNext)) = '999'

          AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')

          -- ##### THE WINDOW BOUNDARY (BUILD.md §4.5 trap 1 / V17) #####
          -- Cognos: DUE_DATE >= to_date(sysdate - (182.5*1.0e0)). The
          -- subtraction happens INSIDE to_date(), and sysdate carries a time
          -- component, so the boundary MOVES WITH THE RUN'S TIME OF DAY:
          --   run before 12:00 -> lands D-183 in the evening -> truncates D-183
          --   run at/after 12:00 -> lands D-182 in the small hours -> D-182
          -- (Contrast report 21's to_date(sysdate) - 365, which truncates
          -- first and is deterministic. Report 19 is the ambiguous form.)
          -- The capture proves an AFTERNOON run: DATE = 2026-08-06 and the
          -- minimum Promised Ship Date is 2026-02-05 = D-182.
          --
          -- WE SHIP -183, deliberately. It is the more inclusive of the two,
          -- so the report can never silently DROP orders Cognos would have
          -- shown; for a six-month order-size analysis one extra day of
          -- history is harmless, a missing day is a defect the reader cannot
          -- see. A Power BI refresh runs on a schedule we control, so our
          -- result is deterministic even though Cognos's is not.
          -- CONSEQUENCE: against an afternoon Cognos capture this reads
          -- +51 rows / +0.90% (5,726 vs 5,675 - re-measured at build time,
          -- V31, exactly as predicted). Known, explained variance, NOT a miss.
          -- To reproduce a capture exactly, temporarily use -182.
          -- ALWAYS record the Cognos run's time of day with a capture.
          AND f.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))

          AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')

          -- The freight carve-out, and it ADMITS AN EMBEDDED F. Excluded set,
          -- measured (V10): FS 130,333 / FT 3,550 / FI 3,193 / CF 2,209
          -- ('Credit on Freight' - F in position 2) / FA 509 / FO 456 /
          -- FN 193 / FD 157 / FF 1 / 'F ' 1. A LIKE 'F%' 'simplification'
          -- would wrongly KEEP CF. Keep '%F%' verbatim.
          AND f.LineType NOT LIKE '%F%'

          -- ##### THE CANCELLED TRAP (BUILD.md §0.2 / V23) #####
          -- Cognos CANCELLED_INDICATOR <> 'Y'. FactSalesDetail.Cancelled_Flag
          -- LOOKS like the port and is not: it is set on only 366 rows
          -- model-wide and catches 118 of the 486 cancelled lines in scope,
          -- leaving the report +263 rows (+4.6%) too high - spread
          -- proportionally across every branch, which is exactly the kind of
          -- miss that reads as 'close enough'.
          -- The real discriminator is StatusCodeLast. In the final population,
          -- statuses 980 (311 lines) and 984 (57) have, on 100% of their rows,
          -- QuantityShipped = 0, QuantityCanceledScrapped <> 0 and
          -- AmountExtendedPrice = 0; every other status (620, 900, 912, 902)
          -- has QuantityCanceledScrapped = 0 on 100% of rows.
          -- Measured against the 5,675 target:
          --   (none)                             6,024
          --   Cancelled_Flag <> 1                5,938
          --   QuantityCanceledScrapped = 0       5,663  (semantic equivalent,
          --                                      but misses one status-980 line
          --                                      with a zero cancelled quantity)
          --   StatusCodeLast NOT IN ('980','984')  5,675  <-- ties
          AND f.StatusCodeLast NOT IN ('980','984')

          -- Cognos (ORDERED_QTY * SALES_FACTOR) > 0. Same §0.1 substitution -
          -- NOT QuantityOrdered * SalesFactor, whose naive form keeps the
          -- 2,140 SalesFactor = 0 rows out for the wrong reason.
          AND f.QuantityOrderedPrimaryUOM > 0

          -- Cognos AC01 CUSTOMER_TYPE_CODE <> 'INT'. BIQL.DimCustomer NAMES
          -- its first six address category codes instead of numbering them -
          -- SalesBusinessUnit(01), ShippingDocuments(02), PalletRequirements(03),
          -- LabelFormat(04), InternationalCustomer(05), CustomerSegmentation(06)
          -- - which is why AC01 does NOT map to the plausible-looking
          -- InternationalCustomer. Closed by a 0-mismatch check against
          -- dbo.DimCustomer.AddressCode01 over all 22,227 rows (V9); do not
          -- re-derive it from the name. Worth 319 rows.
          AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'

          -- 'Finished goods', same rule as query 1. Worth ~700 lines.
          AND ib.[Master Planning Family] LIKE '%F%'

        -- ##### DELIBERATELY NOT HERE #####
        -- The INDIA-TAX EXCLUSION. It is a business rule with a non-obvious
        -- two-column fallback, so it lives in DAX (BUILD.md §5.2 / V29): this
        -- query projects its two inputs ([Item Global Bulk] and
        -- [2nd Item Number]) and nothing more. Free to move because it removes
        -- ZERO rows here, so the import is byte-identical either way -
        -- re-confirmed at build time (V31).
        --
        -- Why it removes zero, with two independent causes (V28): the tax
        -- pseudo-items DO exist in EDW - ItemNum2nd is one of IGST/CGST/SGST/
        -- CVD/ADD on 15,316 lines - but every one is in an Indian branch plant
        -- (MUM3 14,167, MUM2 843, HARY 306), so 0 fall in the six branch
        -- plants AND 0 have an item-branch whose MPF matches '%F%' (theirs is
        -- blank). Either filter alone already excludes them.
        --
        -- Note for whoever ports the Oracle decode(GLOBAL_BULK_ITEM,'-',...):
        -- '-' is COGNOS RENDERING A NULL, not a stored sentinel. Measured over
        -- all 116,002 item-branches, [Item Global Bulk] is '-' on 0 rows,
        -- empty on 0, NULL on 17. So a literal = '-' test never matches on EDW
        -- and the fallback to 2nd item number becomes DEAD CODE, under-firing
        -- on exactly the rows it was written for - those 15,316 lines carry
        -- NULL. The DAX form tests for missing in all its shapes.
        --
        -- Also not here: BUDGET_FACTOR <> 1 and Cancelled_Flag <> 1 (above).
        --
        -- No ORDER BY (Power BI wraps this in SELECT * FROM ( ... )); the
        -- Cognos sort lives in the table visual. No SELECT DISTINCT: the
        -- Cognos query is a GROUP BY + SUM, not a dedup, and collapsing with
        -- DISTINCT would drop genuine repeat lines and understate the
        -- quantities (§4.5 trap 7).
        ",
        null,
        [EnableFolding = false]
    )
in
    Data

// ----------------------------------------------------------------------------
// RESIDUALS, disclosed rather than engineered around:
//  * ~1% of groups on the two weight columns (59 LB / 57 KG of 5,675), where
//    the DW and EDW genuinely disagree about an item's weight - NOT a formula
//    error. Column totals are -0.0021% (V40). Known examples: DF201-JG (export
//    8.34 LB, EDW 7.0, old basis 14.0 - neither reproduces it) and
//    251067CX.S-PD, whose Unit_Weight_Adj of 0.005 KG is simply wrong.
//    Superseded: the +0.376% this column used to carry (V25) is closed.
//  * +51 rows / +0.90% against an AFTERNOON Cognos capture - the deliberate
//    -183 boundary (V17).
//  * 4 rows each on Customer Name and Global Parent Name (0.07%) - genuine
//    source differences: case, and trailing tabs inside the Cognos value (V21).
//  * 8 TM Names out of 5,674 - the incomplete EDW territory-manager dimension
//    (V22). Upstream fix, §11 Q8.
//  * 1 row where Cognos's ITEM.BULK_ITEM renders '-' (NULL in DW_LEGACY) and
//    EDW's [Item Bulk] is 'DP050' - order 336252 / DP050-P2 / CINC. Every
//    other column on that row agrees, so the row set is 5,675 = 5,675 with one
//    item-master value difference, not a missing or extra row (V25 / §4.7).
// ----------------------------------------------------------------------------
