// ============================================================================
// Report 22 - "CM - Information 2020 - Future" - TM ASSIGNMENT (lookup, hidden)
// COMMENTED MASTER. The shipped file is "TM Assignment.m" (comment-free, repo
// rule CLAUDE.md). Maintain the two in parallel; the code must stay
// byte-identical.
//
// One territory manager per customer, read by the model column
// Forecast[TM Name] = LOOKUPVALUE ( 'TM Assignment'[TM Name],
// 'TM Assignment'[Customer Code], Forecast[Customer Code] ). Not on any page.
//
// Why EDW: Cognos's forecast TM is the customer's commission assignment
// (INVENTORY_DEMAND_MEASURE.SALES_REP_ID, the legacy stamp of JDE F42140).
// BIQLTabular carries no customer-level TM - FactForecast's own Territory
// Manager is set for FC-group customers only, and Customer / Address carry
// none - so this is a documented field-level step down the source ladder
// (BUILD.md, COLLECTION_NOTES.md). EDW BIQL.TbTM_Max_Assignment holds the
// current assignment per ship-to and role; the FC-group TM when one exists,
// else the CS-group TM, reproduces Cognos on all 41 forecast customers
// (PROBE/11e_edw_customer_tm.csv). PPGTM rows are never used.
//
// EDW traps: Role is nchar (trimmed); Mailing Name can carry trailing blanks.
// A customer has at most one row per role, so ROW_NUMBER is deterministic;
// CommissionLineNum only breaks a tie that does not occur today.
// ============================================================================
let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
SET NOCOUNT ON;
SELECT
    [Customer Code],
    [TM Name],
    [TM Role]
FROM (
    SELECT
        -- Ship-to address number = FactForecast[AddressNum] = Forecast[Customer Code].
        m.[Ship To CC]                          AS [Customer Code],
        LTRIM(RTRIM(t.[Mailing Name]))          AS [TM Name],
        LTRIM(RTRIM(m.Role))                    AS [TM Role],
        -- FC-group assignment first, else CS-group.
        ROW_NUMBER() OVER (
            PARTITION BY m.[Ship To CC]
            ORDER BY CASE m.Role WHEN N'FCGTM' THEN 1 ELSE 2 END, m.CommissionLineNum
        )                                       AS rn
    FROM BIQL.TbTM_Max_Assignment m
    JOIN BIQL.TbTerritoryManager t
        ON t.TerritoryManagerSKey = m.TerritoryManagerSKey
    -- Never PPGTM: Cognos's SALES_REP_ID is the FC / CS commission rep.
    WHERE m.Role IN (N'FCGTM', N'CSGTM')
) x
WHERE rn = 1
",
        null,
        [EnableFolding = false]
    )
in
    Data
