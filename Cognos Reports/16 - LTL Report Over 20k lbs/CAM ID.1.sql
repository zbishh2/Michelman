-- Report 16 - LTL report over 20k lbs
-- Query object: "CAM ID"  ->  Cognos [JDE Live Data].[User Details]
-- Source: Cognos "Generated SQL.txt" (live popup, 2026-07-15) SELECT #2.
-- Byte-identical to the workbook-captured "User Details.1.sql" (reference copy);
-- this standard-named file is authoritative.
--
-- ROLE: BURST DISTRIBUTION PLUMBING ONLY. Maps a CSR's JDE address number
-- (VENDOR_CODE / "AB Number") to their Cognos directory account (CAMID). Query1
-- joins this to the main "Report" query on CSR AB Number = AB Number purely so the
-- burst can deliver each CSR's slice to their directory entry. NONE of these
-- columns (ALT_NAME, VENDOR_CODE, CAMID) appears on the rendered page.
-- => The Power BI rebuild does NOT need USER_DETAILS. See BUILD.md "Burst analysis".

select "USER_DETAILS"."ALT_NAME", "USER_DETAILS"."VENDOR_CODE", "USER_DETAILS"."CAMID"
 from "DW_LEGACY"."USER_DETAILS" "USER_DETAILS"
 where "USER_DETAILS"."VENDOR_CODE"<>N'-'
