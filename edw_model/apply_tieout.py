# -*- coding: utf-8 -*-
"""apply_tieout.py -- (re)apply the batch tie-out additions to the Executive Dashboard model.

WHY THIS EXISTS AS A SCRIPT RATHER THAN HAND EDITS
On 2026-08-07 every one of these edits was wiped in one go: Desktop was open on the jumpbox,
it saved, and the save serialised the whole SemanticModel from its own state straight over the
top through OneDrive. Nothing was recoverable from the tree -- only from the generators. So the
whole set is scripted and idempotent: run it again after any jumpbox save that lands before a
refresh has picked these up, and it will restore exactly the same model.

  python edw_model/apply_tieout.py            # apply
  python edw_model/apply_tieout.py --check    # report what is present, change nothing

DESKTOP MUST BE CLOSED ON THE JUMPBOX BEFORE RUNNING THIS. See CLAUDE.md section 1.

WHAT IT ADDS
  table  'SOP Excluded Items'   the boil-out / cleaning item codes, a maintained list
  table  'Quality Database WOs' frozen extract of the sheet the business measures to today
  cols   WorkOrders[S&OP Month]  -- and nothing else, see the WO_COLS note below
  meas   10 x [Tie-Out - ...], including the two that replaced WorkOrders calculated columns
  rel    'Quality Database WOs'[WO Number] -> WorkOrders[WorkOrderNum], bidirectional

AND AMENDS
  WorkOrders[SOP Flag - Item] and [SOP Flag - Counts As Batch] to test the excluded-item
  table instead of three hardcoded codes (Jessica's list, 2026-08-07).
"""
import io, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEF = (r'C:\Users\Zack\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects'
       r'\Executive Dashboard\Executive Dashboard.SemanticModel\definition')
TABLES = os.path.join(DEF, 'tables')
CHECK = '--check' in sys.argv

# The boil-out and cleaning item codes that must never count as a batch. Supplied by Jessica
# 2026-08-07, replacing the three codes transcribed from the Cognos S&OP report. Nine of the
# fifteen match nothing in EDW today; they are kept so the list is the client's, verbatim.
EXCLUDED_ITEMS = [
    'BOILOUT', 'BOILOUT.E', 'BOILOUT286', 'BOILOUTC.E', 'BOILOUTC',
    'BOILOUT286.E', 'BOILEPOX', 'BOILEPOX.E', 'ECBOILOUT', 'BOILOUT.S',
    'SBOILOUT.S', 'BOILOUTA', 'BOILOUTA.E', 'BOILOUTH.E', 'ECBOILOUT.S',
]

OLD_ITEM_TEST = 'WorkOrders[Item Num] IN { "BOILOUT.E", "BOILOUT.S", "BOILEPOX.E" }'
NEW_ITEM_TEST = "WorkOrders[Item Num] IN ALL ( 'SOP Excluded Items'[Item Num] )"

report = []


def note(ok, msg):
    report.append(('  ok   ' if ok else '  ADD  ') + msg)


def read(p):
    return io.open(p, encoding='utf-8', newline='').read()


def write(p, s):
    if not CHECK:
        io.open(p, 'w', encoding='utf-8', newline='').write(s)


def tabs(lines):
    """lines is a list of (depth, text); '' text emits a bare blank line."""
    return '\r\n'.join(('\t' * d + t) if t else '' for d, t in lines)


# --------------------------------------------------------------- 1. excluded items table
def excluded_items_table():
    p = os.path.join(TABLES, 'SOP Excluded Items.tmdl')
    if os.path.exists(p):
        note(True, "table 'SOP Excluded Items'")
        return
    note(False, "table 'SOP Excluded Items'")
    wrapped, line = [], ''
    for i, code in enumerate(EXCLUDED_ITEMS):
        tok = '"%s"' % code + (', ' if i < len(EXCLUDED_ITEMS) - 1 else '')
        if len(line) + len(tok) > 74:
            wrapped.append(line.rstrip())
            line = ''
        line += tok
    if line:
        wrapped.append(line.rstrip())
    L = [(0, '/// Item codes that never count as a batch: boil-out and cleaning runs, which pass '
             'through production work centres but produce no saleable bulk. A maintained list - '
             'add a code here to exclude it from Right Time First Batch.'),
         (0, "table 'SOP Excluded Items'"),
         (1, 'lineageTag: 5d90e2c7-4a13-4b86-9f27-c30e158fa64b'),
         (0, ''),
         (1, '/// JDE item number. Matches WorkOrders[Item Num].'),
         (1, "column 'Item Num'"),
         (2, 'dataType: string'),
         (2, 'lineageTag: 8e12b40f-6c95-4d73-a5e8-2b7091fc3d58'),
         (2, 'summarizeBy: none'),
         (2, 'sourceColumn: [Item Num]'),
         (0, ''),
         (2, 'annotation SummarizationSetBy = Automatic'),
         (0, ''),
         (1, "partition 'SOP Excluded Items' = calculated"),
         (2, 'mode: import'),
         (2, 'source ='),
         (4, 'SELECTCOLUMNS ('),
         (4, '    {')]
    for wline in wrapped:
        L.append((4, '        ' + wline))
    L += [(4, '    },'),
          (4, '    "Item Num", [Value]'),
          (4, ')'),
          (0, ''),
          (1, 'annotation PBI_Id = 7c4b16e9f0a2438d95e17c60b83fa2d4'),
          (0, '')]
    write(p, tabs(L) + '\r\n')


