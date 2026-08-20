import sys,json,re
dax=open(sys.argv[1],encoding='utf-8').read()
# strip // comment lines
dax='\n'.join(l for l in dax.splitlines() if not l.strip().startswith('//'))
dax=re.sub(r'\s+',' ',dax).strip()
db = sys.argv[2] if len(sys.argv)>2 else 'BIQLTabular'
m = ('let Raw = AnalysisServices.Database("SSASPROD","%s",[ Query = "%s" ]), '
     'Data = Table.TransformColumnNames(Raw, each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]") then Text.Middle(_, 1, Text.Length(_) - 2) else _) in Data') % (db, dax.replace('"','""'))
print(json.dumps(m))
