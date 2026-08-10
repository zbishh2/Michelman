-- =====================================================================
-- EDWPROD discovery / orientation (READ-ONLY)
-- Server: EDWPROD (SQL Server 14 / 2017), login NTDOM1\ZackB
-- NOTE: this is PROD. SELECT only. Do not run anything that writes.
-- Run each numbered block one at a time; paste results back to Zack.
-- =====================================================================

-- 1) What databases exist on this server? (find the EDW catalog — likely "EDW")
SELECT name
FROM sys.databases
ORDER BY name;
GO


-- 2) Switch to the EDW catalog, then find all sales-related tables/views.
--    >>> change [EDW] below if step 1 shows a different catalog name <<<
USE [EDW];
GO

SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE   -- TABLE_TYPE = BASE TABLE or VIEW
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%Sales%'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
GO


-- 3) Column truth for the sales detail table — exact names + datatypes.
--    Tells us whether [Order Type Desc], [Filter - Active Order Types], etc.
--    are real, or underscored / JDE-native (F-file) names.
SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, ORDINAL_POSITION
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'TbSales_Detail'
ORDER BY ORDINAL_POSITION;
GO


-- 4) If TbSales_Detail is a VIEW, capture its definition (source lineage —
--    shows which JDE/base tables it pulls from). Harmless if it's a base table
--    (returns NULL). Adjust schema if step 2 shows something other than BIQL.
SELECT OBJECT_DEFINITION(OBJECT_ID('BIQL.TbSales_Detail')) AS ViewDef;
GO


-- 5) Full BIQL schema column dump (only if you want me to design a semantic
--    model from source — gives every table/column in the schema). Skip for now
--    if it's huge; we can scope it later.
-- SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
-- FROM INFORMATION_SCHEMA.COLUMNS
-- WHERE TABLE_SCHEMA = 'BIQL'
-- ORDER BY TABLE_NAME, ORDINAL_POSITION;
-- GO