# --------------------------------------------------------------- 2. WorkOrders amendments
# ⚠ ONLY [S&OP Month] LIVES HERE, and that is the whole point. 'Quality Database WOs'
# calculated columns read WorkOrders; if WorkOrders calculated columns read back, DAX closes
# a circular dependency AT TABLE GRANULARITY and the PBIP will not open. The classification
# that used to sit here is now measures, which take no part in that graph. Do not add a
# calculated column here that mentions 'Quality Database WOs'.
WO_COLS = [
    ('S&OP Month', 'dateTime', 'mmm yyyy', 'c6f0428d-71b9-4e35-a806-395d2ec417f0',
     'First day of the month [Completion Date (SOP Basis)] falls in. The month a batch is '
     'counted in.',
     """
VAR _d = WorkOrders[Completion Date (SOP Basis)]
RETURN
    IF ( NOT ISBLANK ( _d ), DATE ( YEAR ( _d ), MONTH ( _d ), 1 ) )
"""),
]


# The two batch flags, rewritten off CALCULATE. A calculated column that uses CALCULATE takes
# a dependency on EVERY column of its own table, which makes every later addition to WorkOrders
# a circular-dependency risk. Leaving the table free of CALCULATE columns is what makes
# [S&OP Month] safe to add.
#
# ⚠ THESE ARE NOT COSMETIC COPIES -- THEY OVERWRITE PRODUCTION. Both bodies were rewritten on
# 2026-08-07 and this file was updated to match. If you edit either flag in the TMDL, EDIT IT
# HERE TOO, or the next run of this script silently reverts it. What changed:
#   [SOP Flag - Work Centre]     inverted. Was "is the routing at one of the 95 listed
#                                production centres"; is now "is it at a JDE RNM rename
#                                centre", passing everything else. 'SOP Work Centres' is
#                                retired and this expression no longer reads it.
#   [SOP Flag - Counts As Batch] five conditions, not four, and it now REFERENCES the two
#                                rename flag columns instead of inlining the work centre test.
# Rationale, scoreboard and the do-not-simplify warning: ExecutiveDashboard_Model.dax.
FLAG_EXPRS = {
    'SOP Flag - Work Centre': """
VAR _wo = WorkOrders[WorkOrderSKey]
VAR _ops =
    COUNTROWS (
        FILTER (
            ALL (
                WorkOrderRouting[WorkOrderSKey],
                WorkOrderRouting[Bulk Production Work Center]
            ),
            WorkOrderRouting[WorkOrderSKey] = _wo
        )
    )
VAR _rename =
    COUNTROWS (
        FILTER (
            ALL (
                WorkOrderRouting[WorkOrderSKey],
                WorkOrderRouting[Bulk Production Work Center]
            ),
            WorkOrderRouting[WorkOrderSKey] = _wo
                && WorkOrderRouting[Bulk Production Work Center] = "RNM"
        )
    )
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( _ops ), "No routing",
        _rename > 0, "Rename work centre",
        "Production work centre"
    )
""",
    'SOP Flag - Counts As Batch': """
IF (
        WorkOrders[SOP Flag - Rename (Parts)] = "Not a rename"
            && WorkOrders[SOP Flag - Work Centre] = "Production work centre"
            && NOT ISBLANK ( WorkOrders[Item Num] )
            && NOT CONTAINSSTRING ( WorkOrders[Item Num], "-" )
            && NOT ( WorkOrders[Item Num] IN ALL ( 'SOP Excluded Items'[Item Num] ) )
            && WorkOrders[WO Status] IN { "93", "94", "95", "97", "99" }
            && WorkOrders[QuantityShipped] > 0,
        "Batch",
        "Not a batch"
    )
""",
}


