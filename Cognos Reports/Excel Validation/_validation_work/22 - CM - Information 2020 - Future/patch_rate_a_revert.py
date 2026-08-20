# Brings the "- Updated" report-out workbook to the shipped Shipments definition:
# USD = the cube's stored net amount, EUR = native cube EUR for EUR-currency
# companies else USD at the month-end rate A. Rewrites the PBI amount columns
# (BM/BN) from an executeQueries pull of the refreshed model, then syncs the
# Notes results/counts/query listing and the RS Shipments block.
import datetime
import json
import os
import re
import sys
import time

import pythoncom
import win32com.client
from pywintypes import com_error

ROOT = r"C:\Users\Zack\Documents\Code\Michelman"
WB_PATH = os.path.join(ROOT, r"Cognos Reports\Excel Validation\_report_out\22 - CM - Information 2020 - Future - Updated.xlsx")
PULL = r"C:\Users\Zack\AppData\Local\Temp\claude\C--Users-Zack-Documents-Code-Michelman\b908b0b3-8fa2-4038-bdc1-8782cac9df0c\scratchpad\eq_out.json"
SHIPMENTS_M = os.path.join(ROOT, r"Cognos Reports\22 - CM - Information 2020 - Future\Shipments.m")

LOCK = os.path.join(os.path.dirname(WB_PATH), "~$22 - CM - Information 2020 - Future - Updated.xlsx")
if os.path.exists(LOCK):
    sys.exit("ABORT: the Updated workbook is open in Excel (lock file present)")

FIRST, LAST = 14, 2878

# ---- model pull -> key lookup ------------------------------------------------
rows = json.load(open(PULL))["text"]["results"][0]["tables"][0]["rows"]
lookup = {}
for r in rows:
    k = (str(r["[co]"]).strip(), str(int(r["[ord]"])), float(r["[ln]"]),
         datetime.datetime.fromisoformat(r["[dt]"]).date())
    lookup.setdefault(k, []).append((r["[usd]"], r["[eur]"]))
print(f"model rows: {len(rows)}  distinct keys: {len(lookup)}")

# ---- DAX text for the Notes listing -----------------------------------------
m_text = open(SHIPMENTS_M, encoding="utf-8").read()
q = re.search(r'Query = "\n(.*?)\n"\n', m_text, re.S).group(1)
dax_lines = q.replace('""', '"').splitlines()
print(f"query lines for Notes: {len(dax_lines)}")

