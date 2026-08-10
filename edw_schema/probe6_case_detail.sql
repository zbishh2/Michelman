-- probe6 — case-detail drill-through (Jessica's request, 2026-06-24)
-- Run on the JUMP BOX against EDWDEV (the live SF chain Complaints.m now points at).
-- Purpose: confirm whether the candidate "readable" product/champion columns carry
-- names/codes, or are also raw Salesforce IDs. Everything else Jessica asked for is
-- already a plain readable column (see edw_schema/03_columns.csv) and is added to
-- Complaints.m — this probe only settles the two ID-gap fields + the open picks.
-- Export result to edw_schema/ as CSV.

-- 1) Product + Champion: are the candidate columns readable, or more SF IDs?
SELECT TOP (40)
    CaseNumber,
    Product_Code__c,          -- known raw SF Product2 id (01t…)
    Unmapped_Products__c,     -- candidate readable product (nvarchar 255)
    Case_Product__c,          -- alt (likely another id)
    Product_Status__c,        -- alt text?
    Champion__c,              -- known raw SF User id (005…)
    I_am_Champion__c,         -- candidate readable champion name (nvarchar 1300)
    Operator__c               -- alt person text?
FROM BIQL.TbSF_Case
WHERE UPPER(LTRIM(RTRIM(Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY')
  AND (Unmapped_Products__c IS NOT NULL OR I_am_Champion__c IS NOT NULL)
ORDER BY Date_of_Occurance__c DESC;

-- 2) "Customer" pick — which field does Jessica mean? Show all candidates side by side.
SELECT TOP (40)
    CaseNumber,
    [Address Name],               -- readable customer name (nvarchar 40)
    Customer_Code__c,             -- JDE-ish customer code (nvarchar 40)
    Sold_To_Customer_Code__c,     -- sold-to (nvarchar 1300)
    Ship_To_Customer_Code__c,     -- ship-to (nvarchar 1300)
    Account_Segmentation__c       -- customer segmentation
FROM BIQL.TbSF_Case
WHERE UPPER(LTRIM(RTRIM(Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY')
ORDER BY Date_of_Occurance__c DESC;

-- 3) "Quantity" pick — Impacted vs Delivered (+ UOM) coverage on complaint rows.
SELECT
    COUNT(*) AS Cases,
    SUM(CASE WHEN Quantity_Impacted__c  IS NOT NULL THEN 1 ELSE 0 END) AS Has_Qty_Impacted,
    SUM(CASE WHEN Quantity_Delivered__c IS NOT NULL THEN 1 ELSE 0 END) AS Has_Qty_Delivered,
    SUM(CASE WHEN UOM__c IS NOT NULL THEN 1 ELSE 0 END)                AS Has_UOM
FROM BIQL.TbSF_Case
WHERE UPPER(LTRIM(RTRIM(Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY');

-- 4) "Root cause type" — no dedicated column. See what Detail_1 / Detail_2 actually hold.
SELECT TOP (30) Root_Cause_Detail_1__c, COUNT(*) AS n
FROM BIQL.TbSF_Case
WHERE UPPER(LTRIM(RTRIM(Level_1__c))) IN ('PRODUCT QUALITY','PRODUCT DELIVERY')
  AND Root_Cause_Detail_1__c IS NOT NULL
GROUP BY Root_Cause_Detail_1__c ORDER BY n DESC;
