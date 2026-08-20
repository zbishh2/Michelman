"""usage: python mk_probe_def.py <file.dax> <TableName> "col:type,col:type,..." [db]
Prints the JSON `definitions` array for table_operations Create (probe table wrapping the DAX in AnalysisServices.Database)."""
import sys,json,re
dax=open(sys.argv[1],encoding='utf-8').read()
dax='\n'.join(l for l in dax.splitlines() if not l.strip().startswith('//'))
dax=re.sub(r'\s+',' ',dax).strip()
name=sys.argv[2]; cols=sys.argv[3]; db=sys.argv[4] if len(sys.argv)>4 else 'BIQLTabular'
m=('let Raw = AnalysisServices.Database("SSASPROD","%s",[ Query = "%s" ]), '
   'Data = Table.TransformColumnNames(Raw, each if Text.StartsWith(_, "[") and Text.EndsWith(_, "]") then Text.Middle(_, 1, Text.Length(_) - 2) else _) in Data') % (db, dax.replace('"','""'))
defs=[{"name":name,"mExpression":m,"columns":[{"name":c.split(':')[0],"dataType":c.split(':')[1],"sourceColumn":c.split(':')[0]} for c in cols.split(',')]}]
print(json.dumps(defs))
