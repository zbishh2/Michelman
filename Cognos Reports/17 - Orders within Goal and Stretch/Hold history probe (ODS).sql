/* ============================================================================
   Is hold-code history recoverable from the JDE sales order ledger?

   Server:   ODSPROD        Database:  ODS
   Runtime:  Q1 and Q2 scan F42199 (~19.6M rows); seconds, read-only throughout.

   Four questions, in order. Q1/Q2 test the ledger, Q3 confirms holds exist at
   all, Q4 puts the two together on the same orders.
   ============================================================================ */

SET NOCOUNT ON;


/* --- Q1: how many ledger rows carry a hold code? ------------------------- */

SELECT
    'F42199.SLHOLD' AS TableAndColumn,
    COUNT_BIG(*)                                                              AS TotalRows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(SLHOLD)), '') IS     NULL THEN 1 ELSE 0 END) AS BlankOrNull,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(SLHOLD)), '') IS NOT NULL THEN 1 ELSE 0 END) AS Populated,
    COUNT(DISTINCT NULLIF(LTRIM(RTRIM(SLHOLD)), ''))                          AS DistinctCodes
FROM PRODDTA.F42199;


/* --- Q2: show any ledger row that carries one. Returns no rows. ---------- */

SELECT TOP 20
    l.SLKCOO        AS OrderCompany,
    l.SLDOCO        AS OrderNumber,
    l.SLDCTO        AS OrderType,
    l.SLLNID        AS LineNumber,
    l.SLUPMJ        AS UpdatedJulian,
    '[' + LTRIM(RTRIM(l.SLHOLD)) + ']' AS HoldCode
FROM PRODDTA.F42199 l
WHERE NULLIF(LTRIM(RTRIM(l.SLHOLD)), '') IS NOT NULL;


/* --- Q3: holds do exist -- on the order header, as current state. -------- */

SELECT
    LTRIM(RTRIM(h.SHHOLD)) AS HoldCode,
    COUNT_BIG(*)           AS OrdersOnHoldNow
FROM PRODDTA.F4201 h
WHERE NULLIF(LTRIM(RTRIM(h.SHHOLD)), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(h.SHHOLD))
ORDER BY OrdersOnHoldNow DESC;


/* --- Q4: for orders on hold RIGHT NOW, what does their own ledger say? ---
   LedgerRowsCarryingAHold is zero on every code: an order can be sitting on a
   C1 credit hold this minute and its full ledger stream still says nothing.
   The ledger records status changes, and a hold does not change status.       */

SELECT
    LTRIM(RTRIM(h.SHHOLD))   AS CurrentHoldCode,
    COUNT(DISTINCT h.SHDOCO) AS HeldOrders,
    COUNT_BIG(l.SLDOCO)      AS TheirLedgerRows,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(l.SLHOLD)), '') IS NOT NULL THEN 1 ELSE 0 END)
                             AS LedgerRowsCarryingAHold
FROM PRODDTA.F4201 h
JOIN PRODDTA.F42199 l
  ON  l.SLKCOO = h.SHKCOO
  AND l.SLDOCO = h.SHDOCO
  AND l.SLDCTO = h.SHDCTO
WHERE NULLIF(LTRIM(RTRIM(h.SHHOLD)), '') IS NOT NULL
GROUP BY LTRIM(RTRIM(h.SHHOLD))
ORDER BY HeldOrders DESC;
