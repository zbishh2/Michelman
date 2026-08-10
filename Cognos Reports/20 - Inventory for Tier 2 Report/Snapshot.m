let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        DECLARE @lo date, @hi date;

        SELECT @lo = MIN(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END),
               @hi = MAX(CASE WHEN CompanySKey = 2 THEN DATEADD(DAY, -1, StartDate) ELSE StartDate END)
        FROM dbo.FactInventorySnapshot_History WITH (NOLOCK)
        WHERE LTRIM(RTRIM(BusinessUnit)) IN ('CINC', 'CIN2');

        SELECT CAST(DATEADD(DAY, v.n, @lo) AS date) AS CalendarDate
        INTO #dates
        FROM (SELECT TOP (DATEDIFF(DAY, @lo, @hi) + 1)
                     ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
              FROM sys.all_objects a WITH (NOLOCK)
                   CROSS JOIN sys.all_objects b WITH (NOLOCK)) v;
        CREATE UNIQUE CLUSTERED INDEX ix_dates ON #dates (CalendarDate);

        SELECT z.ItemNumShort, z.BU, z.KGperPrim
        INTO #kgf
        FROM (SELECT k.ItemNumShort,
                     ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '') AS BU,
                     k.KG / CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary)) THEN 1.0
                                 ELSE NULLIF(k.ConversionFactorSecToPrim, 0) END AS KGperPrim,
                     ROW_NUMBER() OVER (PARTITION BY k.ItemNumShort, ISNULL(LTRIM(RTRIM(k.BusinessUnit)), '')
                                        ORDER BY CASE WHEN LTRIM(RTRIM(k.UOM)) = LTRIM(RTRIM(k.UOMPrimary))
                                                      THEN 0 ELSE 1 END, k.UOM) AS rn
              FROM BIQL.DimItemUOMConversionLBKG k WITH (NOLOCK)) z
        WHERE z.rn = 1;
        CREATE UNIQUE CLUSTERED INDEX ix_kgf ON #kgf (ItemNumShort, BU);

        SELECT
            CAST(c.CalendarDate AS date)                AS [Inventory Date],
            LTRIM(RTRIM(snap.BusinessUnit))             AS [Branch Plant],
            ib.[Item Num 2nd]                           AS [2nd Item Number],
            ib.[Item Bulk]                              AS [Bulk Item],
            ib.[Item Global Bulk]                       AS [Global Bulk Item],
            LTRIM(RTRIM(ib.[Master Planning Family]))   AS [Master Planning Family],
            snap.QuantityOnHandPrimaryUOM               AS [Quantity on Hand],
            LTRIM(RTRIM(snap.UOMPrimary))               AS [Primary UOM],
            COALESCE(kx.KGperPrim, kb.KGperPrim)        AS [KG per Primary Unit],
            LTRIM(RTRIM(snap.Location))                 AS [Location],
            LTRIM(RTRIM(snap.LotNum))                   AS [Lot Number],
            snap.LotStatusCode                          AS [Lot Status],
            snap.ItemBranchSKey                         AS [ItemBranchSKey]
        FROM #dates c
            INNER JOIN dbo.FactInventorySnapshot_History snap WITH (NOLOCK)
                    ON (CASE WHEN snap.CompanySKey = 2 THEN DATEADD(DAY, 1, c.CalendarDate)
                             ELSE c.CalendarDate END)
                       BETWEEN snap.StartDate AND ISNULL(snap.StopDate, '9999-12-31')
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = snap.ItemBranchSKey
            LEFT  JOIN #kgf kx ON kx.ItemNumShort = snap.ItemNumShort
                              AND kx.BU = LTRIM(RTRIM(snap.BusinessUnit))
            LEFT  JOIN #kgf kb ON kb.ItemNumShort = snap.ItemNumShort
                              AND kb.BU = ''
        WHERE LTRIM(RTRIM(snap.BusinessUnit)) IN ('CINC', 'CIN2')
          AND snap.QuantityOnHandPrimaryUOM <> 0
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
