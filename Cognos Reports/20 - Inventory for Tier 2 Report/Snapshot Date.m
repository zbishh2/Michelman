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

        SELECT CAST(DATEADD(DAY, v.n, @lo) AS date) AS [Date]
        FROM (SELECT TOP (DATEDIFF(DAY, @lo, @hi) + 1)
                     ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
              FROM sys.all_objects a WITH (NOLOCK)
                   CROSS JOIN sys.all_objects b WITH (NOLOCK)) v
        ",
        null,
        [EnableFolding = false]
    )
in
    Data
