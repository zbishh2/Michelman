"""Emits the report 22 paginated report.

The RDL is the deliverable; this script is how it is maintained. Six tabs — Receipts,
Shipments, Forecast, Work Orders, BOM, Item Details — each a Rectangle carrying a PageName so
the Excel export lands on a named sheet. The datasets are the PBIP's queries read verbatim
from the `<Table>.m` files beside this script (DAX against SSASPROD/BIQLTabular, T-SQL against
EDWPROD/EDW for BOM and for the TM Assignment lookup); each tablix groups the line-grain rows
on the displayed attributes and sums the `(Line)` columns, which is what the PBIP table visuals
do. Forecast's TM Name is a `Lookup` into the TM Assignment dataset on Customer Code - the same
thing the PBIP does with its LOOKUPVALUE column.

Styling follows reports 14, 19 and 21: Cognos-look 7pt cells, bold red headers, 1pt black
cell borders.
"""

import pathlib
import re
from xml.sax.saxutils import escape

HERE = pathlib.Path(__file__).parent
OUT = HERE / "22 - CM - Information 2020 - Future (RDL)" / "CM - Information 2020 - Future.rdl"

NS = "http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition"

RED = "#ff0000"
BLACK = "#000000"
GREY = "#666666"
DARK = "#333333"
MID = "#595959"
CELL = "7pt"

# ---------------------------------------------------------------------------
# Queries — lifted from the shipped .m files so the RDL and the PBIP run the same text
# ---------------------------------------------------------------------------

def m_query(name):
    text = (HERE / ("%s.m" % name)).read_text(encoding="utf-8")
    m = re.search(r'Query = "((?:[^"]|"")*)"', text, re.S)
    if m:
        return m.group(1).replace('""', '"').strip("\n")
    m = re.search(r'Value\.NativeQuery\(\s*Source,\s*"((?:[^"]|"")*)"', text, re.S)
    return m.group(1).replace('""', '"').strip("\n")


DAX_REFRESH = """EVALUATE
ROW (
    "LastRefreshed",
    CALCULATE ( MAX ( Audit[DateUpdated] ) )
)"""

# ---------------------------------------------------------------------------
# Columns:  (header, dataset column, kind, width)
#   L = looked up from another dataset (LOOKUPS), not a field of the page's own dataset
#   T = text attribute, D = date attribute, N = numeric attribute, M = summed "(Line)" column
# ---------------------------------------------------------------------------

T, D, N, M, L = "T", "D", "N", "M", "L"

# looked-up column -> (key field on this dataset, lookup dataset, key field there, value field there)
LOOKUPS = {"TM Name": ("Customer_Code", "dsTMAssignment", "Customer_Code", "TM_Name")}

