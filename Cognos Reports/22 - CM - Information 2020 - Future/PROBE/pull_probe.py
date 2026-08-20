"""Pull a full probe-table result from the Validation host via executeQueries (no 100-row cap).
usage: python pull_probe.py "<DAX query>" out.csv
"""
import sys,json,subprocess,csv,os,tempfile
WS='50b98bb9-9fcb-47db-a0df-f2c167b351fb'; DS='a87a2810-496b-48d3-ad88-456e442c3ecb'
q,out=sys.argv[1],sys.argv[2]
body={"queries":[{"query":q}],"serializerSettings":{"includeNulls":True}}
bf=os.path.join(os.path.dirname(os.path.abspath(out)),'_body.json')
open(bf,'w',encoding='utf-8').write(json.dumps(body))
r=subprocess.run(['fab','api','-A','powerbi',f'groups/{WS}/datasets/{DS}/executeQueries','-X','post','-i',bf],capture_output=True,text=True,shell=True)
txt=r.stdout
try:
    j=json.loads(txt)
except Exception:
    print(txt[:2000]); print(r.stderr[:2000]); sys.exit(1)
if 'text' in j: j=j['text']
if isinstance(j,str): j=json.loads(j)
rows=j['results'][0]['tables'][0]['rows']
if not rows: print('0 rows'); open(out,'w').write(''); sys.exit()
cols=list(rows[0].keys())
def clean(c):
    return c.split('[',1)[1][:-1] if '[' in c else c
with open(out,'w',newline='',encoding='utf-8') as f:
    w=csv.writer(f); w.writerow([clean(c) for c in cols])
    for r_ in rows: w.writerow([r_.get(c) for c in cols])
print(len(rows),'rows ->',out)
os.remove(bf)
