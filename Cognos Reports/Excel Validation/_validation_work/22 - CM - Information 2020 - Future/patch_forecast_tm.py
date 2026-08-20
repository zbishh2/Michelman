"""Forecast TM Name is now carried: a hidden EDW table 'TM Assignment' (BIQL.TbTM_Max_Assignment,
FC-group TM else CS-group - the commission assignment Cognos stamps) and Forecast[TM Name] =
LOOKUPVALUE on Customer Code; matches Cognos on all 41 forecast customers, no blanks. Reflect that
in the delivered workbook IN PLACE: fill the PBI TM Name column on Comparison - Forecast from the
refreshed model (tm_map.json, customer code -> name), restore the plain EXACT compare on that
column, reword the Notes / RS lines, drop the query's old RELATED TM line and add the TM
Assignment SQL as its own section."""
import json, time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
HROW = 13

TM_SQL = """SET NOCOUNT ON;
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
WHERE rn = 1"""


def retry(fn, tries=60):
    for i in range(tries):
        try: return fn()
        except com_error as e:
            if e.hresult != -2147418111 or i == tries - 1: raise
            time.sleep(0.5)


def edit(ws, r, c, old, new):
    v = retry(lambda: ws.Cells(r, c).Value)
    assert isinstance(v, str) and old in v, (ws.Name, r, c, old[:50], str(v)[:80])
    retry(lambda: setattr(ws.Cells(r, c), "Value", v.replace(old, new)))


tm = {int(k): v for k, v in json.load(open("tm_map.json")).items()}
assert len(tm) == 41

xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only (stale lock / another Excel holds it)"
    retry(lambda: setattr(xl, "Calculation", -4135))

    # --- Comparison - Forecast: fill the PBI TM Name column, plain-EXACT compare
    cf = retry(lambda: wb.Worksheets("Comparison - Forecast"))
    hdr = [retry(lambda: cf.Cells(HROW, c).Value) for c in range(1, 66)]
    assert hdr[31] == "TM Name" and hdr[53] == "TM Name" and hdr[61] == "Customer Code" and hdr[44] == "Company Code", hdr[30:66:11]
    CMP_TM, PBI_TM, PBI_KEY, PBI_CC, CMP_NB = 32, 54, 45, 62, 41   # compare TM, PBI TM, PBI block key, PBI Customer Code, neighbor compare (Customer Name)
    last = HROW
    while retry(lambda: cf.Cells(last + 1, 1).Value) is not None or retry(lambda: cf.Cells(last + 1, PBI_KEY).Value) is not None:
        last += 1
    assert last - HROW == 2304, last - HROW
    filled = 0
    for r in range(HROW + 1, last + 1):
        if retry(lambda: cf.Cells(r, PBI_KEY).Value) is None:
            continue
        cc = int(retry(lambda: cf.Cells(r, PBI_CC).Value))
        retry(lambda: setattr(cf.Cells(r, PBI_TM), "Value", tm[cc])); filled += 1
    assert filled == 2304, filled
    nb = retry(lambda: cf.Cells(HROW + 1, CMP_NB).FormulaR1C1)
    assert nb.startswith("=EXACT(") and "OR(" not in nb, nb
    old_tm = retry(lambda: cf.Cells(HROW + 1, CMP_TM).Formula)
    assert old_tm.startswith("=OR(EXACT("), old_tm
    lf = HROW + 1
    while retry(lambda: cf.Cells(lf + 1, CMP_TM).HasFormula): lf += 1
    retry(lambda: setattr(cf.Range(cf.Cells(HROW + 1, CMP_TM), cf.Cells(lf, CMP_TM)), "FormulaR1C1", nb))

    # --- Notes
    ws = retry(lambda: wb.Worksheets("Notes"))
    edit(ws, 6, 3, "Forecast Item Description 2, TM Name; Item Details", "Forecast Item Description 2; Item Details")
    assert retry(lambda: ws.Cells(20, 3).Value).startswith("Forecast: TM Name: 730 FALSE")
    retry(lambda: setattr(ws.Cells(20, 3), "Value",
          "Forecast: 0 FALSE - TM Name is looked up from EDW BIQL.TbTM_Max_Assignment (the commission assignment Cognos stamps: "
          "FC-group TM else CS-group) via the hidden TM Assignment table, and matches Cognos on every row."))
    edit(ws, 34, 3, "Forecast Revenue Business Unit and TM Name,", "Forecast Revenue Business Unit,")
    assert retry(lambda: ws.Cells(198, 9).Value) == "TM Name"
    retry(lambda: setattr(ws.Cells(198, 12), "Value",
          "LOOKUPVALUE ( 'TM Assignment'[TM Name], 'TM Assignment'[Customer Code], Forecast[Customer Code] ) - hidden EDW table "
          "(BIQL.TbTM_Max_Assignment, FC-group TM else CS-group), the same commission assignment Cognos stamps; matches all 41 customers"))
    assert retry(lambda: ws.Cells(199, 9).Value) == "Revenue Business Unit"
    retry(lambda: setattr(ws.Cells(199, 12), "Value",
          "NOT PRODUCED - no production source carries the TM-to-RBU mapping; open question to Dave"))
    assert retry(lambda: ws.Cells(217, 3).Value).lstrip().startswith('"TM Name", RELATED')
    retry(lambda: ws.Range("217:217").EntireRow.Delete())
    assert retry(lambda: ws.Cells(217, 3).Value).lstrip().startswith('"Current Forecast (Line)"')
    # TM Assignment query section after the Forecast query (which now ends at 228, blank 229, WO header 230)
    assert retry(lambda: ws.Cells(228, 3).Value).strip() == ")" and retry(lambda: ws.Cells(230, 3).Value).startswith("4. Work Orders")
    lines = ["3b. TM Assignment - EDWPROD / EDW (hidden lookup table; Forecast[TM Name] = LOOKUPVALUE on Customer Code)"] + TM_SQL.splitlines() + [""]
    retry(lambda: ws.Range("230:%d" % (229 + len(lines))).EntireRow.Insert())
    for i, ln in enumerate(lines):
        if ln: retry(lambda: setattr(ws.Cells(230 + i, 3), "Value", ln))
    assert retry(lambda: ws.Cells(230 + len(lines), 3).Value).startswith("4. Work Orders")

    # --- RS
    rs = retry(lambda: wb.Worksheets("RS"))
    assert retry(lambda: rs.Cells(80, 1).Value).startswith("TM Name: 730 FALSE")
    retry(lambda: setattr(rs.Cells(80, 1), "Value",
          "(none) - TM Name is looked up from EDW BIQL.TbTM_Max_Assignment (FC-group TM else CS-group) and matches on every matched row."))

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done; filled", filled)
finally:
    xl.Quit()