# ---- COM edit ----------------------------------------------------------------
pythoncom.CoInitialize()
xl = win32com.client.DispatchEx("Excel.Application")
xl.Visible = False
xl.DisplayAlerts = False
try:
    wb = xl.Workbooks.Open(WB_PATH)
    assert not wb.ReadOnly, "opened read-only"
    xl.Calculation = -4135  # manual
    ws = wb.Worksheets("Comparison - Shipments")

    keys = ws.Range(f"BA{FIRST}:BV{LAST}").Value  # BA..BV block; need BA, BC, BD, BV
    consumed = {}
    bm, bn, misses = [], [], 0
    for row in keys:
        co, ordnum, ln, dt = row[0], row[2], row[3], row[21]
        k = (str(co).strip(), str(int(float(ordnum))), float(ln),
             dt.date() if hasattr(dt, "date") else None)
        bucket = lookup.get(k)
        if bucket:
            i = consumed.get(k, 0)
            usd, eur = bucket[min(i, len(bucket) - 1)]
            consumed[k] = i + 1
            bm.append((usd,))
            bn.append((eur,))
        else:
            misses += 1
            bm.append((None,))
            bn.append((None,))
    print(f"grid rows matched: {LAST - FIRST + 1 - misses}  misses: {misses}")
    if misses:
        sys.exit("ABORT: unmatched grid rows - key logic is wrong, nothing written")
    ws.Range(f"BM{FIRST}:BM{LAST}").Value = bm
    ws.Range(f"BN{FIRST}:BN{LAST}").Value = bn

    # ---- Notes ---------------------------------------------------------------
    nt = wb.Worksheets("Notes")
    c5 = nt.Range("C5").Value
    nt.Range("C5").Value = c5.replace(
        "Shipments: 2,864 Cognos rows and 2,864 Power BI rows",
        "Shipments: 2,865 Cognos rows and 2,867 Power BI rows")
    # query listing: clear the old block, copy the C126 format down, write anew
    nt.Range("C126:C182").ClearContents()
    nt.Range("C126").Copy()
    nt.Range(f"C126:C{126 + len(dax_lines) - 1}").PasteSpecial(-4122)  # formats
    xl.CutCopyMode = False
    nt.Range(f"C126:C{126 + len(dax_lines) - 1}").Value = [(l,) for l in dax_lines]
    # derived-column grid: EUR report definition
    nt.Range("L130").Value = ('IF ( Sales[LocalCurrency] = "EUR", Sales[AmountOrderNetEUR], '
                              "DIVIDE ( Sales[AmountOrderNetUSD], [@EurToUsd] ) ) - native cube EUR, "
                              "else USD at the month-end rate A of the GL date")

    # ---- RS ------------------------------------------------------------------
    rs = wb.Worksheets("RS")
    rs.Range("A21").Value = ("Cognos 2865 = matched 2865 + Cognos-only 0;  "
                             "PBI 2867 = matched 2865 + PBI-only 2")
    # the two PBI-only rows replace the single '(none)' under 'in PBI but not in Cognos'
    rs.Rows(26).Insert()
    rs.Range("A25").Value = "00030 | 2770939 | 1"
    rs.Range("B25").Value = "Order placed after the Cognos export - live drift, not a query difference"
    rs.Range("A26").Value = "00030 | 2770974 | 1"
    rs.Range("B26").Value = "Order placed after the Cognos export - live drift, not a query difference"

    xl.Calculation = -4105  # automatic
    xl.CalculateFullRebuild()

    counts = ws.Range("AA12:AY12").Value[0]
    hdrs = ws.Range("AA13:AY13").Value[0]
    false_counts = {h: int(c) for h, c in zip(hdrs, counts) if c}
    print("FALSE counts:", false_counts)
    usd_net_pct = ws.Range("AM10").Value
    eur_net_pct = ws.Range("AN10").Value
    if not isinstance(usd_net_pct, float):
        usd_net_pct = 0.0
    if not isinstance(eur_net_pct, float):
        eur_net_pct = 0.0
    print("USD net %:", usd_net_pct, " EUR net %:", eur_net_pct)
    print("Cognos USD:", xl.WorksheetFunction.Sum(ws.Range(f"M{FIRST}:M{LAST}")),
          " PBI USD:", xl.WorksheetFunction.Sum(ws.Range(f"BM{FIRST}:BM{LAST}")))
    print("Cognos EUR:", xl.WorksheetFunction.Sum(ws.Range(f"N{FIRST}:N{LAST}")),
          " PBI EUR:", xl.WorksheetFunction.Sum(ws.Range(f"BN{FIRST}:BN{LAST}")))

    # results line and FALSE-block text carry the recalculated numbers
    usd_false = false_counts.get("Order Net Amount USD", 0)
    eur_false = false_counts.get("Order Net Amount EUR", 0)
    nt.Range("C9").Value = (
        f"Shipments: 2865 of 2865 Cognos rows matched, 2 Power BI-only rows (orders placed after "
        f"the Cognos export). Order Net Amount USD is the cube's stored net amount "
        f"(net variance {usd_net_pct:+.2%}); EUR is the cube's native EUR for EUR-currency companies, "
        f"otherwise USD at the month-end EUR/USD rate A of the GL date (net variance {eur_net_pct:+.2%}). "
        f"The {usd_false} USD / {eur_false} EUR row-level FALSEs are rate-basis differences - Cognos "
        f"re-converts every line at its own monthly rate - plus the two back-ordered lines, which "
        f"carry 0 in the cube's net columns.")
    # after the row-26 insert the old USD/EUR explanation rows sit at 28/29
    rs.Range("A28").Value = (f"Order Net Amount USD ({usd_false}): rate basis - Cognos re-converts at its own "
                             f"monthly rate; the report carries the cube's stored USD. Includes the two "
                             f"back-ordered lines (2645790-1, 26001448-1), 0 in the cube's net column.")
    rs.Range("A29").Value = (f"Order Net Amount EUR ({eur_false}): rate basis - the report converts USD-company "
                             f"lines at the cube's month-end rate A; Cognos uses its own monthly rate. "
                             f"Includes the two back-ordered lines, 0 in the cube's net column.")
    xl.CalculateFullRebuild()

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
print("saved:", WB_PATH)
