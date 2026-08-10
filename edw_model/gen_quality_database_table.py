# -*- coding: utf-8 -*-
"""Emit 'Quality Database WOs.tmdl'. Indentation is applied by tab depth, never typed."""
import io

MSRC = (r'C:\Users\Zack\LeanGo\LeanGo - Documents\Clients\Michelman Bryan Becker\Michelman'
        r'\edw_model\QualityDatabaseWorkOrders.m')
OUT = (r'C:\Users\Zack\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects'
       r'\Executive Dashboard\Executive Dashboard.SemanticModel\definition\tables'
       r'\Quality Database WOs.tmdl')
TBL = "'Quality Database WOs'"

SRCCOLS = [
    ('Sheet Row', 'int64', '0', 'none', 'ba3f6017-8d24-4e59-b0c7-451e8d92f306',
     'Ordinal position of the row in the extract. Exists so a work order\'s rows can be counted '
     'without CALCULATE - see the note on [Sheet Rows For This WO].', []),
    ('WO Number', 'int64', '0', 'none', '3c9e5d71-4028-4b93-a6f5-71ed08b249ca',
     'JDE work order number as recorded on their sheet. Relates many-to-one to WorkOrders.', []),
    ('Sheet Year', 'int64', '0', 'none', '5a2d81f6-7c34-4e09-b258-0947f3ea6c1d',
     'Year their sheet books the work order to.', []),
    ('Sheet Month', 'int64', '0', 'none', '8f01c9b4-2e56-4d7a-91c3-6b840f27de5b',
     'Month number their sheet books the work order to.', []),
    ('Sheet Month Start', 'dateTime', 'mmm yyyy', 'none', 'd4e73b18-6a92-4f50-8c71-25b09ef3417a',
     'First day of the month their sheet books the work order to. The axis their chart is drawn on.',
     ['annotation UnderlyingDateTimeDataType = Date']),
    ('Sheet Completion Date', 'dateTime', 'm/d/yy', 'none', '2b8a60d5-93c7-4e18-a740-5fc16d82093e',
     'Completion date as recorded on their sheet. Their month bucket is the month of this date.',
     ['annotation UnderlyingDateTimeDataType = Date',
      'annotation PBI_FormatHint = {"isDateTimeCustom":true}']),
    ('Region', 'string', None, 'none', '7e4c92a0-1b58-4d36-9f82-c0537ae6d194',
     'Region as recorded on their sheet.', []),
    ('Branch Plant', 'string', None, 'none', '0a6f38e2-5d94-4712-b8c6-9e2701f5ad83',
     'JDE branch plant as recorded on their sheet.', []),
    ('Location', 'string', None, 'none', 'c58d1740-3e6b-49a2-8517-b6f094e2d371',
     'Plant name their sheet derives from the branch: Shell, Kemper, Aubange or Singapore.', []),
    ('Item Number', 'string', None, 'none', '91b27ce6-408f-4d15-a963-72e5c8f30b4a',
     'Second item number as recorded on their sheet. The bulk item the batch produced.', []),
    ('Global Bulk Item', 'string', None, 'none', '6d403f95-8a71-4c2e-b059-1748ec92035f',
     'Global bulk item grouping as recorded on their sheet.', []),
    ('Product Family', 'string', None, 'none', 'a2704e83-c516-4bd9-8f31-e6905d2c7148',
     'Product family as recorded on their sheet.', []),
    ('Work Center', 'string', None, 'none', '4f81d63a-27e0-4956-b1c8-503fa7e91d62',
     'Production work centre their sheet attributes the batch to. Agrees with a real JDE routing '
     'operation on 99.9% of matched work orders.', []),
    ('Standard Work Center', 'string', None, 'none', 'e30956c1-7d24-48af-9026-c185b4f7302d',
     'Standard work centre grouping their sheet rolls the batch up to.', []),
    ('WO Completed KGs', 'double', '#,0', 'sum', '17a4bc02-8e59-4d31-b076-4c8390fa2e15',
     'Completed quantity in kilograms as recorded on their sheet.', []),
    ('WO Requested KGs', 'double', '#,0', 'sum', '8c520e97-46b3-4d1f-a075-9e2831a0b7d4',
     'Requested quantity in kilograms as recorded on their sheet.', []),
    ('Duplicate Work Order Catch', 'string', None, 'none', 'b6183ea4-5029-4c7d-91f6-3d40e857a29b',
     'Their own duplicate flag. Their chart keeps only the rows reading OK. It does not catch '
     'every repeat - see [Tie-Out Status].', []),
    ('Within Date Range', 'string', None, 'none', '2ef70946-8b13-45ca-a3d8-6019c74be502',
     'Their own date-window flag, carried over unchanged.', []),
    ('Unique ID', 'string', None, 'none', '5904ac31-e762-4b08-9d75-84c2f1360ea9',
     'Row key their sheet builds. Not unique in practice.', []),
]

