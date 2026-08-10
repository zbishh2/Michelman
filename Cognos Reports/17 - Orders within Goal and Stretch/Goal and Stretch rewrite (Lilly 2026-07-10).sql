-- Lilly's T-SQL for "Report - Orders within Goal and Stretch" (report ID 137)
-- Source: migration workbook tab "Orders within Goal and Stretch", from Lilly's 7/10/26 email
-- CAUTION: Lilly's original validation of this report NEVER PASSED ("historical data returning the wrong values")
DECLARE @Company        varchar(max) = NULL;
DECLARE @BusinessGroup  varchar(max) = NULL;
DECLARE @Customer       varchar(max) = NULL;
DECLARE @BulkItem       varchar(max) = NULL;
DECLARE @CSR            varchar(max) = NULL;
DECLARE @OrderStartDate date = '2026-06-01';
DECLARE @OrderEndDate   date = '2026-06-16';
DECLARE @StartJulian int =
    (YEAR(@OrderStartDate) - 1900) * 1000
    + DATEPART(DAYOFYEAR, @OrderStartDate);
DECLARE @EndJulian int =
    (YEAR(@OrderEndDate) - 1900) * 1000
    + DATEPART(DAYOFYEAR, @OrderEndDate);
WITH CSR AS (
    SELECT
        A.CMAN8,
        A.CMSLSM AS CSR_Number,
        B.ABALPH AS CSR_Name
    FROM PRODDTA.F42140 A WITH (NOLOCK)
    LEFT JOIN PRODDTA.F0101 B WITH (NOLOCK)
        ON A.CMSLSM = B.ABAN8
    WHERE A.CMRTYPE = 'CSR'
),
LedgerRows AS (
    SELECT
        L.SLDOCO AS Order_Number,
        L.SLLNID AS Line_Number,
        L.SLDCTO AS Order_Type,
        L.SLKCOO AS Company_Code,
        LTRIM(RTRIM(L.SLMCU)) AS Branch_Plant,
        L.SLAN8 AS Sold_To_Customer_Code,
        L.SLSHAN AS Ship_To_Customer_Code,
        LTRIM(RTRIM(L.SLLITM)) AS [2nd_Item_Number],
        L.SLUORG AS Ordered_Quantity,
        L.SLFRTH AS Freight_Handling_Code,
        L.SLLTTR AS Last_Status,
        L.SLNXTR AS Next_Status,
        L.SLTRDJ AS Order_Date_Julian,
        L.SLDRQJ AS Requested_Date_Julian,
        L.SLUPMJ AS Updated_Julian_Date,
        DATEADD(DAY, L.SLTRDJ % 1000 - 1,
            DATEFROMPARTS(1900 + L.SLTRDJ / 1000, 1, 1)
        ) AS Order_Date,
        CASE WHEN L.SLDRQJ > 0 THEN
            DATEADD(DAY, L.SLDRQJ % 1000 - 1,
                DATEFROMPARTS(1900 + L.SLDRQJ / 1000, 1, 1))
        END AS Requested_Date,
        CASE WHEN L.SLUPMJ > 0 THEN
            DATEADD(DAY, L.SLUPMJ % 1000 - 1,
                DATEFROMPARTS(1900 + L.SLUPMJ / 1000, 1, 1))
        END AS Updated_Date
    FROM PRODDTA.F42199 L WITH (NOLOCK)
    WHERE L.SLNXTR IN ('525','540')
      AND L.SLDCTO NOT IN ('S5','ST')
      AND L.SLTRDJ BETWEEN @StartJulian AND @EndJulian
      AND (@Company IS NULL OR L.SLKCOO = @Company )
),
Ledger540 AS (
    SELECT
        Order_Number,
        Line_Number,
        Order_Type,
        Company_Code,
        MIN(Updated_Date) AS Date540
    FROM LedgerRows
    WHERE Next_Status = '540'
    GROUP BY Order_Number, Line_Number, Order_Type, Company_Code
),
Ledger525 AS (
    SELECT
        L.Order_Number,
        L.Line_Number,
        L.Order_Type,
        L.Company_Code,
        MAX(Updated_Date) AS Date525
    FROM LedgerRows L
INNER JOIN Ledger540 G
On L.Order_Number = G.Order_Number
AND L.Line_Number = G.Line_Number
AND L.Order_Type = G.Order_Type
AND L.Company_Code = G.Company_Code
WHERE L.Next_Status = '525'
AND L.Updated_Date <= G.Date540
    GROUP BY L.Order_Number, L.Line_Number, L.Order_Type, L.Company_Code
),
BaseOrder AS (
    SELECT *
    FROM (
        SELECT
            L.*,
            ROW_NUMBER() OVER (
                PARTITION BY L.Order_Number, L.Line_Number, L.Order_Type, L.Company_Code
                ORDER BY L.Updated_Date Desc
            ) AS RN
        FROM LedgerRows L
INNER JOIN Ledger540 G
ON L.Order_Number = G.Order_Number
AND L.Line_Number = G.Line_Number
AND L.Order_Type = G.Order_Type
AND L.Company_Code = G.Company_Code
WHERE L.Next_Status = '525'
AND L.Updated_Date <= G.Date540
    ) X
    WHERE RN = 1
),
Joined AS (
    SELECT
        O.*,
        L525.Date525,
        L540.Date540
    FROM BaseOrder O
    INNER JOIN Ledger525 L525
        ON O.Order_Number = L525.Order_Number
       AND O.Line_Number = L525.Line_Number
       AND O.Order_Type = L525.Order_Type
       AND O.Company_Code = L525.Company_Code
    INNER JOIN Ledger540 L540
        ON O.Order_Number = L540.Order_Number
       AND O.Line_Number = L540.Line_Number
       AND O.Order_Type = L540.Order_Type
       AND O.Company_Code = L540.Company_Code
),
Adjusted AS (
    SELECT
        *,
        CASE
            WHEN DATENAME(WEEKDAY, Date525) = 'Saturday' THEN DATEADD(DAY, 2, Date525)
            WHEN DATENAME(WEEKDAY, Date525) = 'Sunday' THEN DATEADD(DAY, 1, Date525)
            ELSE Date525
        END AS Date525_Business,
        CASE
            WHEN DATENAME(WEEKDAY, Date540) = 'Saturday' THEN DATEADD(DAY, 2, Date540)
            WHEN DATENAME(WEEKDAY, Date540) = 'Sunday' THEN DATEADD(DAY, 1, Date540)
            ELSE Date540
        END AS Date540_Business,
CASE
WHEN DATENAME(WEEKDAY, Date540) = 'Saturday' THEN DATEADD(DAY, 2, Order_Date)
            WHEN DATENAME(WEEKDAY, Date540) = 'Sunday' THEN DATEADD(DAY, 1, Order_Date)
ELSE Order_Date
END AS Order_Date_Business
    FROM Joined
),
FinalCalc AS (
    SELECT
        *,
        DATEDIFF(DAY, Order_Date_Business, Date525_Business)
        - (DATEDIFF(WEEK, Order_Date_Business, Date525_Business) * 2)
        AS Business_Days_Between_525_540
    FROM Adjusted
)
SELECT
    F.Company_Code,
    F.Branch_Plant,
    BU.MCRP02 AS Company_Level_2_Code,
    BU.MCRP03 AS Business_Group,
    F.Freight_Handling_Code,
    F.Order_Number,
    F.Line_Number,
    F.Ordered_Quantity,
    F.[2nd_Item_Number],
    F.Sold_To_Customer_Code,
    SoldTo.ABALPH AS Sold_To_Customer_Name,
    F.Ship_To_Customer_Code,
    ShipTo.ABALPH AS Ship_To_Customer_Name,
    CSR.CSR_Number,
    CSR.CSR_Name,
    F.Order_Date,
    F.Date525 AS Confirmation_Date,
    F.Date540 AS Shipped_Date,
    F.Requested_Date,
    F.Business_Days_Between_525_540,
    CASE
        WHEN BU.MCRP02 = 'RAME' AND F.Business_Days_Between_525_540 <= 1 THEN 1
        WHEN BU.MCRP02 IN ('REUR','RASI') AND F.Business_Days_Between_525_540 <= 2 THEN 1
        ELSE 0
    END AS Goal,
    CASE WHEN F.Business_Days_Between_525_540 <= 1 THEN 1 ELSE 0 END AS Stretch,
    CASE WHEN F.Business_Days_Between_525_540 > 2 THEN 1 ELSE 0 END AS [Greater_Than_48H],
    CASE WHEN F.Business_Days_Between_525_540 < 3 THEN 1 ELSE 0 END AS [Less_Than_72H],
    CASE WHEN F.Business_Days_Between_525_540 > 3 THEN 1 ELSE 0 END AS [Greater_Than_72H]
FROM FinalCalc F
LEFT JOIN PRODDTA.F0006 BU WITH (NOLOCK)
    ON LTRIM(RTRIM(BU.MCMCU)) = F.Branch_Plant
LEFT JOIN PRODDTA.F0101 SoldTo WITH (NOLOCK)
    ON SoldTo.ABAN8 = F.Sold_To_Customer_Code
LEFT JOIN PRODDTA.F0101 ShipTo WITH (NOLOCK)
    ON ShipTo.ABAN8 = F.Ship_To_Customer_Code
LEFT JOIN CSR
    ON CSR.CMAN8 = F.Ship_To_Customer_Code
WHERE (@BusinessGroup IS NULL OR BU.MCRP03 IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@BusinessGroup, ',')))
  AND (@Customer IS NULL OR CAST(F.Sold_To_Customer_Code AS varchar(50)) IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@Customer, ',')))
  AND (@BulkItem IS NULL OR F.[2nd_Item_Number] IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@BulkItem, ',')))
  AND (@CSR IS NULL OR CAST(CSR.CSR_Number AS varchar(50)) IN (SELECT LTRIM(RTRIM(value)) FROM STRING_SPLIT(@CSR, ',')))
ORDER BY
    F.Order_Number,
    F.Line_Number;
