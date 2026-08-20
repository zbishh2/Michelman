"""Pull each report-22 page at the table visual's display grain from the published model
(Zack (Validation) / 22 - CM - Information 2020 - Future (SSAS Import)) via executeQueries."""
import json, subprocess, csv, os, sys
WS = '50b98bb9-9fcb-47db-a0df-f2c167b351fb'; DS = '89c6fd75-66e1-4f6c-8db0-5906e64e9451'
HERE = os.path.dirname(os.path.abspath(__file__))

def cols(t, names): return ", ".join("'%s'[%s]" % (t, n) for n in names)
def meas(names): return ", ".join('"%s", [%s]' % (n, n) for n in names)

Q = {
"Receipts": "EVALUATE SUMMARIZECOLUMNS ( %s, %s )" % (
    cols("Receipts", ["Global Bulk Item","Bulk Item","2nd Item Number","Vendor Name","Vendor ID","Receipt Transaction Type","Receipt Transaction Date","Order Type","Document Number","Line Number","Document Type","Date","Year","Month"]),
    meas(["Received Quantity","Received Quantity LBs","Received Quantity KGs","Amount Received","Amount Received USD","Amount Received EUR"])),
"Shipments": "EVALUATE SUMMARIZECOLUMNS ( %s, %s )" % (
    cols("Shipments", ["Order Company","Branch Plant","Order Number","Line Number","Open Indicator","Global Bulk Item","Bulk Item","2nd Item Number","Description 1","Description 2","Freight Handling Code","Next Status","Revenue Business Unit","TM Name","Customer Name","Country Name","Global Parent Name","Date","Year","Month","Chemist Name"]),
    meas(["Order Net Amount USD","Order Net Amount EUR","Ordered Quantity LBs","Ordered Quantity KGs","Raw Material Margin USD","Raw Material Margin EUR"])),
"Forecast": "EVALUATE SUMMARIZECOLUMNS ( %s, %s )" % (
    cols("Forecast", ["Company Code","Branch Plant","Global Bulk Item","Bulk Item","2nd Item Number","Item Description 1","Item Description 2","Requested Date","TM Name","Primary UOM","Date","Year","Month","Customer Code","Customer Name","Global Parent Name","Chemist Name"]),
    meas(["Current Forecast","Current Forecast LB","Current Forecast KG"])),
"Work Orders": "EVALUATE SUMMARIZECOLUMNS ( %s, %s )" % (
    cols("Work Orders", ["Branch Plant","Global Bulk Item","Bulk Item","2nd Item Number","WO Number","Start Date","Completion Date","Year","Month","WO Status","Component Branch Plant","Component 2nd Item Number","Component UOM","Component Global Bulk Item","Component Bulk Item","Component Item 2nd Item Number","Stock Type Code"]),
    meas(["Issued Quantity","Quantity Ordered"])),
"BOM": "EVALUATE SUMMARIZECOLUMNS ( %s, %s )" % (
    cols("BOM", ["Branch Plant","Parent Second Item Number","2nd Item Number","Bulk Item","Global Bulk Item"]), meas(["Quantity"])),
"Item Details": "EVALUATE 'Item Details'",
}

for name, q in Q.items():
    body = {"queries": [{"query": q}], "serializerSettings": {"includeNulls": True}}
    bf = os.path.join(HERE, "_body.json"); open(bf, "w", encoding="utf-8").write(json.dumps(body))
    r = subprocess.run(["fab", "api", "-A", "powerbi", f"groups/{WS}/datasets/{DS}/executeQueries", "-X", "post", "-i", bf], capture_output=True, text=True, shell=True)
    j = json.loads(r.stdout)
    if "text" in j: j = j["text"]
    if isinstance(j, str): j = json.loads(j)
    rows = j["results"][0]["tables"][0]["rows"]
    c = list(rows[0].keys())
    def clean(x): return x.split("[", 1)[1][:-1] if "[" in x else x
    out = os.path.join(HERE, "pbi_%s.csv" % name.replace(" ", "_").lower())
    with open(out, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow([clean(x) for x in c])
        for rr in rows: w.writerow([rr.get(x) for x in c])
    print(name, len(rows), "rows")
    os.remove(bf)