# NOT CALCULATE. A calculated column that uses CALCULATE takes a dependency on EVERY column
# of its own table, so two such columns on one table depend on each other and the model will
# not open -- "A circular dependency was detected", which is exactly how the first cut of
# this table failed on 2026-08-07. FILTER over ALL(<named columns>) depends on those columns
# alone. ALL over several columns returns DISTINCT combinations and would collapse the very
# repeats being counted, which is what [Sheet Row] is in the extract for.
EXPR_ROWS = """
VAR _wo = 'Quality Database WOs'[WO Number]
RETURN
    COUNTROWS (
        FILTER (
            ALL (
                'Quality Database WOs'[WO Number],
                'Quality Database WOs'[Duplicate Work Order Catch],
                'Quality Database WOs'[Sheet Row]
            ),
            'Quality Database WOs'[WO Number] = _wo
                && 'Quality Database WOs'[Duplicate Work Order Catch] = "OK"
        )
    )
"""

EXPR_FLAG = """
LOOKUPVALUE (
    WorkOrders[SOP Flag - Counts As Batch],
    WorkOrders[WorkOrderNum], 'Quality Database WOs'[WO Number]
)
"""

EXPR_MONTH = """
VAR _d =
    LOOKUPVALUE (
        WorkOrders[Completion Date (SOP Basis)],
        WorkOrders[WorkOrderNum], 'Quality Database WOs'[WO Number]
    )
RETURN
    IF ( NOT ISBLANK ( _d ), DATE ( YEAR ( _d ), MONTH ( _d ), 1 ) )
"""

EXPR_STATUS = """
VAR _dup = 'Quality Database WOs'[Duplicate Work Order Catch]
VAR _okRows = 'Quality Database WOs'[Sheet Rows For This WO]
VAR _batch = 'Quality Database WOs'[EDW Batch Flag]
VAR _edwMonth = 'Quality Database WOs'[EDW S&OP Month]
VAR _shtMonth = 'Quality Database WOs'[Sheet Month Start]
RETURN
    SWITCH (
        TRUE (),
        _dup <> "OK", "Excluded by their duplicate filter",
        _okRows > 1, "Counted more than once",
        ISBLANK ( _batch ), "Work order not in EDW",
        _batch <> "Batch", "In EDW but not an S&OP batch",
        _edwMonth <> _shtMonth, "Counted in a different month",
        "Matched"
    )
"""

EXPR_REASON = """
VAR _wo = 'Quality Database WOs'[WO Number]
VAR _status = 'Quality Database WOs'[Tie-Out Status]
VAR _okRows = 'Quality Database WOs'[Sheet Rows For This WO]
VAR _edwMonth = 'Quality Database WOs'[EDW S&OP Month]
VAR _shtMonth = 'Quality Database WOs'[Sheet Month Start]
VAR _wc = LOOKUPVALUE ( WorkOrders[SOP Flag - Work Centre], WorkOrders[WorkOrderNum], _wo )
VAR _itm = LOOKUPVALUE ( WorkOrders[SOP Flag - Item], WorkOrders[WorkOrderNum], _wo )
VAR _sts = LOOKUPVALUE ( WorkOrders[SOP Flag - WO Status], WorkOrders[WorkOrderNum], _wo )
VAR _qty = LOOKUPVALUE ( WorkOrders[SOP Flag - Completed Qty], WorkOrders[WorkOrderNum], _wo )
VAR _notBatch =
    SWITCH (
        TRUE (),
        _wc <> "S&OP production WC",
            "The JDE routing carries no operation at an S&OP production work centre (" & _wc
                & "). Their sheet attributes it to " & 'Quality Database WOs'[Work Center] & ".",
        _itm <> "Bulk (no hyphen)", "The item is not a countable bulk item (" & _itm & ").",
        _sts <> "S&OP reported status",
            "The work order does not carry a reported status (" & _sts & ").",
        _qty <> "Completed > 0", "The work order completed no quantity (" & _qty & ").",
        "Excluded by the batch definition."
    )
RETURN
    SWITCH (
        _status,
        "Matched", BLANK (),
        "Excluded by their duplicate filter",
            "Their own duplicate filter drops this row, so it is not on their chart.",
        "Counted more than once",
            "Their sheet holds " & _okRows & " rows for this work order with the duplicate flag"
                & " reading OK, so their chart counts the same batch " & _okRows & " times.",
        "Work order not in EDW", "EDW holds no work order with this number.",
        "In EDW but not an S&OP batch", _notBatch,
        "Counted in a different month",
            "Their sheet books it to " & FORMAT ( _shtMonth, "mmm yyyy" )
                & "; the EDW S&OP date puts it in " & FORMAT ( _edwMonth, "mmm yyyy" ) & ".",
        BLANK ()
    )
"""