PAGES = [
    ("Receipts", "Receipts", "dsReceipts", [
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("Vendor Name", "Vendor Name", T, 1.70),
        ("Vendor ID", "Vendor ID", N, 0.65),
        ("Received Quantity", "Received Quantity", M, 0.85),
        ("Received Quantity LBs", "Received Quantity LBs", M, 0.95),
        ("Received Quantity KGs", "Received Quantity KGs", M, 0.95),
        ("Receipt Transaction Type", "Receipt Transaction Type", T, 0.75),
        ("Receipt Transaction Date", "Receipt Transaction Date", D, 0.95),
        ("Order Type", "Order Type", T, 0.55),
        ("Document Number", "Document Number", N, 0.85),
        ("Line Number", "Line Number", N, 0.60),
        ("Document Type", "Document Type", T, 0.65),
        ("Amount Received", "Amount Received", M, 0.90),
        ("Amount Received USD", "Amount Received USD", M, 0.95),
        ("Amount Received EUR", "Amount Received EUR", M, 0.95),
        ("Date", "Date", D, 0.85),
        ("Year", "Year", N, 0.50),
        ("Month", "Month", N, 0.50),
    ], ["Global Bulk Item", "Bulk Item", "2nd Item Number", "Receipt Transaction Date", "Document Number", "Line Number"]),
    ("Shipments", "Shipments", "dsShipments", [
        ("Order Company", "Order Company", T, 0.65),
        ("Branch Plant", "Branch Plant", T, 0.60),
        ("Order Number", "Order Number", T, 0.75),
        ("Line Number", "Line Number", N, 0.55),
        ("Open Indicator", "Open Indicator", T, 0.55),
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("Description 1", "Description 1", T, 1.60),
        ("Description 2", "Description 2", T, 1.20),
        ("Freight Handling Code", "Freight Handling Code", T, 0.60),
        ("Next Status", "Next Status", T, 0.55),
        ("Order Net Amount USD", "Order Net Amount USD", M, 0.95),
        ("Order Net Amount EUR", "Order Net Amount EUR", M, 0.95),
        ("Ordered Quantity LBs", "Ordered Quantity LBs", M, 0.95),
        ("Ordered Quantity KGs", "Ordered Quantity KGs", M, 0.95),
        ("Revenue Business Unit", "Revenue Business Unit", T, 0.75),
        ("TM Name", "TM Name", T, 1.30),
        ("Customer Name", "Customer Name", T, 1.90),
        ("Country Name", "Country Name", T, 1.00),
        ("Global Parent Name", "Global Parent Name", T, 1.90),
        ("Date", "Date", D, 0.85),
        ("Year", "Year", N, 0.50),
        ("Month", "Month", N, 0.50),
        ("Chemist Name", "Chemist Name", T, 1.20),
    ], ["Global Bulk Item", "Bulk Item", "2nd Item Number", "Date", "Order Number", "Line Number"]),
    ("Forecast", "Forecast", "dsForecast", [
        ("Company Code", "Company Code", T, 0.65),
        ("Branch Plant", "Branch Plant", T, 0.60),
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("Item Description 1", "Item Description 1", T, 1.60),
        ("Item Description 2", "Item Description 2", T, 1.20),
        ("Requested Date", "Requested Date", D, 0.90),
        ("TM Name", "TM Name", L, 1.30),
        ("Current Forecast", "Current Forecast", M, 0.85),
        ("Primary UOM", "Primary UOM", T, 0.55),
        ("Current Forecast LB", "Current Forecast LB", M, 0.90),
        ("Current Forecast KG", "Current Forecast KG", M, 0.90),
        ("Date", "Date", D, 0.85),
        ("Year", "Year", N, 0.50),
        ("Month", "Month", N, 0.50),
        ("Customer Code", "Customer Code", N, 0.75),
        ("Customer Name", "Customer Name", T, 1.90),
        ("Global Parent Name", "Global Parent Name", T, 1.90),
        ("Chemist Name", "Chemist Name", T, 1.20),
    ], ["Global Bulk Item", "Bulk Item", "2nd Item Number", "Branch Plant", "Requested Date", "Customer Code"]),
    ("Work Orders", "WorkOrders", "dsWorkOrders", [
        ("Branch Plant", "Branch Plant", T, 0.60),
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("WO Number", "WO Number", N, 0.75),
        ("Start Date", "Start Date", D, 0.85),
        ("Completion Date", "Completion Date", D, 0.90),
        ("Year", "Year", N, 0.50),
        ("Month", "Month", N, 0.50),
        ("WO Status", "WO Status", T, 0.55),
        ("Branch Plant", "Component Branch Plant", T, 0.60),
        ("Component 2nd Item Number", "Component 2nd Item Number", T, 1.00),
        ("Component UOM", "Component UOM", T, 0.60),
        ("Issued Quantity", "Issued Quantity", M, 0.85),
        ("Quantity Ordered", "Quantity Ordered", M, 0.85),
        ("Global Bulk Item", "Component Global Bulk Item", T, 1.00),
        ("Bulk Item", "Component Bulk Item", T, 1.00),
        ("2nd Item Number", "Component Item 2nd Item Number", T, 1.00),
        ("Stock Type Code", "Stock Type Code", T, 0.60),
    ], ["Global Bulk Item", "Bulk Item", "2nd Item Number", "WO Number", "Component Branch Plant", "Component 2nd Item Number", "Component UOM"]),
    ("BOM", "BOM", "dsBOM", [
        ("Branch Plant", "Branch Plant", T, 0.60),
        ("Parent Second Item Number", "Parent Second Item Number", T, 1.10),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Quantity", "Quantity", M, 0.80),
    ], ["Branch Plant", "Parent Second Item Number", "2nd Item Number"]),
    ("Item Details", "ItemDetails", "dsItemDetails", [
        ("Branch Plant", "Branch Plant", T, 0.60),
        ("Global Bulk Item", "Global Bulk Item", T, 1.00),
        ("Bulk Item", "Bulk Item", T, 1.00),
        ("2nd Item Number", "2nd Item Number", T, 1.00),
        ("Stock Type Code", "Stock Type Code", T, 0.60),
        ("Master Planning Family", "Master Planning Family", T, 0.75),
        ("Lead Time Level", "Lead Time Level", N, 0.60),
        ("Lead Time Order to Ship", "Lead Time Order to Ship", N, 0.75),
        ("Planning Code", "Planning Code", T, 0.60),
        ("Planning Time Fence Days", "Planning Time Fence Days", N, 0.80),
        ("Safety Stock", "Safety Stock", N, 0.70),
        ("Shelf Life Days", "Shelf Life Days", N, 0.65),
        ("Supplier Number", "Supplier Number", N, 0.70),
        ("Supplier Name", "Supplier Name", T, 1.70),
        ("Planner Number", "Planner Number", N, 0.70),
        ("Planner Name", "Planner Name", T, 1.30),
        ("Buyer Number", "Buyer Number", N, 0.65),
        ("Buyer Name", "Buyer Name", T, 1.30),
    ], ["Global Bulk Item", "Bulk Item", "2nd Item Number", "Branch Plant"]),
]