def swap_expression(txt, colname, expr):
    """Replace a calculated column's body, leaving its properties untouched."""
    head = "\tcolumn '%s' =\r\n" % colname
    i = txt.index(head) + len(head)
    # The body ends at the column's first property line. These two columns carry no
    # dataType:, so take whichever marker comes first -- searching for dataType: alone
    # runs on into the NEXT column and swallows it.
    j = min(k for k in (txt.find('\t\tdataType:', i), txt.find('\t\tlineageTag:', i),
                        txt.find('\t\tformatString:', i)) if k != -1)
    body = '\r\n'.join('\t\t\t\t' + ln if ln.strip() else '' for ln in expr.strip('\n').split('\n'))
    return txt[:i] + body + '\r\n' + txt[j:]


def workorders():
    p = os.path.join(TABLES, 'WorkOrders.tmdl')
    txt = read(p)

    assert "'Quality Database WOs'" not in txt, (
        'WorkOrders must not reference the sheet table from a calculated column - that is the '
        'circular dependency that stopped the PBIP opening twice on 2026-08-07')

    for name, expr in FLAG_EXPRS.items():
        head = "\tcolumn '%s' =" % name
        seg = txt[txt.index(head):txt.index(head) + 1400]
        if 'CALCULATE' in seg:
            note(False, 'WorkOrders[%s] -> iterator form (no CALCULATE)' % name)
            txt = swap_expression(txt, name, expr)
        else:
            note(True, 'WorkOrders[%s] iterator form' % name)

    if OLD_ITEM_TEST in txt:
        note(False, 'WorkOrders boil-out test -> excluded-item table (%d occurrences)'
             % txt.count(OLD_ITEM_TEST))
        txt = txt.replace(OLD_ITEM_TEST, NEW_ITEM_TEST)
    else:
        note(NEW_ITEM_TEST in txt, 'WorkOrders boil-out test')

    if "column 'S&OP Month'" in txt:
        note(True, 'WorkOrders[S&OP Month]')
    else:
        note(False, 'WorkOrders[S&OP Month]')
        L = []
        for name, dt, fmt, lt, desc, expr in WO_COLS:
            L.append((1, '/// ' + desc))
            L.append((1, "column '%s' =" % name))
            for line in expr.strip('\n').split('\n'):
                L.append((4, line) if line.strip() else (0, ''))
            L.append((2, 'dataType: %s' % dt))
            if fmt:
                L.append((2, 'formatString: %s' % fmt))
            L.append((2, 'lineageTag: %s' % lt))
            L.append((2, 'summarizeBy: none'))
            L.append((0, ''))
            L.append((2, 'annotation SummarizationSetBy = Automatic'))
            if dt == 'dateTime':
                L.append((0, ''))
                L.append((2, 'annotation UnderlyingDateTimeDataType = Date'))
            L.append((0, ''))
        marker = '\tpartition WorkOrders = m\r\n'
        assert marker in txt, 'WorkOrders partition marker not found'
        txt = txt.replace(marker, tabs(L) + '\r\n' + marker)

    write(p, txt)


# --------------------------------------------------------------- 3. measures
REASON = """VAR _wo = SELECTEDVALUE ( WorkOrders[WorkOrderNum] )
VAR _month = SELECTEDVALUE ( WorkOrders[S&OP Month] )
VAR _batch = SELECTEDVALUE ( WorkOrders[SOP Flag - Counts As Batch] )
VAR _comp = SELECTEDVALUE ( WorkOrders[Completion Date] )
VAR _sop = SELECTEDVALUE ( WorkOrders[Completion Date (SOP Basis)] )
VAR _first =
    MINX ( ALL ( 'Quality Database WOs'[Sheet Month Start] ), 'Quality Database WOs'[Sheet Month Start] )
VAR _last =
    MAXX ( ALL ( 'Quality Database WOs'[Sheet Month Start] ), 'Quality Database WOs'[Sheet Month Start] )
VAR _onSheet =
    CALCULATE (
        COUNTROWS ( 'Quality Database WOs' ),
        REMOVEFILTERS ( 'Quality Database WOs' ),
        'Quality Database WOs'[WO Number] = _wo,
        'Quality Database WOs'[Duplicate Work Order Catch] = "OK"
    )
VAR _dropped =
    NOT ISBLANK ( _wo )
        && _batch = "Batch"
        && NOT ISBLANK ( _month )
        && _month >= _first
        && _month < _last
        && ISBLANK ( _onSheet )
RETURN
    IF (
        NOT _dropped,
        BLANK (),
        IF (
            EOMONTH ( _comp, 0 ) > EOMONTH ( _sop, 0 ),
            "Completed " & FORMAT ( _comp, "d mmm yyyy" ) & ", after its "
                & FORMAT ( _sop, "mmm yyyy" )
                & " month had closed, so that month's extract never saw it.",
            "Completed " & FORMAT ( _comp, "d mmm yyyy" )
                & ", inside its own month but after that month's extract was taken."
        )
    )"""

