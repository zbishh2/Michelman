"""Validation-pass sync: the compare formulas are the truth, the prose follows them.
Receipts KGs counts 25 FALSE on matched rows (the 77 sub-kilogram factor rows fall inside the
sheet's 0.005 relative tolerance; 17 tote + 8 Granite remain). The RS Shipments block carries
counts from an earlier capture; the sheet counts (and Notes row 19) read 396/11/128/29, Date 4,
no Customer Name / Month FALSEs. Edit IN PLACE."""
import time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"

KG_OLD = ("Received Quantity KGs: 102 FALSE - 77 rows sub-kilogram (SSAS KG factor 0.4536 vs Cognos 0.453597189); "
          "17 rows are the vendor 328211 tote-factor rows;")
KG_NEW = ("Received Quantity KGs: 25 FALSE - 17 vendor 328211 tote-factor rows;")


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


def put(ws, r, c, startswith, new):
    v = retry(lambda: ws.Cells(r, c).Value)
    assert isinstance(v, str) and v.startswith(startswith), (ws.Name, r, c, startswith, str(v)[:80])
    retry(lambda: setattr(ws.Cells(r, c), "Value", new))


xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only (stale lock / another Excel holds it)"
    retry(lambda: setattr(xl, "Calculation", -4135))

    # --- Notes row 18: KGs clause
    ws = retry(lambda: wb.Worksheets("Notes"))
    edit(ws, 18, 3, KG_OLD, KG_NEW)
    edit(ws, 18, 3, "where Cognos computes LB x 0.4536.;",
         "where Cognos computes LB x 0.4536. The 77 sub-kilogram rows (SSAS KG factor 0.4536 vs Cognos 0.453597189) "
         "fall inside the sheet's 0.005 relative tolerance.;")

    # --- RS: Receipts KGs line, then the Shipments block
    rs = retry(lambda: wb.Worksheets("RS"))
    put(rs, 22, 1, "Received Quantity KGs: 102 FALSE",
        "Received Quantity KGs: 25 FALSE - 17 vendor 328211 tote-factor rows; 8 Granite lines (docs 234573/234574) carry "
        "QuantityReceivedKG equal to the LB quantity in SSAS, where Cognos computes LB x 0.4536. The 77 sub-kilogram factor "
        "rows (0.4536 vs 0.453597189) fall inside the sheet's 0.005 relative tolerance.")
    put(rs, 35, 1, "Order Net Amount USD: 920 FALSE",
        "Order Net Amount USD: 396 FALSE at the sheet's tolerance - EUR-company (00020) lines: SSAS carries USD at JDE's "
        "order-time exchange rate, Cognos converts the local amount at its monthly rate M; net +0.25%, abs 0.80%.")
    put(rs, 36, 1, "Order Net Amount EUR: 1423 FALSE",
        "Order Net Amount EUR: 11 FALSE - USD-company lines converted at the month-end EUR rate of the GL month; abs 0.06%.")
    put(rs, 37, 1, "Ordered Quantity LBs: 203 FALSE",
        "Ordered Quantity LBs: 128 FALSE - Item-UOM conversion drift (MW40504-C2 / MW40514-C2 legacy x0.4169; 191245PX-T2 "
        "tote 2300 vs 2400); SSAS carries the current factor. Net +0.20%.")
    put(rs, 38, 1, "Ordered Quantity KGs: 115 FALSE",
        "Ordered Quantity KGs: 29 FALSE - Same conversion-drift rows.")
    assert retry(lambda: rs.Cells(39, 1).Value).startswith("Customer Name: 2 FALSE")
    retry(lambda: rs.Range("39:39").EntireRow.Delete())
    # rows shift up by 1: GP now 39, Date 40, Month 41
    assert retry(lambda: rs.Cells(39, 1).Value).startswith("Global Parent Name: 12 FALSE")
    put(rs, 40, 1, "Date: 32 FALSE",
        "Date: 4 FALSE - Open lines whose date advanced between the Cognos capture and the PBI refresh (live drift).")
    assert retry(lambda: rs.Cells(41, 1).Value).startswith("Month: 16 FALSE")
    retry(lambda: rs.Range("41:41").EntireRow.Delete())
    assert retry(lambda: rs.Cells(41, 1).Value).startswith("Every attribute and the transaction-currency amount tie")

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done")
finally:
    xl.Quit()
