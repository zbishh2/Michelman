let
    Source = Sql.Database("EDWPROD", "EDW"),
    Data = Value.NativeQuery(
        Source,
        "
        SET NOCOUNT ON;

        SELECT
            f.OrderCompany                               AS [Order Company],
            LTRIM(RTRIM(f.BusinessUnit))                 AS [Branch Plant],
            ib.[Item Global Bulk]                        AS [Global Bulk Item],
            ib.[Item Bulk]                               AS [Bulk Item],
            f.ItemNum2nd                                 AS [2nd Item Number],
            CAST(f.OrderNum AS varchar(12))              AS [Order Number],
            LEFT(CASE WHEN f.LineNum = FLOOR(f.LineNum)
                      THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
                      ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12))
                 END, 5)                                 AS [Line Number],
            LTRIM(RTRIM(f.StatusCodeLast))               AS [Last Status],
            LTRIM(RTRIM(f.StatusCodeNext))               AS [Next Status],
            f.PromisedShipmentDate                       AS [Promised Ship Date],
            SUM(f.QuantityOrderedPrimaryUOM)             AS [Ordered Quantity],
            LTRIM(RTRIM(f.UOMTransaction))               AS [Ordering Unit of Measure],
            LTRIM(RTRIM(f.LineType))                     AS [Line Type],
            CAST(f.AddressNumShipTo AS varchar(12))      AS [Customer Code],
            a.AddressDesc                                AS [Customer Name],
            LTRIM(RTRIM(f.OrderType))                    AS [Order Type Code],
            LTRIM(RTRIM(MIN(f.UOMPrimary)))              AS [Primary Unit of Measure],
            MIN(f.ConversionFactorKG)                    AS [KG Factor]
        FROM dbo.FactSalesDetail f WITH (NOLOCK)
            INNER JOIN BIQL.TbItemBranch ib WITH (NOLOCK)
                    ON ib.ItemBranchSKey = f.ItemBranchSKey
            INNER JOIN dbo.DimCustomer c WITH (NOLOCK)
                    ON c.CustomerSKey = f.ShipToCustomerSKey
            INNER JOIN dbo.DimAddress a WITH (NOLOCK)
                    ON a.AddressSKey = c.AddressSKey
        WHERE f.QuantityOrderedPrimaryUOM > 0
          AND (f.QuantityOrdered - f.QuantityCanceledScrapped) > 0
          AND f.PromisedShipmentDate >= DATEADD(DAY, -365, CAST(GETDATE() AS date))
          AND LTRIM(RTRIM(f.LineType)) = 'S'
          AND LTRIM(RTRIM(f.OrderType)) NOT IN ('ST')
          AND LTRIM(RTRIM(f.BusinessUnit)) IN ('CINC', 'CIN2', 'CINC', 'AUBA', 'AUB2', 'SING', 'SNG4')
          AND LTRIM(RTRIM(ib.[Category GL F4101])) = 'IN32'
          AND COALESCE( NULLIF( NULLIF( LTRIM(RTRIM(ISNULL(ib.[Item Global Bulk], ''))), '' ), '-' ),
                        LTRIM(RTRIM(f.ItemNum2nd)) )
              NOT IN ('IGST', 'CGST', 'SGST', 'CVD', 'ADD')
        GROUP BY
            f.OrderCompany,
            LTRIM(RTRIM(f.BusinessUnit)),
            ib.[Item Global Bulk],
            ib.[Item Bulk],
            f.ItemNum2nd,
            CAST(f.OrderNum AS varchar(12)),
            LEFT(CASE WHEN f.LineNum = FLOOR(f.LineNum)
                      THEN CAST(CAST(f.LineNum AS int) AS varchar(12))
                      ELSE CAST(CAST(f.LineNum AS decimal(9,3)) AS varchar(12))
                 END, 5),
            LTRIM(RTRIM(f.StatusCodeLast)),
            LTRIM(RTRIM(f.StatusCodeNext)),
            f.PromisedShipmentDate,
            LTRIM(RTRIM(f.UOMTransaction)),
            LTRIM(RTRIM(f.LineType)),
            CAST(f.AddressNumShipTo AS varchar(12)),
            a.AddressDesc,
            LTRIM(RTRIM(f.OrderType))
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
