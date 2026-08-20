SET NOCOUNT ON;
SELECT
    [Customer Code],
    [TM Name],
    [TM Role]
FROM (
    SELECT
        m.[Ship To CC]                          AS [Customer Code],
        LTRIM(RTRIM(t.[Mailing Name]))          AS [TM Name],
        LTRIM(RTRIM(m.Role))                    AS [TM Role],
        ROW_NUMBER() OVER (
            PARTITION BY m.[Ship To CC]
            ORDER BY CASE m.Role WHEN N'FCGTM' THEN 1 ELSE 2 END, m.CommissionLineNum
        )                                       AS rn
    FROM BIQL.TbTM_Max_Assignment m
    JOIN BIQL.TbTerritoryManager t
        ON t.TerritoryManagerSKey = m.TerritoryManagerSKey
    WHERE m.Role IN (N'FCGTM', N'CSGTM')
) x
WHERE rn = 1
