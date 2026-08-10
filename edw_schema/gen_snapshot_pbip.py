# gen_snapshot_pbip.py - generate the EDW/ODS Snapshot probe PBIP.
#
# WHY A GENERATOR: Power BI will not infer a table's schema from its partition
# expression ("Columns are required. The schema cannot be automatically inferred"),
# so every one of ~2,500 columns has to be declared in TMDL. Hand-writing that is
# not viable; this emits it from edw_schema/03_columns.csv, which is the real
# INFORMATION_SCHEMA dump taken from EDWPROD.
#
# Output is a PBIP whose skeleton mirrors Cognos Reports/12 .../PROBE - authored by
# Desktop 2.146, i.e. the JUMPBOX's version, so the schema versions are ones it can
# open (see CLAUDE.md 7, the bookmark 2.1.0 incident).
#
# TMDL is TAB-indented with CRLF line endings. Both matter; space indentation
# silently misparses.
#
# ---------------------------------------------------------------------------------
# STAGED, NOT YET APPLIED (2026-08-05): every source query gained WITH (NOLOCK) -
# see the note above ODS_TABLES. The PBIPs on disk and their ~1 GB cache.abf files
# were generated BEFORE it. Regenerating changes all 91 partition expressions, and
# Power BI invalidates a partition whose expression changes AS TEXT, so the next
# open will want to reload everything. Do it when a full refresh is happening
# anyway, not on its own.
# ---------------------------------------------------------------------------------

import csv, io, os, shutil, sys, uuid

REPO = os.path.dirname(os.path.abspath(__file__))
# Column metadata. edw_columns_current.csv / ods_columns_current.csv were exported
# from the 2026-08-05 snapshot's own _EDW Columns / _ODS Columns tables, so they are
# current INFORMATION_SCHEMA rather than the 2026-06-03 dump in 03_columns.csv - which
# predates BIQL.TbBranch, TbTerritoryManager and FactForecast_v2 and is why earlier
# passes reported them "missing". 03_columns.csv stays as a fallback only.
COLS_CSV = os.path.join(REPO, "edw_columns_current.csv")
if not os.path.exists(COLS_CSV):
    COLS_CSV = os.path.join(REPO, "03_columns.csv")
# Known-good report shell, authored by Desktop 2.146 (the jumpbox's version).
# report.json is COPIED from here rather than hand-written: themeCollection and its
# matching StaticResources theme file are both REQUIRED, and omitting them fails the
# open with "Required properties are missing from object: themeCollection".
TEMPLATE_REPORT = os.path.join(
    os.path.dirname(REPO), "Cognos Reports",
    "12 - Americas - Open Purchase Orders", "PROBE", "R12 Probe.Report")
OUT_ROOT = r"C:\Users\Zack\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects"
NAME = "EDW-ODS Snapshot"

# Namespace for deterministic lineage tags: regenerating must not churn the file.
NS = uuid.UUID("6f1d2c33-9a4b-4e21-8f70-5c2ab7d9e401")

