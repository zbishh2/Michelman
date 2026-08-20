"""@RateDate and @EurToUsd complete the helper-column story under the Shipments derived-columns
grid: @RateDate carries the GL-else-order-date rule the rate month is read from, @EurToUsd is the
single-row Rate A lookup, layered in a second ADDCOLUMNS because a column expression cannot read
a sibling added in the same call. Rows 135-136, columns I:L only (column C holds the query
listing). Edit IN PLACE."""
import time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"

ROWS = {
    135: ("@RateDate", "-",
          "T5/T12 rate read at type M for the GL date month; ordered date when unposted",
          "IF ( Sales[GL Date] <= DATE ( 1900, 12, 31 ), Sales[Order Date], Sales[GL Date] ) - the date the "
          "rate month is read from; JDE stamps a 1900 sentinel on unposted lines, so those fall back to Order "
          "Date, the same GL-else-ordered rule Cognos applies"),
    136: ("@EurToUsd", "-",
          "T12 rate to EUR  (monthly, from FIN_CURRENCY_CONVERSION)",
          "MAXX ( FILTER ( EurUsdMonthEnd, CalendarDate = EOMONTH ( [@RateDate], 0 ) ), ToRateA ) - the EUR->USD "
          "Rate A row at the month end of @RateDate; Currency Rates holds exactly one EUR->USD row per month end, "
          "so the FILTER resolves a single row and MAXX just reads it. Sits in a second ADDCOLUMNS (VAR Rated) "
          "because a column expression cannot read a sibling column added in the same call - @RateDate must "
          "already exist on the row"),
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
    assert retry(lambda: ws.Cells(133, 9).Value) == "@NetUSD"
    assert retry(lambda: ws.Cells(134, 9).Value) == "@NetEUR"
    for r in (135, 136):
        for c in range(9, 13):
            assert retry(lambda: ws.Cells(r, c).Value) is None, (r, c)
    c135 = retry(lambda: ws.Cells(135, 3).Value)
    assert c135 and c135.strip() == "VAR Lines =", c135

    retry(lambda: ws.Range("I134:L134").Copy())
    retry(lambda: ws.Range("I135:L136").PasteSpecial(Paste=-4122))  # xlPasteFormats
    retry(lambda: setattr(xl, "CutCopyMode", False))
    for r, vals in ROWS.items():
        for c, v in zip(range(9, 13), vals):
            retry(lambda: setattr(ws.Cells(r, c), "Value", v))
    assert retry(lambda: ws.Cells(135, 3).Value) == c135, "column C disturbed"

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done")
finally:
    xl.Quit()
