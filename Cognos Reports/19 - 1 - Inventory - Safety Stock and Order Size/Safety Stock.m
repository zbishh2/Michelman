let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            LTRIM(RTRIM(ib.[Business Unit]))            AS [Branch Plant],
            ib.[Item Bulk]                              AS [Bulk Item],
            ib.[Item Num 2nd]                           AS [2nd Item Number],
            LTRIM(RTRIM(ib.[Stocking Type]))            AS [Stock Type Code],
            LTRIM(RTRIM(ib.[Master Planning Family]))   AS [Master Planning Family],
            ib.[Lead Time MFG_BP]                       AS [Lead Time Order to Ship],
            ib.[Planner Num]                            AS [Planner Number],
            LTRIM(RTRIM(ib.[Planner Name]))             AS [Planner Name (EDW)],
            ib.SafetyStock                              AS [Safety Stock],
            LTRIM(RTRIM(ib.[UOM Primary]))              AS [Unit of Measure Primary],
            ib.ItemBranchSKey                           AS [ItemBranchSKey]
        FROM BIQL.TbItemBranch ib WITH (NOLOCK)
        WHERE LTRIM(RTRIM(ib.[Business Unit])) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
          AND ib.SafetyStock > 1
          AND LTRIM(RTRIM(ib.[Stocking Type])) NOT IN ('O')
          AND ib.[Master Planning Family] LIKE '%F%'
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