M_SOURCES = {"Receipts": "Receipts", "Shipments": "Shipments", "Forecast": "Forecast",
             "WorkOrders": "Work Orders", "BOM": "BOM", "ItemDetails": "Item Details"}

CLR = {T: "System.String", D: "System.DateTime", N: "System.Double", M: "System.Double"}


def field_name(col):
    """RDL field names: letters/digits/underscore, not starting with a digit."""
    f = re.sub(r"[^A-Za-z0-9]+", "_", col).strip("_")
    if f[0].isdigit():
        head, _, rest = f.partition("_")
        f = "%s_%s" % (rest, head) if rest else "F_" + f
    return f


def dataset_column(col, kind):
    return "%s (Line)" % col if kind == M else col


# ---------------------------------------------------------------------------
# XML helpers
# ---------------------------------------------------------------------------

def ind(text, n):
    pad = " " * n
    return "\n".join(pad + line if line else line for line in text.split("\n"))


def cell_style(bg=None):
    parts = ["<Style>",
             "  <Border>",
             "    <Color>%s</Color>" % BLACK,
             "    <Style>Solid</Style>",
             "  </Border>"]
    if bg:
        parts.append("  <BackgroundColor>%s</BackgroundColor>" % bg)
    parts += ["  <VerticalAlign>Middle</VerticalAlign>",
              "  <PaddingLeft>2pt</PaddingLeft>",
              "  <PaddingRight>2pt</PaddingRight>",
              "  <PaddingTop>2pt</PaddingTop>",
              "  <PaddingBottom>2pt</PaddingBottom>",
              "</Style>"]
    return "\n".join(parts)


