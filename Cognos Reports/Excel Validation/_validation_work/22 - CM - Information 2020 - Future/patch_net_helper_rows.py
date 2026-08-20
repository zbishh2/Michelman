"""The Shipments query defines two helper columns, @NetUSD and @NetEUR, that the Order Net
Amount grid rows reference. Give each its own row underneath the Shipments derived-columns grid
(Notes I:L, rows 133-134 - column C on those rows carries the source-query listing and is not
touched) so the reviewer sees where [@NetUSD] / [@NetEUR] come from. Edit IN PLACE."""
import time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"

ROWS = {
    133: ("@NetUSD", "-",
          "case when ORDER_NET_AMOUNT = 0 and QTY_BACKORDERED > 0 then ordered qty x ORDER_NET_PRICE "
          "else ORDER_NET_AMOUNT end  (one column carries both states)",
          "Sales[AmountOrderNetUSD] + Sales[BackOrderedExtendedAmount] - the cube stores the same value in two "
          "mutually exclusive columns (the back-ordered amount is nonzero only where NetUSD = 0), so the sum "
          "reunites them and cannot double-count; the cube's own net-sales measures roll back-ordered value in "
          "the same way"),
    134: ("@NetEUR", "-",
          "same, x T12 rate to EUR",
          "Sales[AmountOrderNetEUR] + Sales[BackOrderedExtendedAmountEUR] - the EUR pair of the same two columns; "
          "populated only for EUR-local companies (00020) and null for USD-local (00010/00030), which is why "
          "Order Net Amount EUR falls back to Net USD / ToRateA for those"),
}


def retry(fn, tries=60):
    for i in range(tries):
        try: return fn()
        except com_error as e:
            if e.hresult != -2147418111 or i == tries - 1: raise
            time.sleep(0.5)


xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only (stale lock / another Excel holds it)"
    retry(lambda: setattr(xl, "Calculation", -4135))

    ws = retry(lambda: wb.Worksheets("Notes"))
    assert retry(lambda: ws.Cells(129, 9).Value) == "Order Net Amount USD"
    assert retry(lambda: ws.Cells(132, 9).Value) == "Year / Month"
    for r in (133, 134):
        for c in range(9, 13):
            assert retry(lambda: ws.Cells(r, c).Value) is None, (r, c)
    cq133 = retry(lambda: ws.Cells(133, 3).Value)
    assert cq133 and cq133.strip().startswith("&& 'Currency Rates'[CalendarDate]"), cq133

    retry(lambda: ws.Range("I132:L132").Copy())
    retry(lambda: ws.Range("I133:L134").PasteSpecial(Paste=-4122))  # xlPasteFormats
    retry(lambda: setattr(xl, "CutCopyMode", False))
    for r, vals in ROWS.items():
        for c, v in zip(range(9, 13), vals):
            retry(lambda: setattr(ws.Cells(r, c), "Value", v))
    assert retry(lambda: ws.Cells(133, 3).Value) == cq133, "column C disturbed"

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done")
finally:
    xl.Quit()
