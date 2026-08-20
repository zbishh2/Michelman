"""Zack removed the Amount Received USD / EUR columns from the Compare block on
Comparison - Receipts (the rate-basis FALSE noise is out of the compare by design). Sync the
prose to that IN PLACE: the Receipts residual line and filter-grid note stop describing USD/EUR
FALSE counts, the RS Receipts section carries one 'not compared' line instead of two counts, and
the Receipts tolerance legend drops USD/EUR. Also sharpen the Forecast derived-columns grid's
Revenue Business Unit cell with the characterized rule (omitted; rollup is the open Dave item)."""
import time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"


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


xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only (stale lock / another Excel holds it)"
    retry(lambda: setattr(xl, "Calculation", -4135))

    # --- Comparison - Receipts: tolerance legend no longer covers USD/EUR
    cr = retry(lambda: wb.Worksheets("Comparison - Receipts"))
    edit(cr, 3, 25, "converted/calculated columns (LBs, KGs, USD, EUR)", "converted/calculated columns (LBs, KGs)")

    # --- Notes
    ws = retry(lambda: wb.Worksheets("Notes"))
    edit(ws, 18, 3,
         "; Amount Received USD: 312 FALSE - USD at the JDE transaction rate (SSAS); Cognos applies the monthly rate M. "
         "Amount Received (transaction currency) ties.; Amount Received EUR: 1370 FALSE - EUR at the JDE transaction rate (SSAS); "
         "Cognos applies the monthly rate M. Rate basis only.",
         "; Amount Received USD / EUR: not compared - the rate basis differs by design (SSAS stores the JDE transaction-rate "
         "conversion, Cognos applies the legacy monthly rate M); the transaction-currency Amount Received ties on every matched row.")
    edit(ws, 46, 3, "the USD/EUR amounts are where the FALSEs sit", "the USD/EUR amounts are not compared")
    assert retry(lambda: ws.Cells(199, 9).Value) == "Revenue Business Unit"
    retry(lambda: setattr(ws.Cells(199, 12), "Value",
          "OMITTED - the legacy warehouse stamps RBU on the forecast fact at ETL time. The stamp is the TM-role suffix "
          "(CS 220 / FC 240) on the TM's company rolled to the revenue-booking entity (00021 SARL books under 00020 Belgium, "
          "00035 India under 00030 Asia-Pacific); no production table carries that rollup. Open with Dave."))

    # --- RS: two count lines -> one 'not compared' line
    rs = retry(lambda: wb.Worksheets("RS"))
    assert retry(lambda: rs.Cells(23, 1).Value).startswith("Amount Received USD: 312 FALSE")
    assert retry(lambda: rs.Cells(24, 1).Value).startswith("Amount Received EUR: 1370 FALSE")
    retry(lambda: setattr(rs.Cells(23, 1), "Value",
          "Amount Received USD / EUR: not compared - the rate basis differs by design (SSAS stores the JDE transaction-rate "
          "conversion, Cognos applies the legacy monthly rate M); transaction currency ties."))
    retry(lambda: rs.Range("24:24").EntireRow.Delete())
    assert retry(lambda: rs.Cells(24, 1).Value).startswith("Measures compare at display rounding")

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done")
finally:
    xl.Quit()
