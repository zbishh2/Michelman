# Updates the report-out workbook for the Shipments net-amount definition:
# Order Net Amount USD/EUR are the base columns of the cube's [Order Net Amt SPD USD]/[EUR]
# measures (Sales[AmountOrderNetUSD]/[AmountOrderNetEUR]).
#   - PBI block: the 2 back-ordered lines -> USD 0 (EUR-company line also EUR 0);
#     EUR blank on USD-local companies (00010/00030).
#   - Notes: Shipments query listing rewritten (39 lines), derived-columns grid rows for
#     Order Net USD/EUR retexted, @NetUSD/@NetEUR/@RateDate/@EurToUsd rows cleared,
#     results line for Shipments retexted.
#   - RS: "Compare columns with FALSE on matched rows" block inserted for Shipments.
# Edits in place via Excel COM. Aborts if the workbook is open elsewhere (ReadOnly).
import shutil, sys, time
import pythoncom
from pywintypes import com_error
import win32com.client

WB = r"C:\Users\Zack\Documents\Code\Michelman\Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx"
BK = r"C:\Users\Zack\AppData\Local\Temp\claude\C--Users-Zack-Documents-Code-Michelman\b908b0b3-8fa2-4038-bdc1-8782cac9df0c\scratchpad\22 - CM - Information 2020 - Future.pre-spd.xlsx"

shutil.copy2(WB, BK)
print("backup ->", BK)

QUERY = [
    'EVALUATE',
    None,  # row 127: VAR Bulks - kept as-is
    'VAR Lines =',
    '    FILTER (',
    '        Sales,',
    "        TRIM ( RELATED ( 'Item Branch'[Item Bulk] ) ) IN Bulks",
    '            && Sales[Promised Shipment Date] >= DATE ( 2020, 1, 1 )',
    '            && Sales[Cancelled_Flag] = 0',
    '            && NOT Sales[Order Type] IN { "SB", "SR" }',
    '    )',
    'RETURN',
    '    SELECTCOLUMNS (',
    '        Lines,',
    '        "Order Company", Sales[Order Company],',
    '        "Branch Plant", TRIM ( Sales[BusinessUnit] ),',
    '        "Order Number", Sales[Order Num],',
    '        "Line Number", Sales[Line Num],',
    '        "Open Indicator", Sales[Open Order Flag],',
    '        "Global Bulk Item", RELATED ( \'Item Branch\'[Item Global Bulk] ),',
    '        "Bulk Item", RELATED ( \'Item Branch\'[Item Bulk] ),',
    '        "2nd Item Number", Sales[Item Num 2nd],',
    '        "Description 1", Sales[Description 1],',
    '        "Description 2", Sales[Description 2],',
    '        "Freight Handling Code", Sales[Freight Handling Code],',
    '        "Next Status", Sales[Status Code Next],',
    '        "Order Net Amount USD (Line)", Sales[AmountOrderNetUSD],',
    '        "Order Net Amount EUR (Line)", Sales[AmountOrderNetEUR],',
    '        "Ordered Quantity LBs (Line)", Sales[QuantityOrderedLB],',
    '        "Ordered Quantity KGs (Line)", Sales[QuantityOrderedKG],',
    '        "Revenue Business Unit", RELATED ( \'Revenue Business Unit\'[RBU] ),',
    '        "TM Name", RELATED ( \'Territory Manager\'[Mailing Name] ),',
    '        "Customer Name", RELATED ( \'Customer Ship To\'[Customer Ship To Name] ),',
    '        "Country Name", RELATED ( \'Customer Ship To\'[Country Desc] ),',
    '        "Global Parent Name", RELATED ( Customer[Global Parent Name] ),',
    '        "Date", Sales[Promised Shipment Date],',
    '        "Year", YEAR ( Sales[Promised Shipment Date] ),',
    '        "Month", MONTH ( Sales[Promised Shipment Date] ),',
    '        "Chemist Name", RELATED ( \'Item Branch\'[Chemist Name] )',
    '    )',
]  # rows 126..164; rows 165..181 cleared below

GRID = {
    "J129": "measure [Order Net Amt SPD USD]",
    "L129": ("Sales[AmountOrderNetUSD] - the measure's base column, so the report shows the same "
             "numbers as every cube-based report. Back-ordered lines carry 0 here (the cube holds "
             "that value separately in BackOrderedExtendedAmount, outside the measure); 2 lines."),
    "J130": "measure [Order Net Amt SPD EUR]",
    "L130": ("Sales[AmountOrderNetEUR] - the measure's base column. Blank for USD-local companies "
             "(00010/00030): the cube rates only EUR-local companies into EUR, so those rows are "
             "not comparable to Cognos's every-line converted EUR."),
}