SETS = """VAR _first =
    MINX ( ALL ( 'Quality Database WOs'[Sheet Month Start] ), 'Quality Database WOs'[Sheet Month Start] )
VAR _last =
    MAXX ( ALL ( 'Quality Database WOs'[Sheet Month Start] ), 'Quality Database WOs'[Sheet Month Start] )
VAR _sheet =
    TREATAS (
        CALCULATETABLE (
            VALUES ( 'Quality Database WOs'[WO Number] ),
            REMOVEFILTERS ( 'Quality Database WOs' ),
            'Quality Database WOs'[Duplicate Work Order Catch] = "OK"
        ),
        WorkOrders[WorkOrderNum]
    )
VAR _batches =
    CALCULATETABLE (
        VALUES ( WorkOrders[WorkOrderNum] ),
        WorkOrders[SOP Flag - Counts As Batch] = "Batch",
        WorkOrders[S&OP Month] >= _first,
        WorkOrders[S&OP Month] < _last
    )"""

MEASURES = [
    ('Tie-Out - Sheet Batches',
     'Batches on the sheet the business measures to today, counting rows exactly as their chart '
     'does - repeats included.',
     "CALCULATE (\n    COUNTROWS ( 'Quality Database WOs' ),\n"
     "    'Quality Database WOs'[Duplicate Work Order Catch] = \"OK\"\n)",
     '#,0', '8d17f4a2-60c3-4e95-b871-2f0946ac5e13'),
    ('Tie-Out - Sheet Work Orders',
     'Distinct work orders behind [Tie-Out - Sheet Batches]. Lower than that measure wherever '
     'their sheet counts the same batch twice.',
     "CALCULATE (\n    DISTINCTCOUNT ( 'Quality Database WOs'[WO Number] ),\n"
     "    'Quality Database WOs'[Duplicate Work Order Catch] = \"OK\"\n)",
     '#,0', 'b409c7e5-1d82-4a36-9f04-7ce5183bd260'),
    ('Tie-Out - Double Counted',
     'Rows their chart counts more than once for the same work order.',
     '[Tie-Out - Sheet Batches] - [Tie-Out - Sheet Work Orders]',
     '#,0', 'f52e83b0-46a1-4d79-8c35-90b71ea4c6df'),
    ('Tie-Out - Sheet Rows',
     'Every row on their sheet, including the ones their own duplicate filter excludes. The '
     'denominator for the breakdown by tie-out status.',
     "COUNTROWS ( 'Quality Database WOs' )",
     '#,0', 'a3e19f57-2c84-4d06-b715-8f0e63a2c94d'),
    ('Tie-Out - EDW Batches',
     'Batches by the S&OP definition, over the months their sheet covers, so both sides are '
     'measured across the same ground. The last month their sheet holds is excluded: it is '
     'still being filled in, and counting it would report the whole month as dropped.',
     SETS + '\nRETURN\n    COUNTROWS ( _batches )',
     '#,0', '31ca908d-7e64-42fb-b158-e0d29473af05'),
    ('Tie-Out - Matched',
     'Work orders both sides count.',
     SETS + '\nRETURN\n    COUNTROWS ( INTERSECT ( _batches, _sheet ) )',
     '#,0', '6be0147c-a935-48d2-9071-c384f5e2b09a'),
    ('Tie-Out - Dropped By Old Process',
     'Batches the S&OP definition counts that their sheet never picked up.',
     SETS + '\nRETURN\n    COUNTROWS ( EXCEPT ( _batches, _sheet ) )',
     '#,0', 'e7d3260f-8b51-4c9a-a642-1f709853db4e'),
    ('Tie-Out - Only On Their Sheet',
     'Rows on their sheet with no matching batch in EDW, whether because the work order is not '
     'a batch or because it is counted in a different month.',
     "CALCULATE (\n    DISTINCTCOUNT ( 'Quality Database WOs'[WO Number] ),\n"
     "    'Quality Database WOs'[Tie-Out Status] IN {\n"
     '        "Work order not in EDW",\n        "In EDW but not an S&OP batch",\n'
     '        "Counted in a different month"\n    }\n)',
     '#,0', '9a4f5c18-3072-4be6-85d3-c60184fa27b9'),
    ('Tie-Out - Drop Reason',
     'Why the old process missed this batch, in plain language. Blank for anything that is '
     'not a dropped batch, which is what prunes the detail grid to exactly those rows. '
     'Replaces the calculated column of the same purpose, which could not exist without '
     'making WorkOrders and the sheet table depend on each other.',
     REASON,
     None, '4f8b02e6-71d9-4a35-9c08-2e61b3f7a04d'),
    ('Tie-Out - Agreement %',
     'Share of the work orders their sheet counts that the S&OP definition also counts, in the '
     'same month.',
     'DIVIDE ( [Tie-Out - Matched], [Tie-Out - Sheet Work Orders] )',
     '0.0%;-0.0%;0.0%', 'd8106b73-5e29-4f14-a970-3b52c8de10a6'),
]


