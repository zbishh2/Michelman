"""The PBI side carries no render sentinels: cube blanks stay blank where Cognos shows the legacy
warehouse's '-' / 'Not Available'. Reflect that in the delivered workbook IN PLACE (Zack's formatting
stays): Notes query lines, derived-column blocks, residual lines, 'What was compared'; the PBI blocks on
the Comparison sheets; and a tolerant compare on exactly those columns (Cognos '-' / 'Not Available'
against a PBI blank counts as a match, stated on Notes)."""
import re
import win32com.client as com
import time
from pywintypes import com_error


def retry(fn, tries=40):  # Excel rejects COM calls while it is busy; back off and retry
    for i in range(tries):
        try: return fn()
        except com_error as e:
            if e.hresult != -2147418111 or i == tries - 1: raise
            time.sleep(0.5)

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
PAT = re.compile(r'IF \( TRIM \( (.+?) \) = "", "(?:-|Not Available)", \1 \)')
SENT = ("-", "Not Available")
# sheet -> columns whose PBI cells lose the sentinel and whose compare becomes tolerant
COLS = {
    "Comparison - Receipts": ["Bulk Item"],
    "Comparison - Shipments": ["Description 2", "TM Name"],
    "Comparison - Forecast": ["Item Description 2", "TM Name"],
    "Comparison - Item Details": ["Supplier Name", "Planner Name", "Buyer Name"],
}
BLOCK_L = {  # Notes row -> new 'Our definition' text
    102: "RELATED ( 'Item Branch'[Item Num Bulk] ); blank stays blank (Cognos shows the legacy '-', 8 rows)",
    138: "Sales[Description 2]; blank stays blank (Cognos shows the legacy '-', 2,617 rows)",
    142: "RELATED ( 'Territory Manager'[Mailing Name] ); blank stays blank (Cognos shows the legacy 'Not Available', 419 rows)",
    199: "RELATED ( 'Item Branch'[Description 2] ); blank stays blank (Cognos shows the legacy '-' on every row)",
    200: "RELATED ( 'Territory Manager'[Mailing Name] ); blank stays blank - FactForecast carries a TM for FC-group customers only; the 730 CS-group rows are blank where Cognos shows the sales-history TM (open question to Dave)",
    296: "Item Branch'[Branch Supplier Name] / [Planner Name] / [Buyer Name]; blank stays blank (Cognos shows the legacy 'Not Available': supplier 372 / planner 24 / buyer 321)",
}
COMPARED_NOTE = (" Cognos's '-' and 'Not Available' are legacy-warehouse defaults, not cube values; the Power BI side leaves those cells blank, "
                 "and on exactly those columns (Receipts Bulk Item; Shipments Description 2, TM Name; Forecast Item Description 2, TM Name; "
                 "Item Details Supplier / Planner / Buyer Name) the compare treats Cognos '-' or 'Not Available' against a Power BI blank as a match (matched rows only).")

xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False  # private instance, never the user's open Excel
wb = xl.Workbooks.Open(WB)
assert not wb.ReadOnly, "workbook opened read-only (stale lock / another Excel holds it) - the save would go elsewhere"
xl.Calculation = -4135  # manual while editing
hits = []

ws = wb.Worksheets("Notes")
last = ws.UsedRange.Rows.Count + ws.UsedRange.Row
for r in range(1, last + 1):
    v = ws.Cells(r, 3).Value
    if isinstance(v, str) and "IF ( TRIM (" in v and PAT.search(v):
        ws.Cells(r, 3).Value = PAT.sub(r"\1", v); hits.append(("query line", r))
for r, txt in BLOCK_L.items():
    assert ws.Cells(r, 9).Value, ("block row moved", r, ws.Cells(r, 9).Value)
    ws.Cells(r, 12).Value = txt; hits.append(("block", r, ws.Cells(r, 9).Value))

# residual lines
def edit(r, old, new):
    v = ws.Cells(r, 3).Value
    if old in v: ws.Cells(r, 3).Value = v.replace(old, new); hits.append(("residual", r))
    else: assert new in v or new == "", (r, old)
edit(18, "; Bulk Item: 8 FALSE - Cognos prints '-' for an empty bulk item; PBI leaves it blank", "")
edit(20, "Forecast: TM Name: 730 FALSE - CS-group customers carry no TM on the SSAS forecast row; PBI renders Not Available. FC-group names match.",
         "Forecast: TM Name: 730 FALSE - CS-group customers carry no TM on the SSAS forecast row (PBI blank); Cognos shows the sales-history TM. FC-group names match.")
edit(23, "Same people; 24 Not Available rows match.", "Same people; the 24 rows with no planner are blank on both sides (Cognos 'Not Available').")
v6 = ws.Cells(6, 3).Value
if COMPARED_NOTE.strip() not in v6:
    ws.Cells(6, 3).Value = v6.rstrip() + COMPARED_NOTE; hits.append(("what was compared", 6))

for sh, names in COLS.items():
    cs = retry(lambda: wb.Worksheets(sh))
    hrow = 13
    hdr = [retry(lambda: cs.Cells(hrow, c).Value) for c in range(1, 90)]
    nfields = len([h for h in hdr if h]) // 3
    lastc = retry(lambda: cs.UsedRange.Rows.Count + cs.UsedRange.Row)
    # data extent = last row with a key in col A or the PBI key column
    for name in names:
        cols = [i + 1 for i, h in enumerate(hdr) if h == name]
        assert len(cols) == 3, (sh, name, cols)
        cog, cmp_, pbi = cols
        vals = retry(lambda: cs.Range(cs.Cells(hrow + 1, pbi), cs.Cells(lastc, pbi)).Value)
        rows = [hrow + 1 + i for i, (x,) in enumerate(vals) if x in SENT]
        for r in rows:
            retry(lambda: cs.Cells(r, pbi).ClearContents())
        # tolerant compare on this column only, same extent as the existing formula
        f0 = retry(lambda: cs.Cells(hrow + 1, cmp_).Formula)
        assert f0.startswith("=EXACT(") or f0.startswith("=OR(EXACT("), (sh, name, f0)
        # find last formula row
        lf = hrow + 1
        while retry(lambda: cs.Cells(lf + 1, cmp_).HasFormula): lf += 1
        A = cs.Cells(hrow + 1, cog).GetAddress(False, False); P = cs.Cells(hrow + 1, pbi).GetAddress(False, False)
        K = cs.Cells(hrow + 1, pbi - cog + 1).GetAddress(False, True)  # PBI block's first column (its key): the row must exist on the PBI side
        formula = (f'=OR(EXACT(TRIM({A}&""),TRIM({P}&"")),'
                   f'AND(OR(TRIM({A}&"")="-",TRIM({A}&"")="Not Available"),TRIM({P}&"")="",{K}&""<>""))')
        retry(lambda: setattr(cs.Range(cs.Cells(hrow + 1, cmp_), cs.Cells(lf, cmp_)), 'Formula', formula))
        hits.append((sh, name, "cleared", len(rows), "formula rows", hrow + 1, lf))

xl.Calculation = -4105
xl.CalculateFullRebuild()
ws.Activate(); ws.Range("A1").Select()
wb.Save(); wb.Close(True); xl.Quit()
for h in hits: print(h)