# ---------------------------------------------------------------- table list
# EDW only. Every one is small - the largest is FactInventorySnapshot_History at
# 2.03M rows and FactSalesDetail entire is 979k - so nothing here is windowed.
# Deliberate: a date cutoff on this data buys nothing and has already manufactured
# a false finding once (the 13,853 "orphan" FactScheduleChange rows, 2026-08-04).
EDW_TABLES = [
    ("dbo",  "FactSalesDetail"),
    ("dbo",  "DimWorkOrder"),
    ("dbo",  "DimItem"),
    ("dbo",  "DimItemBranch"),
    ("dbo",  "DimCustomer"),
    ("dbo",  "DimAddress"),
    ("dbo",  "DimLot"),
    ("dbo",  "FactInventorySnapshot_History"),
    ("BIQL", "TbItemBranch"),
    ("BIQL", "TbSF_Case"),
    ("BIQL", "TbWorkOrderDetail"),
    ("BIQL", "TbCompany"),
    ("BIQL", "DimItem"),
    ("BIQL", "DimAddress"),
    ("BIQL", "DimLot"),
    ("BIQL", "DimCompany"),
    ("BIQL", "DimCurrencyExchangeRatesUSDDaily"),
    ("BIQL", "DimItemUOMConversionLBKG"),
    ("BIQL", "FactForecast"),
    ("BIQL", "DimCalendarInventorySnapshot"),

    # --- added 2026-08-05 for the final consolidated pull. Everything here is
    # referenced by a .m / .sql / .tmdl file somewhere in the repo (measured, not
    # guessed), and every one was previously undeclarable because the 2026-06-03
    # dump did not contain it.
    ("BIQL", "TbBranch"),               # BranchSKey -> TbBranch -> TbCompany, the RTFB Region chain
    ("BIQL", "TbTerritoryManager"),
    ("BIQL", "TbAddress"),
    ("BIQL", "FactForecast_v2"),
    ("BIQL", "TbDate"),
    ("BIQL", "TbLot"),
    ("BIQL", "DimCustomer"),            # BIQL twin of dbo.DimCustomer; enrichment columns live here (CLAUDE.md 4)
    ("BIQL", "TbCalendarSnapshot"),
    ("BIQL", "TbRevenueBusinessUnit"),
    ("BIQL", "SF_DimCase"),
    ("BIQL", "FactInventorySnapshot"),
    ("BIQL", "FactInventorySnapshot_History_Filtered"),
    ("dbo",  "DimUDC"),                 # UDC decodes on the EDW side; PRODCTL.F0005 is the JDE side
    ("dbo",  "DimItemCost_History"),

    # --- added 2026-08-06: WORK ORDER ROUTING. The gap the snapshot could not
    # cover. Two questions both need routing and neither could be answered
    # locally without it:
    #   (a) "run machine actual hours > 0" as a batch filter. It is NOT on the
    #       work order header — dbo.DimWorkOrder[HoursActual] is 0.0000 on all
    #       44,308 rows in the snapshot, and PRODDTA.F4801[WAHRSA] is 0 on all
    #       237,106 rows in ODS. Both measured 2026-08-06. RunMachineActual on
    #       this view is the real field.
    #   (b) the ~1,300 work order gap against the client's Global Completion
    #       Report. Its scope is a curated list of 66 production work centres and
    #       the work centre only exists in routing.
    # Grain is (work order x operation sequence x work centre), so ~3-5 rows per
    # work order — expect a few million. Aggregate before joining anything to it.
    # _Time is the sibling view; it carries the same RunMachineActual column but
    # looks like hours-transaction grain (Type Of Hours / Shift Code / GL Date).
    # Both are pulled so the difference can be settled by measurement rather than
    # by reading column names, which is what forced this trip in the first place.
    ("BIQL", "TbWorkOrderRouting_Routing"),
    ("BIQL", "TbWorkOrderRouting_Time"),

    # BUSINESS UNIT — the dimension that actually carries the bulk-production
    # work-centre flag, and the piece that was missing. ssasprod.bim scopes its
    # production measures with
    #     'Business Unit'[Bulk Production Work Center] = "BAT"
    #     'Business Unit'[Business Unit Type]          = "WC"
    # joined from 'Work Order Routing'[BusinessUnitSKey].
    # ⚠ NOT TbBranch. BIQL.TbBranch carries an identically-named column and it is
    # BLANK for CINC / CIN2 / SING / AUBA (measured 2026-08-06) — because a branch
    # is a plant, not a work centre. Checking TbBranch and concluding "the flag is
    # not populated" is the wrong-table trap; the flag lives on the WC-type
    # business units.
    ("BIQL", "TbBusinessUnit"),
    ("dbo",  "DimBusinessUnit"),
    # Currency: five objects because the reports reach for different ones and we
    # have never established which is authoritative. All are small.
    ("BIQL", "DimCurrencyExchangeRates"),
    ("BIQL", "TbCurrencyRates"),
    ("BIQL", "CurrencyRatesTo"),
    ("BIQL", "DimCurrencyRatesToCXA"),
    ("BIQL", "DimCurrencyCrossRatesCalc"),
]

# ------------------------------------------------------------------ ODS tables
# Column lists come from ods_columns_current.csv - the _ODS Columns table exported
# out of the mounted snapshot. There is no PRODDTA schema dump in this repo and JDE
# tables run to 268 columns, so this is the only way to declare them without
# inventing names. ODS mirrors 172 objects; the list below is the subset we take.
#
# WINDOWS: two. F42199 is 19,539,040 rows and F43121 is 724,632 with 163 columns.
# SLUPMJ/PRUPMJ >= 123001 is julian for 2023-01-01, chosen one year wider than the
# production FactScheduleChange.m (124001 / 2024-01-01) so the 2023-based Cognos
# reports stay reproducible. Everything else comes whole.
#
# Raw on purpose: no SLDCTO NOT IN ('CM','CO') exclusion, no reason-episode logic.
# Those are business rules this copy exists to TEST, not to inherit.
ODS_COLS_CSV = os.path.join(REPO, "ods_columns_current.csv")
ODS_PACKED = os.path.join(REPO, "ods_columns_packed.csv")   # fallback: the older packed form
ODS_WHERE = {
    "F42199": "WHERE SLUPMJ >= 123001",
    "F43121": "WHERE PRUPMJ >= 123001",
}