def measures():
    p = os.path.join(TABLES, '.Measures.tmdl')
    txt = read(p)
    missing = [m for m in MEASURES if ("measure '%s'" % m[0]) not in txt]
    if not missing:
        note(True, 'tie-out measures (%d)' % len(MEASURES))
        return
    note(False, 'tie-out measures (%d of %d)' % (len(missing), len(MEASURES)))
    L = []
    for name, desc, expr, fmt, lt in missing:
        L.append((0, ''))
        L.append((1, '/// ' + desc))
        L.append((1, "measure '%s' =" % name))
        for line in expr.split('\n'):
            L.append((3, line) if line.strip() else (0, ''))
        L.append((2, 'formatString: %s' % fmt))
        L.append((2, 'displayFolder: RTFT\\Tie-Out'))
        L.append((2, 'lineageTag: %s' % lt))
    write(p, txt.rstrip('\r\n') + '\r\n' + tabs(L) + '\r\n')


# --------------------------------------------------------------- 4. model + relationships
def model_and_relationships():
    p = os.path.join(DEF, 'model.tmdl')
    txt = read(p)
    changed = False
    for t in ("'SOP Excluded Items'", "'Quality Database WOs'"):
        if ('ref table %s' % t) not in txt:
            changed = True
            note(False, 'model.tmdl ref table %s' % t)
            txt = txt.replace("ref table 'SOP Work Centres'\r\n",
                              "ref table 'SOP Work Centres'\r\nref table %s\r\n" % t)
        else:
            note(True, 'model.tmdl ref table %s' % t)
    if '"Quality Database WOs"' not in txt:
        changed = True
        txt = txt.replace('"WorkOrderRouting"]', '"WorkOrderRouting","Quality Database WOs"]')
    if changed:
        write(p, txt)

    p = os.path.join(DEF, 'relationships.tmdl')
    txt = read(p)
    if '8f5c2e19-3a04-4d76-b1e8-72c0964df531' in txt:
        note(True, 'relationship sheet -> WorkOrders')
        return
    note(False, 'relationship sheet -> WorkOrders (single direction)')
    # No comment may precede a relationship: TMDL rejects '///' with "Property 'description'
    # is unknown" and '//' with an indentation error. See CLAUDE.md section 7.
    #
    # NOT bidirectional, and this is load-bearing. A bidirectional edge here makes the two
    # tables depend on each other at table granularity, which re-creates the circular
    # dependency even with zero WorkOrders -> sheet column references. Verified 2026-08-07:
    # with 'crossFilteringBehavior: bothDirections' Desktop refuses to open the PBIP.
    L = [(0, ''),
         (0, 'relationship 8f5c2e19-3a04-4d76-b1e8-72c0964df531'),
         (1, "fromColumn: 'Quality Database WOs'.'WO Number'"),
         (1, 'toColumn: WorkOrders.WorkOrderNum')]
    write(p, txt.rstrip('\r\n') + '\r\n' + tabs(L) + '\r\n')


# --------------------------------------------------------------- 5. the sheet extract table
def quality_database_table():
    p = os.path.join(TABLES, 'Quality Database WOs.tmdl')
    if os.path.exists(p):
        note(True, "table 'Quality Database WOs'")
        return
    note(False, "table 'Quality Database WOs'")
    if CHECK:
        return
    import subprocess
    gen = os.path.join(HERE, 'gen_quality_database_table.py')
    subprocess.check_call([sys.executable, gen])


for fn in (excluded_items_table, quality_database_table, workorders, measures,
           model_and_relationships):
    fn()

print('CHECK ONLY - nothing written\n' if CHECK else 'APPLIED\n')
print('\n'.join(report))