def textbox(name, value, *, size=CELL, bold=False, color=BLACK, fmt=None,
            align="Left", bg=None, bordered=True, padding=True):
    run = ["<TextRun>",
           "  <Value>%s</Value>" % escape(value),
           "  <Style>",
           "    <FontSize>%s</FontSize>" % size]
    if bold:
        run.append("    <FontWeight>Bold</FontWeight>")
    if fmt:
        run.append("    <Format>%s</Format>" % escape(fmt))
    run += ["    <Color>%s</Color>" % color,
            "  </Style>",
            "</TextRun>"]

    if bordered:
        style = cell_style(bg)
    else:
        style = "\n".join(["<Style>",
                           "  <Border>",
                           "    <Style>None</Style>",
                           "  </Border>"] +
                          (["  <PaddingLeft>2pt</PaddingLeft>",
                            "  <PaddingRight>2pt</PaddingRight>",
                            "  <PaddingTop>2pt</PaddingTop>",
                            "  <PaddingBottom>2pt</PaddingBottom>"] if padding else []) +
                          ["</Style>"])

    return "\n".join([
        '<Textbox Name="%s">' % name,
        "  <CanGrow>true</CanGrow>",
        "  <KeepTogether>true</KeepTogether>",
        "  <Paragraphs>",
        "    <Paragraph>",
        "      <TextRuns>",
        ind("\n".join(run), 8),
        "      </TextRuns>",
        "      <Style>",
        "        <TextAlign>%s</TextAlign>" % align,
        "      </Style>",
        "    </Paragraph>",
        "  </Paragraphs>",
        ind(style, 2),
        "</Textbox>",
    ])


def floating_textbox(name, value, *, top, left=None, width, height, zindex,
                     size, color, align="Left"):
    box = textbox(name, value, size=size, color=color, align=align, bordered=False)
    extra = ["  <Top>%s</Top>" % top]
    if left is not None:
        extra.append("  <Left>%s</Left>" % left)
    extra += ["  <Height>%s</Height>" % height,
              "  <Width>%s</Width>" % width,
              "  <ZIndex>%d</ZIndex>" % zindex]
    lines = box.split("\n")
    cut = next(i for i, l in enumerate(lines) if l == "  <Style>")
    return "\n".join(lines[:cut] + extra + lines[cut:])


# ---------------------------------------------------------------------------
# Grouped tablix: one row per distinct attribute tuple, "(Line)" columns summed
# ---------------------------------------------------------------------------

FMT = {M: "#,0", D: "MMM d, yyyy", N: None, T: None, L: None}