# Explicit, because ods_columns_current.csv describes all 172 mirrored objects and
# emitting them all would pull ~90M rows (F0902 alone is 30M).
ODS_TABLES = [
    ("PRODCTL", "F0005"),                                   # UDC decodes
    # --- original 25 ---
    ("PRODDTA", "F0006"), ("PRODDTA", "F0010"), ("PRODDTA", "F0101"),
    ("PRODDTA", "F0111"), ("PRODDTA", "F0116"), ("PRODDTA", "F3002"),
    ("PRODDTA", "F3111"), ("PRODDTA", "F3111_ARCH"), ("PRODDTA", "F41002"),
    ("PRODDTA", "F4101"), ("PRODDTA", "F4102"), ("PRODDTA", "F41021"),
    ("PRODDTA", "F4201"), ("PRODDTA", "F4201_ARCH"), ("PRODDTA", "F4211"),
    ("PRODDTA", "F4211_ARCH"), ("PRODDTA", "F42119"), ("PRODDTA", "F42119_ARCH"),
    ("PRODDTA", "F42140"), ("PRODDTA", "F42199"), ("PRODDTA", "F4311"),
    ("PRODDTA", "F4311_ARCH"), ("PRODDTA", "F4801"), ("PRODDTA", "F4801_ARCH"),
    ("PRODDTA", "F554101"),

    # --- added 2026-08-05, the final consolidated pull ---
    ("PRODDTA", "F03012"),      # 22,226   customer master
    ("PRODDTA", "F0015"),       # 71,639   currency exchange rates
    ("PRODDTA", "F0150"),       # 4,458    address organisation structure
    ("PRODDTA", "F3003"),       # 111,050  routing master
    ("PRODDTA", "F30026"),      # 2,164,377 item cost components
    ("PRODDTA", "F3312"),       # 66,760   MPS/MRP message
    ("PRODDTA", "F3313"),       # 39,658
    ("PRODDTA", "F41003"),      # 59       UOM standard conversion
    ("PRODDTA", "F4105"),       # 2,042,461 item cost ledger
    ("PRODDTA", "F4108"),       # 570,981  lot master
    ("PRODDTA", "F4301"),       # 131,843  purchase order header
    ("PRODDTA", "F4301_ARCH"),  # 74,990
    ("PRODDTA", "F43121"),      # 724,632  PO receiver ledger - WINDOWED, 163 columns
    # The T_ family is Michelman's product/MSDS system, not stock JDE. Wide free
    # text, so it compresses poorly - but the one true size bomb in it is
    # T_PDF_MSDS.F_PDF, 157,168 actual PDF blobs, which the binary skip below drops.
    ("PRODDTA", "T_COMP_DATA"),     # 519,628
    ("PRODDTA", "T_PDF_MSDS"),      # 157,168  (metadata only once F_PDF is dropped)
    ("PRODDTA", "T_PROD_COMP"),     # 335,996
    ("PRODDTA", "T_PROD_DATA"),     # 485,856
    ("PRODDTA", "T_PROD_TEXT"),     # 1,049,374
    ("PRODDTA", "T_PRODUCTS"),      # 18,681
    ("PRODDTA", "T_TEXT_DETAILS"),  # 825,748

    # --- added 2026-08-06: the JDE side of work order routing, so the EDW views
    # above can be checked against source rather than trusted.
    # We already had F3111 and mistook it for routing — it is the work order
    # PARTS LIST (WM prefix, components issued, no hours at all). F3003 is the
    # routing MASTER (standards by item, not per work order). Neither answers a
    # per-work-order actual-hours question. These two do:
    ("PRODDTA", "F3112"),       # work order ROUTING: WLDOCO / WLOPSQ / WLMMCU
                                # (work centre!) / WLRUNM / WLRUNL. WLMMCU is the
                                # column the Global Completion Report's 66-work-centre
                                # scope is built on.
    ("PRODDTA", "F31122"),      # work order TIME TRANSACTIONS: WTDOCO / WTOPSQ /
                                # WTMMCU. The likely true source of "Actual Machine
                                # Hours" — F4801's header WAHRSA is 0 everywhere.
]

# NOT taken, so the reasoning survives the next time someone asks "why isn't X here":
#   F3460      4,631,827 - redundant. BIQL.FactForecast IS the enriched view over it
#                          (identical row count; F3460's 22 JDE columns appear there
#                          alongside the SKeys). Verified 2026-08-05.
#   F0902     30,012,654 - GL balances. No reference anywhere in the repo.
#   F0911     19,310,987 - GL detail. Same.
#   F41112 /  7,763,429 - item ledger (Cardex) and its as-of twin. Genuinely useful
#   F4111     7,394,553   for "why did this lot move", but nothing in the repo reads
#   F4111_ARCH 4,580,061   them - Cognos got inventory from snapshots instead. This is
#                          the main judgement call in the list; adding all three would
#                          cost ~20M rows.
#   F3102/F43199/F3711/F4074/F5531_PRE_90/F3413/F31122/F3400/F3112 and the rest of
#   the 172 - manufacturing and AR/AP ledgers with zero references.

# WITH (NOLOCK) on every source query, EDW and ODS alike (added 2026-08-05).
# A SELECT under READ COMMITTED still takes shared locks, and a scan this size
# escalates to a table-level shared lock - which blocks WRITERS. ODS and EDW are
# replication/ETL-fed mirrors, so a multi-hour sweep across 46 ODS tables can stall
# the very load that keeps them current, and the overnight batch window is when that
# load runs. Dirty reads cost us nothing we were relying on: this snapshot is
# deliberately stale, explicitly not for tie-outs, and the README already says so.
# Preferred over "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;" because that
# makes the partition a multi-statement batch and puts query folding at risk.

