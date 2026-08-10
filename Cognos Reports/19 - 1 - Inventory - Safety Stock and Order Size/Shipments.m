let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            f.OrderCompany                              AS [Order Company],
            LTRIM(RTRIM(f.BusinessUnit))                AS [Branch Plant],
            f.OrderNum                                  AS [Order Number],
            ib.[Item Bulk]                              AS [Bulk Item],
            f.ItemNum2nd                                AS [2nd Item Number],
            f.OrderDate                                 AS [Ordered Date],
            f.QuantityOrderedPrimaryUOM                 AS [Ordered Quantity Primary UOM],
            LTRIM(RTRIM(f.UOMTransaction))              AS [Ordering Unit of Measure],
            f.Unit_Weight_Adj                           AS [Line Weight Adj],
            LTRIM(RTRIM(f.UOM_Weight_Adj))              AS [Line Weight Adj UOM],
            f.ConversionFactorLB                        AS [Conversion Factor LB],
            f.ConversionFactorKG                        AS [Conversion Factor KG],
            f.PromisedShipmentDate                      AS [Promised Ship Date],
            f.ScheduledPickDate                         AS [Scheduled Pick Date],
            f.AddressNumShipTo                          AS [Customer Code],
            LTRIM(RTRIM(sa.AddressDesc))                AS [Customer Name],
            LTRIM(RTRIM(p5.AddressDesc))                AS [Global Parent Name],
            sc.CustomerSegmentationDesc                 AS [Customer Segmentation Description],
            ISNULL(tm.[Mailing Name], 'Not Available')  AS [TM Name],
            sa.MailAddressCountryDesc                   AS [Country Name],
            CAST(GETDATE() AS date)                     AS [DATE],
            ib.[Item Global Bulk]                       AS [Item Global Bulk],
            f.ItemBranchSKey                            AS [ItemBranchSKey]
        FROM BIQL.FactSalesDetail f WITH (NOLOCK)
            INNER JOIN BIQL.TbItemBranch       ib WITH (NOLOCK) ON ib.ItemBranchSKey       = f.ItemBranchSKey
            INNER JOIN BIQL.DimCustomer        sc WITH (NOLOCK) ON sc.CustomerSKey         = f.ShipToCustomerSKey
            INNER JOIN BIQL.DimAddress         sa WITH (NOLOCK) ON sa.AddressSKey          = f.ShipToAddressSKey
            LEFT  JOIN BIQL.DimAddress         p5 WITH (NOLOCK) ON p5.AddressNum           = sa.AddressNum5th
                                                               AND p5.DWIsCurrent          = 1
            LEFT  JOIN BIQL.TbTerritoryManager tm WITH (NOLOCK) ON tm.TerritoryManagerSKey = f.TerritoryManagerSKey
        WHERE f.RecordType = 'Sales Detail'
          AND LTRIM(RTRIM(f.StatusCodeNext)) = '999'
          AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC','CIN2','AUBA','AUB2','SING','SNG4')
          AND f.PromisedShipmentDate >= DATEADD(DAY, -183, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(f.OrderType)) NOT IN ('S5','ST')
          AND f.LineType NOT LIKE '%F%'
          AND f.StatusCodeLast NOT IN ('980','984')
          AND f.QuantityOrderedPrimaryUOM > 0
          AND LTRIM(RTRIM(ISNULL(sc.SalesBusinessUnit,''))) <> 'INT'
          AND ib.[Master Planning Family] LIKE '%F%'
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
