# Pull full table data from the open 07/09 PBI models via ADOMD (no MCP 100-row cap),
# and generate the cognos_/pbi_ CSVs the compare pipelines expect.
import clr, csv, os, openpyxl
DLL = r'C:/Program Files/Microsoft Office/root/Office16/ADDINS/Microsoft Power Query for Excel Integrated/bin/Microsoft.PowerBI.AdomdClient.dll'
clr.AddReference(DLL)
from Microsoft.AnalysisServices.AdomdClient import AdomdConnection
from System import DateTime, DBNull

BASE = r'C:/Users/Zack/Documents/Code/michelman/Cognos Reports/Excel Validation/_validation_work'

def conv(v):
    if v is None or isinstance(v, DBNull): return ''
    if isinstance(v, DateTime): return v.ToString('yyyy-MM-dd HH:mm:ss')
    return str(v)

def pull(port, table):
    con = AdomdConnection('Data Source=localhost:%d' % port); con.Open()
    cmd = con.CreateCommand(); cmd.CommandText = 'EVALUATE %s' % table
    rdr = cmd.ExecuteReader()
    n = rdr.FieldCount
    cols = [rdr.GetName(i) for i in range(n)]
    rows = []
    while rdr.Read():
        rows.append([conv(rdr.GetValue(i)) for i in range(n)])
    rdr.Close(); con.Close()
    return cols, rows

def write_csv(path, cols, rows):
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(cols); w.writerows(rows)

def excel_rows(xlsx, sheet):
    wb = openpyxl.load_workbook(xlsx, data_only=True); ws = wb[sheet]
    data = [r for r in ws.iter_rows(values_only=True) if any(c is not None for c in r)]
    hdr = [str(c) if c is not None else '' for c in data[0]]
    body = []
    for r in data[1:]:
        body.append([conv_xl(c) for c in r])
    return hdr, body

def conv_xl(v):
    import datetime
    if v is None: return ''
    if isinstance(v, (datetime.datetime, datetime.date)):
        return v.strftime('%Y-%m-%d %H:%M:%S')
    return str(v)

TABLES = ['Inventory','Work_Orders','Sales_Order_Summary','Inventory_HP','Safety_Stock_HP']

# ---- 07: raw pbi pulls (compare.py reads Excel itself; we only supply PBI) ----
p07 = os.path.join(BASE, '07 - Ivan SK 2023')
print('=== 07 (port 51953) ===')
for t in TABLES:
    cols, rows = pull(51953, t)
    write_csv(os.path.join(p07, '_raw_pbi_%s.csv' % t), cols, rows)
    print('  %-22s %d rows' % (t, len(rows)))

# ---- 09: both cognos_ (from fresh Excel) and pbi_ (from model) ----
p09 = os.path.join(BASE, '09 - Ivan FC 2023')
XLSX09 = r'C:/Users/Zack/Documents/Code/michelman/Cognos Reports/Excel Validation/1 - Ivan FC 2023.xlsx'
SHEET = {'inventory':'Inventory_1','work_orders':'Work Order_2','sales_order_summary':'Sales Orders_3',
         'inventory_hp':'Inventory HP_4','safety_stock_hp':'Safety Stock HP_5'}
LC = {'inventory':'Inventory','work_orders':'Work_Orders','sales_order_summary':'Sales_Order_Summary',
      'inventory_hp':'Inventory_HP','safety_stock_hp':'Safety_Stock_HP'}
print('=== 09 (port 51956) ===')
for lc, sheet in SHEET.items():
    chdr, crows = excel_rows(XLSX09, sheet)
    write_csv(os.path.join(p09, 'cognos_%s.csv' % lc), chdr, crows)
    pcols, prows = pull(51956, LC[lc])
    write_csv(os.path.join(p09, 'pbi_%s.csv' % lc), pcols, prows)
    print('  %-22s cognos %d / pbi %d rows' % (lc, len(crows), len(prows)))
print('DONE')
