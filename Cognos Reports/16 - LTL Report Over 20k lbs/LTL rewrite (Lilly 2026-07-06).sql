-- Lilly's rewritten T-SQL for "LTL report over 20k lbs" (report ID 142)
-- Source: migration workbook tab "Code to Validate LTL over 20k", from Lilly's 7/6/26 email
WITH F42140_CSR AS
(
    SELECT
        C.CMAN8,
        C.CMSLSM,
        A.ABALPH AS CSR_Name
    FROM PRODDTA.F42140 AS C
    INNER JOIN PRODDTA.F0101 AS A
        ON C.CMSLSM = A.ABAN8
    WHERE C.CMRTYPE = 'CSR'
),
BaseData AS
(
    SELECT
        F.SDKCOO AS Order_Company,
        F.SDDOCO AS Order_Number,
        F.SDDCTO AS Order_Type,
        F.SDCARS AS Carrier_AB_Number,
        Carrier.ABALPH AS Carrier_Name,
        CSR.CSR_Name AS Cognos_CSR_Name,
        CAST(F.SDPQOR AS DECIMAL(18,4)) / 10000.0 AS Primary_Quantity_Ordered,
        F.SDUOM1 AS Primary_UOM,
        F.SDNXTR AS Next_Status,
        ShipTo.ABALPH AS Customer_Name,
        CAST(F.SDLNID AS DECIMAL(18,3)) / 1000.0 AS Order_Line,
        CASE
            WHEN F.SDPDDJ > 0 THEN
                DATEADD(
                    DAY,
                    (F.SDPDDJ % 1000) - 1,
                    DATEFROMPARTS((F.SDPDDJ / 1000) + 1900, 1, 1)
                )
            ELSE NULL
        END AS Scheduled_Pick_Date,
        CSR.CMSLSM AS CSR_AB_Number
    FROM PRODDTA.F4211 AS F WITH (NOLOCK)
    INNER JOIN PRODDTA.F0101 AS ShipTo  WITH (NOLOCK)
        ON F.SDSHAN = ShipTo.ABAN8
    LEFT JOIN F42140_CSR AS CSR  WITH (NOLOCK)
        ON F.SDSHAN = CSR.CMAN8
    LEFT JOIN PRODDTA.F0101 AS Carrier  WITH (NOLOCK)
        ON F.SDCARS = Carrier.ABAN8
    WHERE
        F.SDKCOO = '00010'
        AND F.SDDCTO IN ('S4','S5','SZ','SC','ST')
        AND F.SDNXTR IN ('560','550','545','540','535','530','525')
        AND F.SDCARS NOT IN
        (
            293371, 29671, 288676, 26185, 293492,
            98725, 301322, 195487, 136656, 293919,
            304977, 309791, 301333, 309741, 27710,
            26171, 283919, 26175, 301761, 292099,
            309757, 316502
        )
        AND F.SDCARS <> 308636
)
SELECT
    B.Scheduled_Pick_Date,
    B.Carrier_AB_Number,
    B.Customer_Name,
    B.Order_Number,
    B.Next_Status,
    B.Order_Type,
    B.Order_Line,
    B.Carrier_Name,
    COALESCE(V.CSRName, B.Cognos_CSR_Name) AS CSR_Name,
    SUM(B.Primary_Quantity_Ordered) AS Primary_Quantity_Ordered,
    B.Primary_UOM
FROM BaseData AS B
LEFT JOIN [EDWPROD].[EDW].[dbo].[vw_CAM_ID] AS V
    ON B.Order_Number = V.OrderNum
GROUP BY
    B.Scheduled_Pick_Date,
    B.Carrier_AB_Number,
    B.Customer_Name,
    B.Order_Number,
    B.Next_Status,
    B.Order_Type,
    B.Order_Line,
    B.Carrier_Name,
    COALESCE(V.CSRName, B.Cognos_CSR_Name),
    B.Primary_UOM
HAVING
    SUM(B.Primary_Quantity_Ordered) > 20000
ORDER BY
    B.Scheduled_Pick_Date,
    B.Carrier_AB_Number,
    B.Customer_Name,
    B.Order_Number;
