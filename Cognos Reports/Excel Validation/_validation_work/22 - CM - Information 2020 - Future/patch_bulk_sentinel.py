"""Receipts Bulk Item no longer carries the "-" sentinel: reflect it in the delivered workbook in
place (Notes query text, derived-column block, residual line; the PBI block on Comparison - Receipts)."""
import win32com.client as com

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
OLD_LINE = '        "Bulk Item", IF ( TRIM ( RELATED ( \'Item Branch\'[Item Num Bulk] ) ) = "", "-", RELATED ( \'Item Branch\'[Item Num Bulk] ) ),'
NEW_LINE = '        "Bulk Item", RELATED ( \'Item Branch\'[Item Num Bulk] ),'

xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False  # DispatchEx: a private instance, never the user's open Excel
wb = xl.Workbooks.Open(WB)
xl.Calculation = -4135  # manual while editing

ws = wb.Worksheets("Notes")
last = ws.UsedRange.Rows.Count + ws.UsedRange.Row
hits = []
for r in range(1, last + 1):
    v = ws.Cells(r, 3).Value
    if v == OLD_LINE:
        ws.Cells(r, 3).Value = NEW_LINE; hits.append(("query line", r))
    if isinstance(v, str) and v.startswith("Receipts: ") and "FALSE - " in v:
        ws.Cells(r, 3).Value = v + "; Bulk Item: 8 FALSE - Cognos prints '-' for an empty bulk item; PBI leaves it blank"
        hits.append(("residual", r))
    w = ws.Cells(r, 9).Value
    if w == "Bulk Item" and r < 120:
        ws.Cells(r, 10).Value = "(not on his page - Receipts joined to ItemBranch on ItemBranchSKey)"
        ws.Cells(r, 12).Value = "RELATED ( 'Item Branch'[Item Num Bulk] ); blank stays blank (Cognos prints '-', 8 rows)"
        hits.append(("block row", r))

cs = wb.Worksheets("Comparison - Receipts")
hrow = next(r for r in range(1, 40) if cs.Cells(r, 2).Value == "Bulk Item")
hdr = [cs.Cells(hrow, c).Value for c in range(1, 60)]
cols = [i + 1 for i, h in enumerate(hdr) if h == "Bulk Item"]
assert len(cols) == 3, cols
pbi_col = cols[2]
lastc = cs.UsedRange.Rows.Count + cs.UsedRange.Row
vals = cs.Range(cs.Cells(hrow + 1, pbi_col), cs.Cells(lastc, pbi_col)).Value
rows = [hrow + 1 + i for i, (v,) in enumerate(vals) if v == "-"]
for r in rows:
    cs.Cells(r, pbi_col).ClearContents()
n = len(rows)
hits.append(("pbi cells cleared", n, "col", pbi_col))
xl.Calculation = -4105  # automatic
xl.CalculateFullRebuild()
ws.Activate(); ws.Range("A1").Select()
wb.Save(); wb.Close(True); xl.Quit()
print(hits)
