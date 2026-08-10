-- 07d: Memo Lot column-identity probe (run on jumpbox SSMS vs ODSPROD)
-- Question: is DimLot.MemoLot2 the same JDE field (F4108.IOLOT2) Cognos's MEMO_LOT_2 reads,
-- or is one side shifted (F4108 has IOLOT1/IOLOT2/IOLOT3 per the v2.xmla TbLot lineage)?
-- Local evidence already says SAME FIELD (782 non-blank exact matches vs 44 diffs on shared keys;
-- zero cross-column identity). This probe closes it against raw JDE.
--
-- Verdict key (per sample lot):
--   F4108.IOLOT2 == PBI model value  -> our column is right; Cognos Oracle DW lot dim is stale
--                                       (insert-current / update-blind) -> disclosure, no code change.
--   F4108.IOLOT2 == Cognos value     -> EDW DimLot.MemoLot2 is stale or mis-mapped -> defect, fix EDW side.
--   IOLOT3 == either side's value    -> genuine column shift -> remap.
SELECT  LTRIM(RTRIM(IOMCU))  AS BranchPlant,
        LTRIM(RTRIM(IOLITM)) AS Item2nd,
        LTRIM(RTRIM(IOLOTN)) AS LotNumber,
        LTRIM(RTRIM(IORLOT)) AS SupplierLot,
        LTRIM(RTRIM(IOLOT1)) AS MemoLot1,
        LTRIM(RTRIM(IOLOT2)) AS MemoLot2,
        LTRIM(RTRIM(IOLOT3)) AS MemoLot3,
        IOUPMJ               AS DateUpdatedJulian
FROM    PRODDTA.F4108
WHERE   LTRIM(RTRIM(IOLOTN)) IN
        ('618710','618711','614986','619139','619255','4567667','DP680-210125','4573338','615462','4583660','618749')
ORDER BY LotNumber, BranchPlant;
-- Sample coverage: 618710/618711 + 4567667 + DP680-210125 (model populated, Cognos blank incl. the
-- 'REQC LE 16/07/26' July-16 edits), 614986 + 4573338 (both populated, different text),
-- 619139 ('T:' vs 'T:77%' completed-later case), 619255 (Cognos fully blank), 615462 (model-only),
-- 4583660 (Cognos-only: 'POS. BUG PLATE 07/20/2026' vs our blank), 618749 (model-only).
-- Caveat: ODS is INSERT-current / UPDATE-stale on some tables — if results look stale, cross-check
-- SSASPROD BIQLTabular_v2 'Lot'[Memo Lot 2] (TbLot, lineage F4108.IOLOT2) via SSMS DAX instead.
