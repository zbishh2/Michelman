import csv, os
OUT = "_validation_work/01 - RM Staging"
qdir = "C:/Users/Zack/AppData/Local/Temp/PowerBIModelingMCP/QueryResults"

def load_mcp(path):
    with open(path, newline="", encoding="utf-8-sig") as f:
        rows=list(csv.reader(f))
    hdr=[h.split('[')[-1].rstrip(']') for h in rows[0]]
    return [dict(zip(hdr,r)) for r in rows[1:]]

full = load_mcp(qdir+"/dax_query_result_20260706_211111_437.csv")   # full 135 (this call returned first 100? no, maxRows100000)
filt = load_mcp(qdir+"/dax_query_result_20260706_211113_158.csv")   # short-filtered 15

# Save full dump (135) and filtered dump
def norm_date(s):
    # '7/6/2026 12:00:00 AM' -> date tuple
    d=s.split(' ')[0]; m,day,y=d.split('/'); return (int(y),int(m),int(day))
def dstr(s):
    return s.split(' ')[0]

with open(f"{OUT}/pbi_WorkOrder_Detail.csv","w",newline="") as f:
    w=csv.writer(f); w.writerow(["Work Order Start","WO Number","Raw Material","FG Item"])
    for r in sorted(full,key=lambda r:(norm_date(r['Work Order Start']),r['Raw Material'],r['WO Number'])):
        w.writerow([dstr(r['Work Order Start']),r['WO Number'],r['Raw Material'],r['FG Item']])

# Cognos 15 rows (as transcribed by lead; date normalized to m/d/yyyy)
cognos=[
 ("7/6/2026","DMD5980I","4580827","RHOB320"),
 ("7/7/2026","ME91735O","4582842","ME91735"),
 ("7/8/2026","AFEG8200G","4582701","HYPOD8510"),
 ("7/8/2026","AFEG8200G","4582702","HYPOD8510"),
 ("7/8/2026","DMD5980I","4582701","HYPOD8510"),
 ("7/8/2026","DMD5980I","4582702","HYPOD8510"),
 ("7/8/2026","POLYMINP","4583019","DP050"),
 ("7/9/2026","AC6","4583664","J1751"),
 ("7/9/2026","AC680","4583664","J1751"),
 ("7/9/2026","AC950","4582908","PP201"),
 ("7/9/2026","AFEG8200G","4583336","HYPOD8510"),
 ("7/9/2026","AFEG8200G","4583518","HYPOD8510"),
 ("7/9/2026","DMD5980I","4583336","HYPOD8510"),
 ("7/9/2026","DMD5980I","4583518","HYPOD8510"),
 ("7/9/2026","XIRAN1440M","4583328","MD2685"),
]
# key = (date, RawMaterial, WO#, FGItem)
def keyc(t): return (t[0],t[1],t[2],t[3])
def keyp(r): return (dstr(r['Work Order Start']),r['Raw Material'],r['WO Number'],r['FG Item'])

pbi_short={ keyp(r):r for r in filt }
cog_keys=[keyc(t) for t in cognos]

# comparison: match on (date,RM,WO#) then flag each column
fieldnames=["cog_Work Order Start","cog_Raw Material","cog_WO Number","cog_FG Item",
            "date_match","rawmat_match","wo_match","fg_match","row_match",
            "pbi_Work Order Start","pbi_Raw Material","pbi_WO Number","pbi_FG Item"]
comp=[]
matched=0
pbi_used=set()
for t in cognos:
    k=keyc(t)
    p=pbi_short.get(k)
    if p:
        pbi_used.add(k)
        row={"cog_Work Order Start":t[0],"cog_Raw Material":t[1],"cog_WO Number":t[2],"cog_FG Item":t[3],
             "date_match":1,"rawmat_match":1,"wo_match":1,"fg_match":1,"row_match":1,
             "pbi_Work Order Start":dstr(p['Work Order Start']),"pbi_Raw Material":p['Raw Material'],
             "pbi_WO Number":p['WO Number'],"pbi_FG Item":p['FG Item']}
        matched+=1
    else:
        # try match on date+RM+WO ignoring FG
        row={"cog_Work Order Start":t[0],"cog_Raw Material":t[1],"cog_WO Number":t[2],"cog_FG Item":t[3],
             "date_match":0,"rawmat_match":0,"wo_match":0,"fg_match":0,"row_match":0,
             "pbi_Work Order Start":"","pbi_Raw Material":"","pbi_WO Number":"","pbi_FG Item":""}
    comp.append(row)
# PBI-short rows not matched by any Cognos row
for k,p in pbi_short.items():
    if k not in pbi_used:
        comp.append({"cog_Work Order Start":"","cog_Raw Material":"","cog_WO Number":"","cog_FG Item":"",
             "date_match":0,"rawmat_match":0,"wo_match":0,"fg_match":0,"row_match":0,
             "pbi_Work Order Start":dstr(p['Work Order Start']),"pbi_Raw Material":p['Raw Material'],
             "pbi_WO Number":p['WO Number'],"pbi_FG Item":p['FG Item']})

with open(f"{OUT}/comparison_workorder_detail.csv","w",newline="") as f:
    w=csv.DictWriter(f,fieldnames=fieldnames); w.writeheader()
    for r in comp: w.writerow(r)

print("Cognos rows:",len(cognos))
print("PBI short-filtered rows:",len(filt))
print("PBI full-table rows:",len(full),"(note: this dump call)")
print("Matched (all 4 cols):",matched,"/",len(cognos))
print("Unmatched Cognos:",[c for i,c in enumerate(cognos) if comp[i]['row_match']==0])
print("PBI-short not in Cognos:",[k for k in pbi_short if k not in pbi_used])