NOTES_ROW9 = ("Shipments: 2864 of 2864, no one-sided rows. Every attribute ties on all lines. "
              "Order Net Amount USD/EUR carry the cube measures' numbers - the base columns of "
              "[Order Net Amt SPD USD] / [Order Net Amt SPD EUR] - so they differ from Cognos by "
              "rate basis (JDE order-time vs Cognos monthly M), 2 back-ordered lines the cube "
              "holds at 0, and EUR blank on USD-local companies (00010/00030).")

RS_BLOCK = [
    "Compare columns with FALSE on matched rows:",
    ("Order Net Amount USD: by design - the report carries the cube measure "
     "[Order Net Amt SPD USD]'s base column (Sales[AmountOrderNetUSD]) so numbers match the other "
     "cube reports. FALSEs are the rate basis (JDE order-time vs Cognos monthly M) and 2 "
     "back-ordered lines where the cube holds 0 and Cognos re-prices (26001448 line 1, "
     "2645790 line 1)."),
    ("Order Net Amount EUR: by design - the cube's Sales[AmountOrderNetEUR] is blank for "
     "USD-local companies (00010/00030); Cognos converts every line, so those rows are not "
     "comparable. EUR-local companies (00020/00034) carry the cube's native EUR."),
]

USD_LOCAL = {"00010", "00030"}
BO = {("00020", "26001448", 1.0): "EUR", ("00010", "2645790", 1.0): "USD"}

pythoncom.CoInitialize()
xl = win32com.client.DispatchEx("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
try:
    wb = xl.Workbooks.Open(WB)
    assert not wb.ReadOnly, "workbook is open elsewhere (ReadOnly) - aborting, nothing written"
    calc = xl.Calculation
    xl.Calculation = -4135  # manual

    ws = wb.Worksheets("Comparison - Shipments")
    ba = ws.Range("BA14:BA2877").Value
    bc = ws.Range("BC14:BC2877").Value
    bd = ws.Range("BD14:BD2877").Value
    bm = [list(r) for r in ws.Range("BM14:BM2877").Value]
    bn = [list(r) for r in ws.Range("BN14:BN2877").Value]
    n_bo = n_blank = 0
    for i in range(len(ba)):
        comp = str(ba[i][0]) if ba[i][0] is not None else ""
        key = (comp, str(bc[i][0]), float(bd[i][0]) if bd[i][0] is not None else None)
        if key in BO:
            bm[i][0] = 0
            bn[i][0] = 0 if BO[key] == "EUR" else None
            n_bo += 1
        if comp in USD_LOCAL:
            bn[i][0] = None
            n_blank += 1
    assert n_bo == 2, f"expected 2 BO rows, found {n_bo}"
    ws.Range("BM14:BM2877").Value = [tuple(r) for r in bm]
    ws.Range("BN14:BN2877").Value = [tuple(r) for r in bn]
    print(f"Shipments PBI block: {n_bo} BO rows zeroed, {n_blank} USD-local EUR cells blanked")

    nt = wb.Worksheets("Notes")
    for off, txt in enumerate(QUERY):
        if txt is not None:
            nt.Range(f"C{126 + off}").Value = txt
    nt.Range(f"C{126 + len(QUERY)}:C181").ClearContents()
    for addr, txt in GRID.items():
        nt.Range(addr).Value = txt
    nt.Range("I133:L136").Clear()
    nt.Range("C9").Value = NOTES_ROW9
    print("Notes: query listing rewritten (rows 126-164), grid retexted, helper rows cleared, results line updated")

    rs = wb.Worksheets("RS")
    rs.Rows("26:28").Insert()
    for off, txt in enumerate(RS_BLOCK):
        rs.Range(f"A{26 + off}").Value = txt
    print("RS: FALSE-columns block inserted at rows 26-28")

    xl.Calculation = -4105  # automatic
    xl.CalculateFullRebuild()
    for attempt in range(5):
        try:
            wb.Save()
            break
        except com_error as e:
            if e.hresult == -2147418111 and attempt < 4:
                time.sleep(2)
                continue
            raise
    print("saved")
finally:
    try:
        wb.Close(SaveChanges=False)
    except Exception:
        pass
    xl.Quit()
    pythoncom.CoUninitialize()