# Binary columns are dropped from every ODS table. They carry no analytical value,
# they compress badly (a hash column is maximum-entropy by construction), and one of
# them - T_PDF_MSDS.F_PDF - is a varbinary of complete PDF documents. Affects exactly
# five tables (F00165, T_COMP_DATA, T_PDF_MSDS, T_PROD_COMP, T_PROD_TEXT), none of
# which were in the model before this pass, so no existing table changes shape.
SKIP_TYPES = {"varbinary", "image", "binary", "timestamp"}

# SQL type -> TMDL dataType. decimal/numeric are resolved by precision and scale in
# map_type() below, not here; the entry is the fallback when we have neither.
TYPEMAP = {
    "int": "int64", "bigint": "int64", "smallint": "int64", "tinyint": "int64",
    "bit": "boolean",
    "decimal": "double", "numeric": "double", "float": "double", "real": "double",
    "money": "double", "smallmoney": "double",
    "date": "dateTime", "datetime": "dateTime", "datetime2": "dateTime",
    "smalldatetime": "dateTime", "datetimeoffset": "dateTime", "time": "dateTime",
    "char": "string", "nchar": "string", "varchar": "string", "nvarchar": "string",
    "text": "string", "ntext": "string", "uniqueidentifier": "string", "xml": "string",
    "binary": "binary", "varbinary": "binary", "image": "binary", "timestamp": "binary",
}


def map_type(dtype, precision=None, scale=None):
    """SQL type -> TMDL dataType.

    precision/scale are accepted and deliberately IGNORED. Do not reintroduce a
    precision-aware rule here; it was tried on 2026-08-05 and does not work.

    1. DECLARING A TYPE IN TMDL DOES NOT WIN. Power Query maps SQL decimal/numeric to
       `number`, and on refresh Desktop reconciles each column to what the M actually
       delivered and REWRITES the TMDL. Measured: a generated `dataType: int64` came
       back as `dataType: double`, rewritten 4 seconds before the cache was saved.
       Changing the type for real means casting in the SQL (CAST(x AS bigint)), which
       costs every affected table its SELECT * - and is not worth it, because:

    2. THE PROBLEM IS THEORETICAL IN THIS DATA. double holds integers exactly below
       2^53 (~9.0e15). Actual maxima, measured across the snapshot:
           TbSF_Case[Unique Key ID]         numeric(19,0) -> 2,564,987
           FactSalesDetail[CustomerPOPrice] decimal(19,0) -> 6,000,000
           F41002[UMCONV]                   decimal(18,0) -> 999,999,999,999,999
           F4101[IMDFTPCT]                  decimal(20,0) -> 0
       Zero rows anywhere exceed 2^53. Declared precision says what a column COULD
       hold - it is not evidence of what it does hold, and "Unique Key ID" is a
       7-digit sequence number despite its 19-digit declaration.

    3. LEAVING THE MISMATCH IN IS ACTIVELY HARMFUL. Emitting int64 that Desktop
       rewrites to double changes the TMDL on every refresh, and a changed partition
       expression re-invalidates that table's data.
    """
    return TYPEMAP.get(dtype, "string")


def tag(*parts):
    return str(uuid.uuid5(NS, "|".join(parts)))


def tmdl_name(n):
    """TMDL quotes any identifier that is not a bare word."""
    return n if n.replace("_", "a").isalnum() else "'%s'" % n.replace("'", "''")


def load_columns(path=None):
    """INFORMATION_SCHEMA.COLUMNS dump -> {(schema, table): [(ordinal, col, type)]}.

    Positional, not by header name, so it reads both the 03_columns.csv dump and the
    _EDW/_ODS Columns exports - the first five fields are in the same order in each.
    A header row is skipped for free because ORDINAL_POSITION is not a digit there.
    """
    by = {}
    with io.open(path or COLS_CSV, encoding="utf-8-sig") as fh:
        for r in csv.reader(fh):
            if len(r) < 5:
                continue
            sch, tbl, ordinal, col, dtype = (r[0].strip(), r[1].strip(),
                                             r[2].strip(), r[3].strip(), r[4].strip().lower())
            if not ordinal.isdigit():
                continue
            # NUMERIC_PRECISION / NUMERIC_SCALE, present in the _EDW/_ODS Columns
            # exports but not in the older 03_columns.csv - absent means "unknown".
            prec = r[6].strip() if len(r) > 6 and r[6].strip().isdigit() else None
            scale = r[7].strip() if len(r) > 7 and r[7].strip().isdigit() else None
            by.setdefault((sch, tbl), []).append((int(ordinal), col, dtype, prec, scale))
    for k in by:
        by[k].sort()
    return by