CALCCOLS = [
    ('Sheet Rows For This WO', 'int64', '0', 'none', 'f4c8021b-9375-4ea6-80d1-c7390ab5e264',
     'How many rows their sheet holds for this work order with the duplicate flag reading OK. '
     'Above one means their chart counts the same batch more than once.', False, EXPR_ROWS),
    ('EDW Batch Flag', 'string', None, 'none', '7b26e0d4-51fc-4938-a6b2-0e4915cd873f',
     'What the EDW batch definition makes of this work order. Blank when EDW holds no work order '
     'with this number.', False, EXPR_FLAG),
    ('EDW S&OP Month', 'dateTime', 'mmm yyyy', 'none', 'c0917f5e-3a48-4b72-9165-8de2470ba36c',
     'The month the EDW S&OP date basis puts this work order in, for comparison with '
     '[Sheet Month Start].', False, EXPR_MONTH),
    ('Tie-Out Status', 'string', None, 'none', '93de5a17-6c02-48bf-b740-1f85e2903c6d',
     'How this row reconciles against the EDW batch population. Matched means the same work order '
     'is counted in the same month on both sides.', False, EXPR_STATUS),
    ('Difference Reason', 'string', None, 'none', '48b1c7f0-2d96-4a35-8e07-5c31904fb2ae',
     'Why this row does not reconcile, in plain language. Blank when it reconciles.',
     False, EXPR_REASON),
]

L = []


def w(depth, text=''):
    L.append(('\t' * depth + text) if text else '')


def quoted(n):
    return "'%s'" % n if any(c in n for c in ' &-') else n


w(0, "/// The batch population the business measures to today: a frozen extract of the "
     "work_order_Detail table inside the client's Quality Database report, which is fed by a "
     "hand-maintained workbook on a file share. Present as evidence for the Tie-Out page only - "
     "no KPI reads it. Covers 2024 onward, the period WorkOrders also covers. Source query: "
     "edw_model/QualityDatabaseWorkOrders.m.")
w(0, 'table %s' % TBL)
w(1, 'lineageTag: b71f4a02-9d38-4c65-8e17-2a95c0d64831')
w(0)

for name, dt, fmt, summ, lt, desc, extra in SRCCOLS:
    w(1, '/// ' + desc)
    w(1, 'column %s' % quoted(name))
    w(2, 'dataType: %s' % dt)
    if fmt:
        w(2, 'formatString: %s' % fmt)
    w(2, 'lineageTag: %s' % lt)
    w(2, 'summarizeBy: %s' % summ)
    w(2, 'sourceColumn: %s' % name)
    w(0)
    w(2, 'annotation SummarizationSetBy = Automatic')
    for e in extra:
        w(0)
        w(2, e)
    w(0)

for name, dt, fmt, summ, lt, desc, hidden, expr in CALCCOLS:
    w(1, '/// ' + desc)
    w(1, 'column %s =' % quoted(name))
    for line in expr.strip('\n').split('\n'):
        if line.strip():
            w(4, line)
        else:
            w(0)
    w(2, 'dataType: %s' % dt)
    if fmt:
        w(2, 'formatString: %s' % fmt)
    if hidden:
        w(2, 'isHidden')
    w(2, 'lineageTag: %s' % lt)
    w(2, 'summarizeBy: %s' % summ)
    w(0)
    w(2, 'annotation SummarizationSetBy = Automatic')
    if dt == 'dateTime':
        w(0)
        w(2, 'annotation UnderlyingDateTimeDataType = Date')
    w(0)

m = io.open(MSRC, encoding='utf-8').read().replace('\r\n', '\n').split('\n')
m = [l for l in m if not l.lstrip().startswith('//')]
while m and m[0].strip() == '':
    m.pop(0)
while m and m[-1].strip() == '':
    m.pop()
body = []
for l in m:
    if l.strip() == '' and body and body[-1].strip() == '':
        continue
    body.append(l)

w(1, 'partition %s = m' % TBL)
w(2, 'mode: import')
w(2, 'source =')
for line in body:
    if line.strip():
        w(4, line)
    else:
        w(0)
w(0)
w(1, 'annotation PBI_ResultType = Table')
w(0)

io.open(OUT, 'w', encoding='utf-8', newline='\r\n').write('\n'.join(L) + '\n')
print('wrote %s' % OUT)
print('%d lines, %d source cols, %d calc cols' % (len(L), len(SRCCOLS), len(CALCCOLS)))
bad = [i + 1 for i, l in enumerate(L) if l.startswith(' ')]
print('lines indented with spaces:', bad[:5] if bad else 'none')