def grouped_tablix(prefix, cols, dataset, sort_cols, top, width):
    columns = "\n".join("<TablixColumn>\n  <Width>%.2fin</Width>\n</TablixColumn>" % w
                        for *_, w in cols)

    header_cells, detail_cells = [], []
    for i, (header, col, kind, _w) in enumerate(cols, start=1):
        hb = textbox("%s_Header_%d" % (prefix, i), header,
                     bold=True, color=RED, align="Left", bg="#ffffff")
        header_cells.append("<TablixCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCell>"
                            % ind(hb, 4))
        if kind == L:
            key, ds, lkey, lval = LOOKUPS[col]
            value = '=Lookup(Fields!%s.Value, Fields!%s.Value, Fields!%s.Value, "%s")' % (key, lkey, lval, ds)
        else:
            f = field_name(dataset_column(col, kind))
            value = "=Sum(Fields!%s.Value)" % f if kind == M else "=Fields!%s.Value" % f
        align = "Right" if kind in (M, N) else "Left"
        db = textbox("%s_Detail_%d" % (prefix, i), value, fmt=FMT[kind], align=align)
        detail_cells.append("<TablixCell>\n  <CellContents>\n%s\n  </CellContents>\n</TablixCell>"
                            % ind(db, 4))

    rows = "\n".join([
        "<TablixRow>",
        "  <Height>0.38in</Height>",
        "  <TablixCells>",
        ind("\n".join(header_cells), 4),
        "  </TablixCells>",
        "</TablixRow>",
        "<TablixRow>",
        "  <Height>0.24in</Height>",
        "  <TablixCells>",
        ind("\n".join(detail_cells), 4),
        "  </TablixCells>",
        "</TablixRow>",
    ])

    col_members = "\n".join("<TablixMember />" for _ in cols)

    group_exprs = "\n".join("<GroupExpression>=Fields!%s.Value</GroupExpression>" % field_name(col)
                            for _h, col, kind, _w in cols if kind not in (M, L))
    sort_exprs = "\n".join("\n".join([
        "<SortExpression>",
        "  <Value>=Fields!%s.Value</Value>" % field_name(c),
        "</SortExpression>"]) for c in sort_cols)

    return "\n".join([
        '<Tablix Name="%s_Table">' % prefix,
        "  <TablixBody>",
        "    <TablixColumns>",
        ind(columns, 6),
        "    </TablixColumns>",
        "    <TablixRows>",
        ind(rows, 6),
        "    </TablixRows>",
        "  </TablixBody>",
        "  <TablixColumnHierarchy>",
        "    <TablixMembers>",
        ind(col_members, 6),
        "    </TablixMembers>",
        "  </TablixColumnHierarchy>",
        "  <TablixRowHierarchy>",
        "    <TablixMembers>",
        "      <TablixMember>",
        "        <KeepWithGroup>After</KeepWithGroup>",
        "        <RepeatOnNewPage>true</RepeatOnNewPage>",
        "        <KeepTogether>true</KeepTogether>",
        "      </TablixMember>",
        "      <TablixMember>",
        '        <Group Name="%s_Rows">' % prefix,
        "          <GroupExpressions>",
        ind(group_exprs, 12),
        "          </GroupExpressions>",
        "        </Group>",
        "        <SortExpressions>",
        ind(sort_exprs, 10),
        "        </SortExpressions>",
        "      </TablixMember>",
        "    </TablixMembers>",
        "  </TablixRowHierarchy>",
        "  <NoRowsMessage>No Data Available</NoRowsMessage>",
        "  <DataSetName>%s</DataSetName>" % dataset,
        "  <Top>%s</Top>" % top,
        "  <Height>0.62in</Height>",
        "  <Width>%.2fin</Width>" % width,
        "  <ZIndex>3</ZIndex>",
        "  <Style>",
        "    <Border>",
        "      <Style>None</Style>",
        "    </Border>",
        "  </Style>",
        "</Tablix>",
    ])


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------

def section(name, title, tablix, *, page_name, top, height, page_break, dataset,
            body_width, stamp, stamp_left, zindex):
    items = [
        floating_textbox("%s_Title" % name, title, top="0in", width="10in",
                         height="0.35in", zindex=0, size="14pt", color=DARK),
        floating_textbox("%s_Context" % name,
                         '="Rows: " & Format(CountDistinct(%s, "%s"), "#,0")' % (
                             " & \"|\" & ".join("Fields!%s.Value" % f for f in stamp["keys"]), dataset),
                         top="0.36in", width="12in", height="0.24in", zindex=1, size="9pt", color=MID),
        floating_textbox("%s_Refresh" % name, stamp["text"],
                         top="0.03in", left="%.2fin" % stamp_left, width="4.35in",
                         height="0.25in", zindex=2, size="8pt", color=GREY, align="Right"),
        tablix,
    ]

    parts = ['<Rectangle Name="%s">' % name,
             "  <ReportItems>",
             ind("\n".join(items), 4),
             "  </ReportItems>"]
    if page_break:
        parts += ["  <PageBreak>",
                  "    <BreakLocation>Start</BreakLocation>",
                  "  </PageBreak>"]
    parts += ["  <PageName>%s</PageName>" % escape(page_name),
              "  <Top>%s</Top>" % top,
              "  <Height>%s</Height>" % height,
              "  <Width>%.2fin</Width>" % body_width,
              "  <ZIndex>%d</ZIndex>" % zindex,
              "  <Style>",
              "    <Border>",
              "      <Style>None</Style>",
              "    </Border>",
              "  </Style>",
              "</Rectangle>"]
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Datasets
# ---------------------------------------------------------------------------