def table_tmdl(sch, tbl, cols, server="EDWPROD", prefix=""):
    disp = ("%s%s %s" % (prefix, sch, tbl)).strip()
    L = ["table %s" % tmdl_name(disp),
         "\tlineageTag: %s" % tag(prefix, sch, tbl),
         ""]
    for _, col, dtype, prec, scale in cols:
        dt = map_type(dtype, prec, scale)
        L += ["\tcolumn %s" % tmdl_name(col),
              "\t\tdataType: %s" % dt,
              "\t\tlineageTag: %s" % tag(prefix, sch, tbl, col),
              # summarizeBy none everywhere: this is a raw dump, and 'sum' on an
              # identifier column corrupts any matrix built over it (CLAUDE.md 7).
              "\t\tsummarizeBy: none",
              "\t\tsourceColumn: %s" % col,
              "",
              "\t\tannotation SummarizationSetBy = Automatic",
              ""]
    query = "SELECT * FROM [%s].[%s] WITH (NOLOCK)" % (sch, tbl)
    L += ["\tpartition %s = m" % tmdl_name(disp),
          "\t\tmode: import",
          "\t\tsource =",
          "\t\t\t\tlet",
          '\t\t\t\t    Source = Sql.Database("%s", "EDW"),' % server,
          '\t\t\t\t    Data = Value.NativeQuery(Source, "%s", null, [EnableFolding=true])' % query,
          "\t\t\t\tin",
          "\t\t\t\t    Data",
          "",
          "\tannotation PBI_ResultType = Table",
          ""]
    return "\r\n".join(L)


def ods_table_tmdl(sch, tbl, cols, dropped=False):
    """A raw PRODDTA/PRODCTL table. cols = [(name, sqltype), ...] in ordinal order.

    dropped=True means SKIP_TYPES removed a column, so the SELECT has to name its
    columns explicitly - SELECT * would hand back a column the TMDL never declared.
    Tables that lost nothing keep SELECT *, which keeps their partitions unchanged.
    """
    disp = "%s %s" % (sch, tbl)
    L = ["table %s" % tmdl_name(disp),
         "\tlineageTag: %s" % tag(sch, tbl),
         ""]
    for col, dtype, prec, scale in cols:
        L += ["\tcolumn %s" % tmdl_name(col),
              "\t\tdataType: %s" % map_type(dtype, prec, scale),
              "\t\tlineageTag: %s" % tag(sch, tbl, col),
              "\t\tsummarizeBy: none",
              "\t\tsourceColumn: %s" % col,
              "",
              "\t\tannotation SummarizationSetBy = Automatic",
              ""]
    where = ODS_WHERE.get(tbl, "")
    sel = ", ".join("[%s]" % c[0] for c in cols) if dropped else "*"
    # WITH (NOLOCK) - see the note above ODS_TABLES for why.
    query = ("SELECT %s FROM [%s].[%s] WITH (NOLOCK) %s" % (sel, sch, tbl, where)).strip()
    L += ["\tpartition %s = m" % tmdl_name(disp),
          "\t\tmode: import",
          "\t\tsource =",
          "\t\t\t\tlet",
          '\t\t\t\t    Source = Sql.Database("ODSPROD", "ODS"),',
          '\t\t\t\t    Data = Value.NativeQuery(Source, "%s", null, [EnableFolding=true])' % query,
          "\t\t\t\tin",
          "\t\t\t\t    Data",
          "",
          "\tannotation PBI_ResultType = Table",
          ""]
    return "\r\n".join(L)


def load_ods_columns():
    """[(schema, table, [(col, sqltype), ...], dropped_any)] for ODS_TABLES, in order.

    Reads the same INFORMATION_SCHEMA shape as the EDW dump. Falls back to the older
    ods_columns_packed.csv only if the current export is missing.
    """
    by = {}
    if os.path.exists(ODS_COLS_CSV):
        for k, v in load_columns(ODS_COLS_CSV).items():
            by[k] = [(c, t, p, s) for _, c, t, p, s in v]
    elif os.path.exists(ODS_PACKED):
        with io.open(ODS_PACKED, encoding="utf-8-sig") as fh:
            rd = csv.reader(fh)
            next(rd, None)
            for r in rd:
                if len(r) < 3 or not r[2].strip():
                    continue
                # Packed form carries no precision/scale, so map_type falls back
                # to TYPEMAP for decimals. Current exports are preferred for this.
                cols = [(p.rsplit(":", 1)[0].strip(), p.rsplit(":", 1)[1].strip().lower(),
                         None, None)
                        for p in r[2].split("|") if ":" in p]
                if cols:
                    by[(r[0].strip(), r[1].strip())] = cols

    out, missing = [], []
    for sch, tbl in ODS_TABLES:
        cols = by.get((sch, tbl))
        if not cols:
            missing.append("%s.%s" % (sch, tbl))
            continue
        kept = [c for c in cols if c[1] not in SKIP_TYPES]
        out.append((sch, tbl, kept, len(kept) != len(cols)))
    return out, missing


def literal_table_tmdl(name, columns, rows):
    """A small M-literal table - used for SnapshotInfo."""
    L = ["table %s" % tmdl_name(name),
         "\tlineageTag: %s" % tag("lit", name),
         ""]
    for col, dt in columns:
        L += ["\tcolumn %s" % tmdl_name(col),
              "\t\tdataType: %s" % dt,
              "\t\tlineageTag: %s" % tag("lit", name, col),
              "\t\tsummarizeBy: none",
              "\t\tsourceColumn: %s" % col,
              "",
              "\t\tannotation SummarizationSetBy = Automatic",
              ""]
    # Typed #table, not the bare {"col","col"} form: an untyped literal yields `any`
    # columns, which then have to reconcile against the declared TMDL dataTypes.
    mtype = {"string": "text", "int64": "Int64.Type", "double": "number",
             "dateTime": "datetime", "boolean": "logical"}
    typedef = ", ".join("%s = %s" % (c, mtype.get(dt, "text")) for c, dt in columns)
    body = ", ".join("{%s}" % ", ".join(r) for r in rows)
    L += ["\tpartition %s = m" % tmdl_name(name),
          "\t\tmode: import",
          "\t\tsource =",
          "\t\t\t\tlet",
          "\t\t\t\t    Source = #table(type table [%s], {%s})" % (typedef, body),
          "\t\t\t\tin",
          "\t\t\t\t    Source",
          "",
          "\tannotation PBI_ResultType = Table",
          ""]
    return "\r\n".join(L)


