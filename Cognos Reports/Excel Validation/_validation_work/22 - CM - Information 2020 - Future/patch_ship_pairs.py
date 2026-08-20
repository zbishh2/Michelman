"""Comparison - Shipments: re-pair the twin rows of re-invoiced order-lines IN PLACE. The delivered sheet
paired twins first-come (crosswise where the twins did not match on every column); the corrected pairing
(ship_swaps.json: Cognos row index -> (old PBI index, new PBI index)) is a permutation of PBI blocks among
those rows, so the PBI block values are read once and written back permuted. Formulas are untouched."""
import json, time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
HROW = 13           # header row on the Comparison sheets (Zack inserted rows above)
NF = 27             # Shipments fields
PBI_C1 = 2 * NF + 3 # PBI block first column (Cognos 1..27, spacer, compare 29..55, spacer, PBI 57..83)

def retry(fn, tries=60):
    for i in range(tries):
        try: return fn()
        except com_error as e:
            if e.hresult != -2147418111 or i == tries - 1: raise
            time.sleep(0.5)

swaps = {int(k): tuple(v) for k, v in json.load(open("ship_swaps.json")).items()}
xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only"
    retry(lambda: setattr(xl, "Calculation", -4135))
    cs = retry(lambda: wb.Worksheets("Comparison - Shipments"))
    assert retry(lambda: cs.Cells(HROW, 1).Value) == "Order Company" and retry(lambda: cs.Cells(HROW, PBI_C1).Value) == "Order Company", "layout"
    # the sheet's PBI block at row 14+i currently holds pbi[old]; read every affected row's block, keyed by old index
    blocks = {}
    for i, (old, new) in swaps.items():
        r = HROW + 1 + i
        # sanity: the Cognos key on this sheet row is the twin we expect
        blocks[old] = retry(lambda: cs.Range(cs.Cells(r, PBI_C1), cs.Cells(r, PBI_C1 + NF - 1)).Value)
    for i, (old, new) in swaps.items():
        r = HROW + 1 + i
        vals = blocks[new]
        retry(lambda: setattr(cs.Range(cs.Cells(r, PBI_C1), cs.Cells(r, PBI_C1 + NF - 1)), "Value", vals))
    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    ws = retry(lambda: wb.Worksheets("Notes")); retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("swapped PBI blocks on", len(swaps), "rows")
finally:
    xl.Quit()
