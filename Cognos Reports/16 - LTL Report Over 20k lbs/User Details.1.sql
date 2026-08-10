-- Old Cognos-generated SQL (Oracle) — DW_LEGACY.USER_DETAILS CAM-ID lookup for "LTL report over 20k lbs" (report ID 142)
-- Source: migration workbook tab "Code to Validate LTL over 20k" ("OLD report code", second query)
-- SQL-Server-side analogue in Lilly's rewrite: [EDWPROD].[EDW].[dbo].[vw_CAM_ID]
select "USER_DETAILS"."ALT_NAME", "USER_DETAILS"."VENDOR_CODE", "USER_DETAILS"."CAMID"
from "DW_LEGACY"."USER_DETAILS" "USER_DETAILS"
where "USER_DETAILS"."VENDOR_CODE"<>N'-'