COMMANDS = []


def dataset(name, source, command, fields):
    """Query text is stashed and re-inserted after indentation, so the DAX and T-SQL
    keep the indentation they were written with."""
    COMMANDS.append(escape(command))
    token = "@@COMMAND%d@@" % (len(COMMANDS) - 1)

    field_xml = "\n".join(
        "\n".join([
            '<Field Name="%s">' % f,
            "  <rd:TypeName>%s</rd:TypeName>" % t,
            "  <DataField>%s</DataField>" % escape(d),
            "</Field>",
        ]) for f, d, t in fields)

    return "\n".join([
        '<DataSet Name="%s">' % name,
        "  <Query>",
        "    <DataSourceName>%s</DataSourceName>" % source,
        "    <CommandText>%s</CommandText>" % token,
        "  </Query>",
        "  <Fields>",
        ind(field_xml, 4),
        "  </Fields>",
        "</DataSet>",
    ])


def page_fields(cols, dax):
    """DAX result columns arrive bracketed ([Name]); the EDW T-SQL columns do not."""
    seen, out = set(), []
    for _h, col, kind, _w in cols:
        if kind == L:
            continue
        dc = dataset_column(col, kind)
        if dc in seen:
            continue
        seen.add(dc)
        out.append((field_name(dc), "[%s]" % dc if dax else dc, CLR[kind]))
    return out


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def build():
    datasources = "\n".join([
        '<DataSource Name="SSASPROD_BIQLTabular">',
        "  <rd:SecurityType>Integrated</rd:SecurityType>",
        "  <ConnectionProperties>",
        "    <DataProvider>OLEDB-MD</DataProvider>",
        "    <ConnectString>Data Source=SSASPROD;Initial Catalog=BIQLTabular</ConnectString>",
        "    <IntegratedSecurity>true</IntegratedSecurity>",
        "  </ConnectionProperties>",
        "  <rd:DataSourceID>22000000-0000-4000-8000-000000000001</rd:DataSourceID>",
        "</DataSource>",
        '<DataSource Name="EDWPROD_EDW">',
        "  <rd:SecurityType>Integrated</rd:SecurityType>",
        "  <ConnectionProperties>",
        "    <DataProvider>SQL</DataProvider>",
        "    <ConnectString>Data Source=EDWPROD;Initial Catalog=EDW</ConnectString>",
        "    <IntegratedSecurity>true</IntegratedSecurity>",
        "  </ConnectionProperties>",
        "  <rd:DataSourceID>22000000-0000-4000-8000-000000000002</rd:DataSourceID>",
        "</DataSource>",
    ])

    ds_parts, sections, widths = [], [], {}
    top = 0.0
    for i, (page_name, key, ds_name, cols, sort_cols) in enumerate(PAGES):
        is_sql = key == "BOM"
        source = "EDWPROD_EDW" if is_sql else "SSASPROD_BIQLTabular"
        ds_parts.append(dataset(ds_name, source, m_query(M_SOURCES[key]), page_fields(cols, dax=not is_sql)))
        width = sum(w for *_, w in cols)
        widths[page_name] = width
        group_fields = [field_name(c) for _h, c, k, _w in cols if k not in (M, L)]
        stamp = {
            "keys": group_fields,
            "text": ('="Query run: " & Format(Globals!ExecutionTime, "MMM d, yyyy h:mm:ss tt")' if is_sql else
                     '="Cube last loaded: " & Format(First(Fields!LastRefreshed.Value, "dsRefresh"), "MMM d, yyyy h:mm:ss tt")'),
        }
        sections.append(section(
            "%sSection" % key, page_name,
            grouped_tablix("%sSection" % key, cols, ds_name, sort_cols, "0.68in", width),
            page_name=page_name, top="%.2fin" % top, height="1.30in", page_break=i > 0,
            dataset=ds_name, body_width=max(sum(w for *_, w in c) for *_, c, _s in PAGES),
            stamp=stamp, stamp_left=max(width - 4.35, 0), zindex=i))
        top += 1.40

    ds_parts.append(dataset("dsRefresh", "SSASPROD_BIQLTabular", DAX_REFRESH,
                            [("LastRefreshed", "[LastRefreshed]", "System.DateTime")]))
    ds_parts.append(dataset("dsTMAssignment", "EDWPROD_EDW", m_query("TM Assignment"),
                            [("Customer_Code", "Customer Code", "System.Int32"),
                             ("TM_Name", "TM Name", "System.String"),
                             ("TM_Role", "TM Role", "System.String")]))
    body_width = max(widths.values())

    footer = "\n".join([
        "<PageFooter>",
        "  <Height>0.22in</Height>",
        "  <PrintOnFirstPage>true</PrintOnFirstPage>",
        "  <PrintOnLastPage>true</PrintOnLastPage>",
        "  <ReportItems>",
        ind(floating_textbox("ExecutionTime", "=Globals!ExecutionTime", top="0.02in",
                             left="%.2fin" % (body_width - 3.0), width="2.75in", height="0.2in", zindex=0,
                             size="8pt", color=GREY, align="Right"), 4),
        "  </ReportItems>",
        "  <Style>",
        "    <Border>",
        "      <Style>None</Style>",
        "    </Border>",
        "  </Style>",
        "</PageFooter>",
    ])

    report = "\n".join([
        '<?xml version="1.0" encoding="utf-8"?>',
        '<Report MustUnderstand="df" xmlns="%s" '
        'xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner" '
        'xmlns:df="%s/defaultfontfamily" '
        'xmlns:am="http://schemas.microsoft.com/sqlserver/reporting/authoringmetadata">'
        % (NS, NS),
        "  <rd:ReportUnitType>Inch</rd:ReportUnitType>",
        "  <rd:ReportID>22000000-0000-4000-8000-000000000022</rd:ReportID>",
        "  <df:DefaultFontFamily>Segoe UI</df:DefaultFontFamily>",
        "  <AutoRefresh>0</AutoRefresh>",
        "  <DataSources>",
        ind(datasources, 4),
        "  </DataSources>",
        "  <DataSets>",
        ind("\n".join(ds_parts), 4),
        "  </DataSets>",
        "  <ReportSections>",
        "    <ReportSection>",
        "      <Body>",
        "        <ReportItems>",
        ind("\n".join(sections), 10),
        "        </ReportItems>",
        "        <Height>%.2fin</Height>" % top,
        "        <Style>",
        "          <Border>",
        "            <Style>None</Style>",
        "          </Border>",
        "        </Style>",
        "      </Body>",
        "      <Width>%.2fin</Width>" % body_width,
        "      <Page>",
        ind(footer, 8),
        "        <PageWidth>%.2fin</PageWidth>" % (body_width + 0.5),
        "        <LeftMargin>0.25in</LeftMargin>",
        "        <RightMargin>0.25in</RightMargin>",
        "        <TopMargin>0.25in</TopMargin>",
        "        <BottomMargin>0.25in</BottomMargin>",
        "        <Style />",
        "      </Page>",
        "    </ReportSection>",
        "  </ReportSections>",
        "  <ConsumeContainerWhitespace>true</ConsumeContainerWhitespace>",
        "</Report>",
    ])

    for i, command in enumerate(COMMANDS):
        report = report.replace("@@COMMAND%d@@" % i, command)

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(report, encoding="utf-8-sig")
    print("wrote %s (%d lines)" % (OUT, report.count("\n") + 1))
    print("widths: " + " | ".join("%s %.2fin" % kv for kv in widths.items()))


if __name__ == "__main__":
    build()
