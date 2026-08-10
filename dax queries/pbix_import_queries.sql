/* =============================================================================
   Power BI IMPORT queries — load JDE tables into a PBIX so Claude can query the
   data locally (via the powerbi-modeling MCP) with no jump box per query.

   HOW TO USE:
     1. Power BI Desktop (ON THE JUMP BOX) -> Get Data -> SQL Server database
     2. Server: EDWPROD.michem.com   (or the ODS server that holds PRODDTA)
        Database: leave blank or the DB that contains PRODDTA
        Data Connectivity mode: **Import**  (NOT DirectQuery)
     3. Expand "Advanced options", paste ONE query below into "SQL statement",
        click OK, then Load.  Repeat Get Data for each table.
     4. Save the .pbix, copy to the laptop, open it there. Tell Claude it's open.

   Notes:
     - Import mode bakes the data into the file -> queryable on the laptop offline.
     - Columns are pruned to what we use + the date-change-reason candidates
       (SLURCD/SLURRF/SLURDT, SLNTR, SLHOLD). Add "SELECT *" if you'd rather grab
       everything (bigger file, slower load).
     - Dates stay as raw JDE Julian ints; Claude converts them in DAX.
     - To shrink F42199 (19.4M rows): uncomment the WHERE. 122001 = 2022-001.
   ============================================================================= */


/* ---- Table 1: F42199  (Sales Order Ledger — the change history) ------------ */
SELECT  SLKCOO, SLDOCO, SLDCTO, SLSFXO, SLLNID, SLMCU, SLLITM, SLLNTY,
        SLNXTR, SLLTTR,
        SLRCD,                                  -- line reason code (returns/credits)
        SLURCD, SLURRF, SLURDT,                 -- user-reserved: date-change reason candidates
        SLNTR, SLHOLD,                          -- other code fields worth checking
        SLPDDJ, SLOPDJ, SLDRQJ, SLRSDJ,         -- promised / original / requested / sched dates
        SLADDJ, SLCNDJ, SLDGL,                  -- actual ship / cancel / GL dates
        SLUPMJ, SLTDAY, SLUSER, SLPID, SLJOBN   -- audit: when / who wrote the row
FROM    PRODDTA.F42199
-- WHERE SLUPMJ >= 122001   -- optional: 2022+ only, to shrink the import
;


/* ---- Table 2: F0005  (UDC master — code descriptions; small, grab it all) -- */
SELECT  DRSY, DRRT, DRKY, DRDL01, DRDL02, DRSPHD
FROM    PRODDTA.F0005
;


/* ---- Table 3: F4211  (Sales Order Detail — CURRENT open orders) ------------ */
SELECT  SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDLNTY,
        SDNXTR, SDLTTR, SDRCD,
        SDPDDJ, SDOPDJ, SDDRQJ, SDRSDJ, SDADDJ, SDCNDJ, SDDGL,
        SDUPMJ, SDTDAY, SDUSER, SDPID
FROM    PRODDTA.F4211
;


/* ---- Table 4 (optional): F42119  (Sales Order Detail HISTORY — closed) ----- */
-- Large. Skip unless we need closed-order history. Same layout as F4211 (SD...).
-- SELECT  SDKCOO, SDDOCO, SDDCTO, SDSFXO, SDLNID, SDMCU, SDLITM, SDLNTY,
--         SDNXTR, SDLTTR, SDRCD,
--         SDPDDJ, SDOPDJ, SDDRQJ, SDRSDJ, SDADDJ, SDCNDJ, SDDGL,
--         SDUPMJ, SDTDAY, SDUSER, SDPID
-- FROM    PRODDTA.F42119
-- ;
