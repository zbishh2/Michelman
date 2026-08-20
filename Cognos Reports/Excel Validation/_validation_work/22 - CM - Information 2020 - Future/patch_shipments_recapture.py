# Rebuilds the Comparison - Shipments tab of a fresh copy of the report-out workbook
# from a same-instant capture pair: the Cognos export (Downloads) and the paginated-
# report Excel export (report folder). Cognos block A14:Y*, PBI block BA14:BY*, PBI
# rows key-aligned to the Cognos rows on (Order Company, Order Number, Line Number)
# by occurrence. Only this tab is touched; the original workbook is not opened.
import datetime
import os
import shutil
import sys
import time

import openpyxl
import pythoncom
import win32com.client
from pywintypes import com_error

ROOT = r"C:\Users\Zack\Documents\Code\Michelman"
SRC_WB = os.path.join(ROOT, r"Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future.xlsx")
NEW_WB = os.path.join(ROOT, r"Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future - Updated.xlsx")
COGNOS = r"C:\Users\Zack\Downloads\CM - Information 2020-Future (1).xlsx"
PBI = os.path.join(ROOT, r"Cognos Reports\22 - CM - Information 2020 - Future\CM - Information 2020 - Future.xlsx")

LOCK = os.path.join(os.path.dirname(SRC_WB), "~$22 - CM - Information 2020 - Future.xlsx")
if os.path.exists(LOCK):
    sys.exit("ABORT: source workbook is open in Excel (lock file present)")

# ---- load the two captures ---------------------------------------------------
def parse_num(x):
    if x is None or str(x).strip() == "":
        return None
    return float(str(x).replace(",", ""))

def parse_date(x):
    if x is None or str(x).strip() == "":
        return None
    return datetime.datetime.strptime(str(x).strip(), "%Y-%m-%d %H:%M:%S")

def parse_int(x):
    if x is None or str(x).strip() == "":
        return None
    return int(float(x))

def parse_text(x):
    if x is None:
        return None
    s = str(x)
    return s if s != "" else None

# 25 workbook columns; converters per side (Line Number is text on the Cognos side,
# numeric on the PBI side, matching the blocks as built).
CONV_COGNOS = [parse_text] * 12 + [parse_num] * 4 + [parse_text] * 5 + [parse_date, parse_int, parse_int, parse_text]
CONV_PBI = list(CONV_COGNOS)
CONV_PBI[3] = parse_num

def load_rows(path, sheet, first_data_row, keep_cols, conv):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb[sheet]
    ws.reset_dimensions()
    out = []
    for i, raw in enumerate(ws.iter_rows(values_only=True), start=1):
        if i < first_data_row:
            continue
        raw = list(raw) + [None] * (max(keep_cols) + 1 - len(raw))
        if all(raw[c] is None or str(raw[c]) == "" for c in keep_cols):
            continue
        out.append([conv[j](raw[c]) for j, c in enumerate(keep_cols)])
    wb.close()
    return out

# Cognos export: 27 cols, drop the two Raw Material Margin cols (0-based 16, 17).
cognos = load_rows(COGNOS, "Shipments_2", 2, [c for c in range(27) if c not in (16, 17)], CONV_COGNOS)
# PBI export: 28 cols with empty spacers at 0-based 12, 16, 23.
pbi = load_rows(PBI, "Shipments", 8, [c for c in range(28) if c not in (12, 16, 23)], CONV_PBI)
print(f"cognos rows: {len(cognos)}  pbi rows: {len(pbi)}")

def key(row):
    return (str(row[0]).strip(), str(row[2]).strip(), float(row[3]))

pbi_by_key = {}
for r in pbi:
    pbi_by_key.setdefault(key(r), []).append(r)

aligned, unmatched_cognos = [], 0
for r in cognos:
    bucket = pbi_by_key.get(key(r))
    if bucket:
        aligned.append(bucket.pop(0))
    else:
        aligned.append([None] * 25)
        unmatched_cognos += 1
pbi_leftover = sum(len(v) for v in pbi_by_key.values())
print(f"cognos-only rows: {unmatched_cognos}  pbi-only rows (not shown): {pbi_leftover}")
if pbi_leftover:
    for k, v in pbi_by_key.items():
        if v:
            print("  pbi-only:", k)

n = len(cognos)
FIRST = 14
LAST = FIRST + n - 1  # 2878 for 2,865 rows
OLD_LAST = 2877

def to_com(rows):
    out = []
    for r in rows:
        line = []
        for v in r:
            if isinstance(v, str) and (v.startswith("=") or _is_numlike(v)):
                v = "'" + v
            line.append(v)
        out.append(tuple(line))
    return tuple(out)

def _is_numlike(s):
    try:
        float(s)
        return True
    except ValueError:
        return False

# ---- edit the copy via Excel COM --------------------------------------------
shutil.copy2(SRC_WB, NEW_WB)
pythoncom.CoInitialize()
xl = win32com.client.DispatchEx("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
try:
    wb = xl.Workbooks.Open(NEW_WB)
    assert not wb.ReadOnly, "opened read-only"
    xl.Calculation = -4135  # manual
    ws = wb.Worksheets("Comparison - Shipments")

    grow = LAST - OLD_LAST
    for _ in range(grow):
        # inserting inside the data band auto-extends the $14:$2877 ranges in
        # row 12 and the AM8:AP11 array formulas
        ws.Rows(OLD_LAST).Insert()
    if grow:
        ws.Range(f"AA{OLD_LAST - 1}:AY{LAST}").FillDown()

    ws.Range(f"A{FIRST}:Y{LAST}").Value = to_com(cognos)
    ws.Range(f"BA{FIRST}:BY{LAST}").Value = to_com(aligned)
    ws.Range("A2").Value = "As of 8/20/2026"

    xl.Calculation = -4105  # automatic
    xl.CalculateFullRebuild()

    counts = ws.Range(f"AA12:AY12").Value[0]
    hdrs = ws.Range(f"AA13:AY13").Value[0]
    print("FALSE counts:", {h: int(c) for h, c in zip(hdrs, counts) if c})
    print("summary:", ws.Range("AA6").Value)
    for addr, label in [("AM8", "USD net"), ("AN8", "EUR net"), ("AO8", "LBs net"), ("AP8", "KGs net"),
                        ("AM10", "USD net %"), ("AN10", "EUR net %")]:
        print(label, "=", ws.Range(addr).Value)
    print("Cognos USD sum:", xl.WorksheetFunction.Sum(ws.Range(f"M{FIRST}:M{LAST}")))
    print("PBI USD sum:", xl.WorksheetFunction.Sum(ws.Range(f"BM{FIRST}:BM{LAST}")))
    print("Cognos EUR sum:", xl.WorksheetFunction.Sum(ws.Range(f"N{FIRST}:N{LAST}")))
    print("PBI EUR sum:", xl.WorksheetFunction.Sum(ws.Range(f"BN{FIRST}:BN{LAST}")))

    for attempt in range(5):
        try:
            wb.Save()
            break
        except com_error:
            time.sleep(2)
    wb.Close(SaveChanges=False)
finally:
    xl.Quit()
    pythoncom.CoUninitialize()
print("saved:", NEW_WB)