def ods_discovery_tmdl(name, query, columns, server="ODSPROD", db="ODS"):
    """Probe tables whose schema is fixed and known (INFORMATION_SCHEMA / sys)."""
    L = ["table %s" % tmdl_name(name),
         "\tlineageTag: %s" % tag("ods", name),
         ""]
    for col, dt in columns:
        L += ["\tcolumn %s" % tmdl_name(col),
              "\t\tdataType: %s" % dt,
              "\t\tlineageTag: %s" % tag("ods", name, col),
              "\t\tsummarizeBy: none",
              "\t\tsourceColumn: %s" % col,
              "",
              "\t\tannotation SummarizationSetBy = Automatic",
              ""]
    L += ["\tpartition %s = m" % tmdl_name(name),
          "\t\tmode: import",
          "\t\tsource =",
          "\t\t\t\tlet",
          '\t\t\t\t    Source = Sql.Database("%s", "%s"),' % (server, db),
          '\t\t\t\t    Data = Value.NativeQuery(Source, "%s", null, [EnableFolding=false])' % query,
          "\t\t\t\tin",
          "\t\t\t\t    Data",
          "",
          "\tannotation PBI_ResultType = Table",
          ""]
    return "\r\n".join(L)


def main():
    by = load_columns()
    sm = os.path.join(OUT_ROOT, NAME, NAME + ".SemanticModel")
    rp = os.path.join(OUT_ROOT, NAME, NAME + ".Report")
    for d in [os.path.join(sm, "definition", "tables"),
              os.path.join(sm, "definition", "cultures"),
              os.path.join(rp, "definition", "pages", "a0b1c2d3e4f5a6b7c8d9")]:
        os.makedirs(d, exist_ok=True)

    written, missing, total_cols = [], [], 0

    for sch, tbl in EDW_TABLES:
        cols = by.get((sch, tbl))
        if not cols:
            missing.append("%s.%s" % (sch, tbl))
            continue
        disp = "%s %s" % (sch, tbl)
        path = os.path.join(sm, "definition", "tables", disp + ".tmdl")
        io.open(path, "w", encoding="utf-8", newline="").write(table_tmdl(sch, tbl, cols))
        written.append(disp)
        total_cols += len(cols)

    # --- EDWDEV twin of SF_Case. The Exec Dashboard / OTIF Complaints table reads
    # EDWDEV, not EDWPROD, so the prod copy above does NOT match what the dashboards
    # run on: prod returned 17,223 cases, dev 25,601 (measured 2026-08-05). Carrying
    # both makes that an in-model diff instead of a jumpbox trip, which is the open
    # question in the SF-feed thread (dev stopped 2026-07-08; prod has fewer rows).
    # Columns are borrowed from the PROD schema dump on the assumption the view
    # definition is the same in both. If dev diverges this one table errors and the
    # other 44 still load - _EDWDEV Columns below is what lets us correct it.
    dev = by.get(("BIQL", "TbSF_Case"))
    if dev:
        disp = "EDWDEV BIQL TbSF_Case"
        io.open(os.path.join(sm, "definition", "tables", disp + ".tmdl"), "w",
                encoding="utf-8", newline="").write(
            table_tmdl("BIQL", "TbSF_Case", dev, server="EDWDEV", prefix="EDWDEV "))
        written.append(disp)
        total_cols += len(dev)

    # --- ODS/JDE raw tables, from the column lists the first snapshot gave us.
    ods_rows, ods_missing = load_ods_columns()
    missing += ods_missing
    for sch, tbl, cols, dropped in ods_rows:
        disp = "%s %s" % (sch, tbl)
        path = os.path.join(sm, "definition", "tables", disp + ".tmdl")
        io.open(path, "w", encoding="utf-8", newline="").write(
            ods_table_tmdl(sch, tbl, cols, dropped))
        written.append(disp)
        total_cols += len(cols)

    # --- ODS discovery: fixed, known schemas. These are what let the NEXT pass
    # generate the PRODDTA tables with real column lists instead of guesses.
    ic_cols = [("TABLE_SCHEMA", "string"), ("TABLE_NAME", "string"),
               ("ORDINAL_POSITION", "int64"), ("COLUMN_NAME", "string"),
               ("DATA_TYPE", "string"), ("CHARACTER_MAXIMUM_LENGTH", "int64"),
               ("NUMERIC_PRECISION", "int64"), ("NUMERIC_SCALE", "int64"),
               ("IS_NULLABLE", "string")]
    ic_sql = ("SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, "
              "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE "
              "FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA IN ('PRODDTA','PRODCTL')")
    p = os.path.join(sm, "definition", "tables", "_ODS Columns.tmdl")
    io.open(p, "w", encoding="utf-8", newline="").write(
        ods_discovery_tmdl("_ODS Columns", ic_sql, ic_cols))
    written.append("_ODS Columns")

    rc_cols = [("TABLE_SCHEMA", "string"), ("TABLE_NAME", "string"), ("ROW_COUNT", "int64")]
    # sys.partitions beats COUNT(*) here: it is metadata, so it returns in about a
    # second across every table instead of scanning tens of millions of rows.
    rc_sql = ("SELECT s.name AS TABLE_SCHEMA, t.name AS TABLE_NAME, "
              "CAST(SUM(p.rows) AS bigint) AS ROW_COUNT "
              "FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id "
              "JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0,1) "
              "WHERE s.name IN ('PRODDTA','PRODCTL') "
              "GROUP BY s.name, t.name")
    p = os.path.join(sm, "definition", "tables", "_ODS RowCounts.tmdl")
    io.open(p, "w", encoding="utf-8", newline="").write(
        ods_discovery_tmdl("_ODS RowCounts", rc_sql, rc_cols))
    written.append("_ODS RowCounts")

    # Re-discover EDW every refresh so the generator always has current metadata.
    # This is what fixed the TbBranch / TbTerritoryManager / FactForecast_v2 gap:
    # they were referenced by report .m files but absent from the 2026-06-03 dump,
    # and the first snapshot's _EDW Columns is where their real schemas came from.
    edw_ic_sql = ("SELECT TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE, "
                  "CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, NUMERIC_SCALE, IS_NULLABLE "
                  "FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA IN ('dbo','BIQL')")
    p = os.path.join(sm, "definition", "tables", "_EDW Columns.tmdl")
    io.open(p, "w", encoding="utf-8", newline="").write(
        ods_discovery_tmdl("_EDW Columns", edw_ic_sql, ic_cols, server="EDWPROD", db="EDW"))
    written.append("_EDW Columns")

    # Same for dev, so a prod/dev schema difference is visible rather than inferred.
    p = os.path.join(sm, "definition", "tables", "_EDWDEV Columns.tmdl")
    io.open(p, "w", encoding="utf-8", newline="").write(
        ods_discovery_tmdl("_EDWDEV Columns", edw_ic_sql, ic_cols, server="EDWDEV", db="EDW"))
    written.append("_EDWDEV Columns")

    # --- SnapshotInfo: this model is deliberately stale; stamp it so no answer
    # taken from it is ever mistaken for current truth.
    p = os.path.join(sm, "definition", "tables", "SnapshotInfo.tmdl")
    io.open(p, "w", encoding="utf-8", newline="").write(
        literal_table_tmdl("SnapshotInfo",
                           [("Item", "string"), ("Value", "string")],
                           # RemoveZone first: DateTimeZone.UtcNow() is a datetimezone and
                           # DateTime.ToText takes a datetime - passing it straight through
                           # is a type error and fails the partition (hit 2026-08-05).
                           [['"Loaded (UTC)"', 'DateTime.ToText(DateTimeZone.RemoveZone(DateTimeZone.UtcNow()), "yyyy-MM-dd HH:mm")'],
                            ['"Sources"', '"EDWPROD/EDW + ODSPROD/ODS"'],
                            ['"Purpose"', '"Headless exploration snapshot - NOT a live source"']]))
    written.append("SnapshotInfo")

    # ------------------------------------------------------------ model files
    io.open(os.path.join(sm, "definition", "database.tmdl"), "w",
            encoding="utf-8", newline="").write("database\r\n\tcompatibilityLevel: 1567\r\n\r\n")

    order = ", ".join('"%s"' % t for t in written)
    refs = "\r\n".join("ref table %s" % tmdl_name(t) for t in written)
    model = ("model Model\r\n"
             "\tculture: en-US\r\n"
             "\tdefaultPowerBIDataSourceVersion: powerBI_V3\r\n"
             "\tsourceQueryCulture: en-US\r\n"
             "\tdataAccessOptions\r\n"
             "\t\tlegacyRedirects\r\n"
             "\t\treturnErrorValuesAsNull\r\n"
             "\r\n"
             "annotation PBI_QueryOrder = [%s]\r\n"
             "\r\n"
             "annotation __PBI_TimeIntelligenceEnabled = 0\r\n"
             "\r\n"
             "annotation PBI_ProTooling = [\"DevMode\"]\r\n"
             "\r\n"
             "%s\r\n"
             "\r\n"
             "ref cultureInfo en-US\r\n" % (order, refs))
    io.open(os.path.join(sm, "definition", "model.tmdl"), "w",
            encoding="utf-8", newline="").write(model)

    io.open(os.path.join(sm, "definition", "cultures", "en-US.tmdl"), "w",
            encoding="utf-8", newline="").write(
        "cultureInfo en-US\r\n\r\n\tlinguisticMetadata =\r\n"
        "\t\t\t{\r\n"
        '\t\t\t  "Version": "1.0.0",\r\n'
        '\t\t\t  "Language": "en-US"\r\n'
        "\t\t\t}\r\n"
        "\r\n\t\tcontentType: json\r\n\r\n")

    def j(path, text):
        io.open(path, "w", encoding="utf-8", newline="").write(text)

    j(os.path.join(sm, "definition.pbism"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/semanticModel/definitionProperties/1.0.0/schema.json",\n'
      '  "version": "4.0",\n  "settings": {}\n}')
    j(os.path.join(sm, ".platform"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",\n'
      '  "metadata": {\n    "type": "SemanticModel",\n    "displayName": "%s"\n  },\n'
      '  "config": {\n    "version": "2.0",\n    "logicalId": "%s"\n  }\n}' % (NAME, tag("sm", NAME)))

    # ------------------------------------------------------------ report shell
    j(os.path.join(rp, ".platform"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/gitIntegration/platformProperties/2.0.0/schema.json",\n'
      '  "metadata": {\n    "type": "Report",\n    "displayName": "%s"\n  },\n'
      '  "config": {\n    "version": "2.0",\n    "logicalId": "%s"\n  }\n}' % (NAME, tag("rp", NAME)))
    j(os.path.join(rp, "definition.pbir"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definitionProperties/1.0.0/schema.json",\n'
      '  "version": "4.0",\n  "datasetReference": {\n    "byPath": {\n      "path": "../%s.SemanticModel"\n    }\n  }\n}' % NAME)
    j(os.path.join(rp, "definition", "version.json"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/versionMetadata/1.0.0/schema.json",\n'
      '  "version": "2.0.0"\n}')
    # report.json + the theme it references, taken verbatim from the working template.
    shutil.copyfile(os.path.join(TEMPLATE_REPORT, "definition", "report.json"),
                    os.path.join(rp, "definition", "report.json"))
    src_theme = os.path.join(TEMPLATE_REPORT, "StaticResources", "SharedResources", "BaseThemes")
    dst_theme = os.path.join(rp, "StaticResources", "SharedResources", "BaseThemes")
    os.makedirs(dst_theme, exist_ok=True)
    for fn in os.listdir(src_theme):
        shutil.copyfile(os.path.join(src_theme, fn), os.path.join(dst_theme, fn))
    j(os.path.join(rp, "definition", "pages", "pages.json"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/pagesMetadata/1.0.0/schema.json",\n'
      '  "pageOrder": [\n    "a0b1c2d3e4f5a6b7c8d9"\n  ],\n  "activePageName": "a0b1c2d3e4f5a6b7c8d9"\n}')
    j(os.path.join(rp, "definition", "pages", "a0b1c2d3e4f5a6b7c8d9", "page.json"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/item/report/definition/page/2.0.0/schema.json",\n'
      '  "name": "a0b1c2d3e4f5a6b7c8d9",\n  "displayName": "Snapshot (no visuals - query headlessly)",\n'
      '  "displayOption": "FitToPage",\n  "height": 720,\n  "width": 1280\n}')

    j(os.path.join(OUT_ROOT, NAME, NAME + ".pbip"),
      '{\n  "$schema": "https://developer.microsoft.com/json-schemas/fabric/pbip/pbipProperties/1.0.0/schema.json",\n'
      '  "version": "1.0",\n  "artifacts": [\n    {\n      "report": {\n        "path": "%s.Report"\n      }\n    }\n  ],\n'
      '  "settings": {\n    "enableAutoRecovery": true\n  }\n}' % NAME)
    j(os.path.join(OUT_ROOT, NAME, ".gitignore"),
      "**/.pbi/localSettings.json\n**/.pbi/cache.abf\n")

    # Drop .tmdl files for tables no longer in the lists. The tables directory is
    # entirely generator-owned, so anything not just written is a leftover from an
    # earlier run - and a stale file that model.tmdl no longer refs is invisible
    # until it confuses the next person reading the folder.
    tdir = os.path.join(sm, "definition", "tables")
    keep = set(t + ".tmdl" for t in written)
    orphans = [f for f in os.listdir(tdir) if f.endswith(".tmdl") and f not in keep]
    for f in orphans:
        os.remove(os.path.join(tdir, f))

    print("tables written : %d" % len(written))
    print("columns emitted: %d" % total_cols)
    if orphans:
        print("stale files removed: %s" % ", ".join(orphans))
    if missing:
        print("NOT FOUND in the schema dump (skipped): %s" % ", ".join(missing))
    print("output         : %s" % os.path.join(OUT_ROOT, NAME))


if __name__ == "__main__":
    # --out <dir> writes the PBIP somewhere other than the OneDrive library. Used for
    # the hand-carry loop: generate to the Desktop, RDP the folder to the jumpbox
    # (1.3 MB without a cache.abf, so it is near-instant), refresh there, carry the
    # whole folder back. Avoids waiting on OneDrive in both directions.
    if "--out" in sys.argv:
        OUT_ROOT = sys.argv[sys.argv.index("--out") + 1]
    main()
