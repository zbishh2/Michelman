"""Raw Material Margin USD / EUR are not carried in the report (Dave Bubash: the consumers do not need
them; the definitions go to Dave / Greg / Rohit for cube-measure review, RAW_MATERIAL_MARGIN.md).
Reflect that in the delivered workbook IN PLACE: drop the six margin columns on Comparison - Shipments
(Cognos, Compare, PBI blocks; Excel re-points Zack's summary formulas), and reword the Notes / RS
lines that described the substitute definition."""
import time
import win32com.client as com
from pywintypes import com_error

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
HROW = 13
RMM = ("Raw Material Margin USD", "Raw Material Margin EUR")


def retry(fn, tries=60):
    for i in range(tries):
        try: return fn()
        except com_error as e:
            if e.hresult != -2147418111 or i == tries - 1: raise
            time.sleep(0.5)


def edit(ws, r, c, old, new):
    v = retry(lambda: ws.Cells(r, c).Value)
    assert isinstance(v, str) and old in v, (ws.Name, r, c, old[:50], v)
    retry(lambda: setattr(ws.Cells(r, c), "Value", v.replace(old, new)))


xl = com.DispatchEx("Excel.Application"); xl.Visible = False; xl.DisplayAlerts = False
try:
    wb = retry(lambda: xl.Workbooks.Open(WB))
    assert not wb.ReadOnly, "opened read-only (stale lock / another Excel holds it)"
    retry(lambda: setattr(xl, "Calculation", -4135))

    # --- Comparison - Shipments: delete the six columns, rightmost pair first so addresses stay valid
    cs = retry(lambda: wb.Worksheets("Comparison - Shipments"))
    hdr = [retry(lambda: cs.Cells(HROW, c).Value) for c in range(1, 90)]
    pairs = []
    for i, h in enumerate(hdr):
        if h == RMM[0]:
            assert hdr[i + 1] == RMM[1], (i, hdr[i + 1])
            pairs.append(i + 1)
    assert len(pairs) == 3 and pairs == [17, 45, 73], pairs
    # threshold cells AE3 / AE4 move two columns left once the Cognos pair goes; the row-5 legend names them
    assert retry(lambda: cs.Range("AE3").Value) == 0.01 and retry(lambda: cs.Range("AE4").Value) == 0.02
    legend = retry(lambda: cs.Range("AC5").Value)
    assert "AE4" in legend and "AE3" in legend, legend[-200:]
    retry(lambda: setattr(cs.Range("AC5"), "Value", legend.replace("AE4", "AC4").replace("AE3", "AC3")))
    for c in reversed(pairs):
        rng = cs.Range(cs.Cells(1, c), cs.Cells(1, c + 1)).EntireColumn
        retry(lambda: rng.Delete())
    hdr2 = [retry(lambda: cs.Cells(HROW, c).Value) for c in range(1, 84)]
    assert RMM[0] not in hdr2 and RMM[1] not in hdr2
    assert len([h for h in hdr2 if h]) == 75, len([h for h in hdr2 if h])      # 25 fields x 3 blocks
    assert retry(lambda: cs.Range("AC3").Value) == 0.01 and retry(lambda: cs.Range("AC4").Value) == 0.02
    assert hdr2[0] == "Order Company" and hdr2[26] == "Order Company" and hdr2[52] == "Order Company", (hdr2[26], hdr2[52])

    # --- Notes
    ws = retry(lambda: wb.Worksheets("Notes"))
    edit(ws, 17, 3, "currency and margin basis, UOM", "currency basis, UOM")
    edit(ws, 19, 3, "Raw Material Margin USD: 1010 FALSE - PBI = standard-cost margin (Net USD - AmountExtendedCostUSD); "
                    "Cognos's A1-cost-plus-freight margin has no production source. Definitional, abs 5.4%; flagged to Dave/Rohit.; "
                    "Raw Material Margin EUR: 724 FALSE - Same definition in EUR.; ", "")
    edit(ws, 19, 3, "Shipments (counts at the sheet's 2% threshold): ",
                    "Shipments (counts at the sheet's 2% threshold; Cognos's Raw Material Margin USD / EUR are not carried - Dave - "
                    "so the sheet has 25 fields): ")
    edit(ws, 34, 3, "Open questions (Dave): RMM cost basis, Forecast", "Open questions (Dave): Forecast")
    edit(ws, 58, 4, "[Order Net Amount USD/EUR], [Raw Material Margin USD/EUR] (model measures)", "[Order Net Amount USD/EUR] (model measures)")
    assert retry(lambda: ws.Cells(59, 3).Value) == "Margin"
    retry(lambda: setattr(ws.Cells(59, 4), "Value",
          "not carried (Dave: the consumers do not need it yet); the definitions we tied out go to Dave / Greg / Rohit for a cube measure"))
    edit(ws, 60, 3, "the LB/KG UOM factor, the margin cost basis, and live drift", "the LB/KG UOM factor, and live drift")
    assert retry(lambda: ws.Cells(141, 9).Value) == "Raw Material Margin USD / EUR"
    retry(lambda: setattr(ws.Cells(141, 12), "Value",
          "NOT CARRIED (Dave: the report consumers do not need it yet). The cube has standard cost but no A1 cost and no "
          "freight / warehouse buckets; the standard-cost margin we tied out (Net USD - Sales[AmountExtendedCostUSD]; EUR analog; "
          "+1.2% net, 5.4% abs vs Cognos) is handed to Dave / Greg / Rohit in RAW_MATERIAL_MARGIN.md for a cube-measure review."))
    assert retry(lambda: ws.Cells(182, 3).Value).lstrip().startswith('"Raw Material Margin USD (Line)"')
    assert retry(lambda: ws.Cells(183, 3).Value).lstrip().startswith('"Raw Material Margin EUR (Line)"')
    retry(lambda: ws.Range("182:183").EntireRow.Delete())
    assert retry(lambda: ws.Cells(182, 3).Value).lstrip().startswith('"Revenue Business Unit"')

    # --- RS
    rs = retry(lambda: wb.Worksheets("RS"))
    assert retry(lambda: rs.Cells(40, 1).Value).startswith("Raw Material Margin USD:")
    assert retry(lambda: rs.Cells(41, 1).Value).startswith("Raw Material Margin EUR:")
    retry(lambda: rs.Range("40:41").EntireRow.Delete())
    edit(rs, 44, 1, "UOM factor drift, the margin definition, and live drift", "UOM factor drift, and live drift")

    retry(lambda: setattr(xl, "Calculation", -4105)); retry(lambda: xl.CalculateFullRebuild())
    retry(lambda: ws.Activate()); retry(lambda: ws.Range("A1").Select())
    retry(lambda: wb.Save()); retry(lambda: wb.Close(True))
    print("done")
finally:
    xl.Quit()
