# Orchestrator Handoff — Cognos→PBI Validation & Report-Out (as of 2026-07-07 ~21:45 ET 7/6)

## What happened (2026-07-06 evening)
Validated ALL 10 Cognos rebuild reports against fresh Cognos Excel exports (`Excel Validation\*.xlsx`, exported ~20:41–20:45) using 10 parallel agents querying the open pbix models via powerbi-modeling MCP. Then built the 10 report-out workbooks in the mandated format.

**Verdict: zero unexplained data errors.** Details per report in `_validation_work\<NN>\FINDINGS.md` (read these first — they contain filters, match rates, root causes, as-of dates).

## Deliverables (done)
- `_report_out\*.xlsx` — 10 report-out workbooks, QA-verified, matching `C:\Users\Zack\Downloads\Missing COA Rohit.xlsx` format exactly (Notes / Comparison Cognos|flags|PBI 3-block / RS). Builder: `_validation_work\build_workbook.py`; driver+verify in `_report_out\_tmp\`.
- `_validation_work\<NN>\` — cognos/pbi/comparison/residual CSVs + FINDINGS.md per report.

## Live-model changes I pushed via MCP (partition M updates, from repo files)
| pbix | table | change | saved? |
|---|---|---|---|
| RM Staging at Shell Road 2026 (ODS) | WorkOrder_Detail | added short-list INNER JOIN (was 135 rows vs Cognos 15) | **UNSAVED — user must save** |
| CM Overview LIVE | Inventory_Availability | LTRIM/RTRIM on Plant | **UNSAVED — user must save** |
| Ivan SFC2023 Forecast (report 10) | Sales_History | F4211 UNION ALL F42119 (was 21 rows vs Cognos 907) | **UNSAVED — user must save** |
| Ivan SK 2023 Forecast (report 08) | Sales_History | same union, pushed pre-refresh 7/6 → already refreshed to 895 rows | saved/refreshed ✅ |
Repo `.m` + PBIP TMDL for 08 were also edited (union + header); 01/03/10 repo files already had their fixes — only live models lagged. **Ivan SK 2023 (report 07) was never touched.**

## Round-2 list (user actions, then re-validate)
1. Save the 3 unsaved pbix above → jumpbox refresh: 01 WorkOrder_Detail (expect 15), CM Inventory_Availability (trimmed Plant), 10 Sales_History (expect ~900), **09 Ivan FC 2023 FULL refresh** (7/6 refresh never reached it — data stamps say 2026-07-05 17:04; its match rates are drift-polluted).
2. After refresh: re-validate those 4 (agents' method in FINDINGS.md) and regenerate their 4 workbooks (re-run builder configs).
3. **Pending user decisions:** (a) 08/10 conversion-factor fixes NOT yet applied anywhere — LB→KG `0.453593` → `1/2.2045992` (=0.45359719; evidence in 08 FINDINGS §2) and EA→LB `44` → `44.091984`; apply to both repo .m + TMDL + live partitions on approval. (b) TM Name "Last, First" (ABALPH) vs Cognos "First Last" — 469 rows 08 / 14 rows 10; reformat or accept. (c) Report 01 PBI page-2 "Shortage Details": live Cognos renders ONE page, no page-2 exists — drop it or load Shortage_Detail.m as extra. (d) 530 card: keep correct count (both sides = 12 on 7/6; Cognos's 1,299 is its own fan-out bug). (e) PBI service links for Notes sheets ("Pending publish" placeholders). (f) Forecast pages 08/10: F3460 `/10000` scaling needs a JDE human check — Cognos export blank by design, unvalidatable.

## Gotchas (will bite you)
- **MCP DAX Execute truncates result CSVs at ~100 rows regardless of maxRows.** Paginate (RANKX rank windows or filter by Branch) and verify vs COUNTROWS.
- **A hook blocks subagents writing FINDINGS.md-style files.** Have agents SendMessage findings to main; orchestrator archives to disk (CSV writes are fine).
- Cognos xlsx exports can omit sub-tables that the live render shows (report 01 export had only the top table; bottom table validated from a user screenshot).
- Cognos list panels paginate at 20 rows — screenshots ≠ full data; exports are full.
- Reconnect MCP after pbix reopen (ports change): `connection_operations ListLocalInstances` then Connect.
- Refreshes only run from the jumpbox (ZackB); this machine edits partitions, user saves/syncs/refreshes.

## Key context
- Report IDs (task#): 01=288, 02=323, 03=324, 04=325, 05=326, 06=327, 07=329, 08=330, 09=331, 10=332. Format reference: `C:\Users\Zack\Downloads\Missing COA Rohit.xlsx`.
- Tracker: `Cognos Reports\_PROGRESS.md` (NOT yet updated with 7/6 results — worth doing).
- Memory: `cognos-validation-round-2026-07-06.md` has the durable summary.
