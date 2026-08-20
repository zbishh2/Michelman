"""Builds the ISH cost-measure tie-out diagnostic.

Runs in Report Builder against the live cube and answers, in one render, whether
[Total Ext Cost IC USD] reproduces the column-read projection once Selected UOM
and Selected Currency are pinned.
"""

import html
from pathlib import Path

OUT = Path(__file__).with_name("ISH cost measure tie-out.rdl")

FILTER = """        TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07"
            && 'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0
            && TRIM ( RELATED ( 'Branch'[Branch Plant] ) ) IN { "CINC", "CIN2", "CIN4", "AUBA", "AUB2", "SING", "SNG4", "MUM3", "SHAN" }
            && TRIM ( RELATED ( 'Item Branch'[Master Planning Family] ) )
                IN { "ATP", "ETP", "FBW", "FCB", "FEC", "FRC", "RAW",
                    "RBW", "RCB", "REC", "RRC", "RWW", "TOL", "WAG" }"""

MEMBERS = """EVALUATE
UNION (
    SELECTCOLUMNS ( 'Selected UOM Filter',
        "Selector", "UOM",
        "Code", FORMAT ( 'Selected UOM Filter'[Selected UOM Code], "0" ),
        "Label", 'Selected UOM Filter'[Selected UOM Filter],
        "IsDefault", FORMAT ( 'Selected UOM Filter'[DefaultUOM], "0" ) ),
    SELECTCOLUMNS ( 'Selected Currency Filter',
        "Selector", "Currency",
        "Code", FORMAT ( 'Selected Currency Filter'[Selected Currency Code], "0" ),
        "Label", 'Selected Currency Filter'[Selected Currency Filter],
        "IsDefault", FORMAT ( 'Selected Currency Filter'[DefaultCurrency], "0" ) )
)
ORDER BY [Selector], [Code]"""

TOTALS = """DEFINE
    VAR Rows_ =
        FILTER (
            'Inventory Snapshot',
            'Inventory Snapshot'[Calendar Date] = DATE ( 2026, 8, 5 )
""" + FILTER + """
        )
    VAR OursUSD =
        SUMX ( Rows_,
            'Inventory Snapshot'[AmountValueAtCost]
                * LOOKUPVALUE ( 'Currency Rates'[ToRateDaily],
                    'Currency Rates'[CurrencySKey], 'Inventory Snapshot'[CurrencyASKey] ) )
    VAR OursEUR =
        SUMX ( Rows_,
            'Inventory Snapshot'[AmountValueAtCost]
                * LOOKUPVALUE ( 'Currency Rates'[ToRateDaily],
                    'Currency Rates'[CurrencySKey], 'Inventory Snapshot'[CurrencyBSKey] ) )
    VAR UomPrimary =
        FILTER ( ALL ( 'Selected UOM Filter' ),
            CONTAINSSTRING ( 'Selected UOM Filter'[Selected UOM Filter], "Primary" ) )
    VAR CurUSD =
        FILTER ( ALL ( 'Selected Currency Filter' ),
            CONTAINSSTRING ( 'Selected Currency Filter'[Selected Currency Filter], "USD" ) )
    VAR CurEUR =
        FILTER ( ALL ( 'Selected Currency Filter' ),
            CONTAINSSTRING ( 'Selected Currency Filter'[Selected Currency Filter], "EUR" ) )
    VAR Base = CALCULATETABLE ( Rows_ )
EVALUATE
UNION (
    ROW ( "Scenario", "1. Ours - AmountValueAtCost x rate (USD)", "Value", OursUSD ),
    ROW ( "Scenario", "2. Ours - AmountValueAtCost x rate (EUR)", "Value", OursEUR ),
    ROW ( "Scenario", "3. Cube [Total Ext Cost IC USD] - nothing pinned",
        "Value", CALCULATE ( [Total Ext Cost IC USD], Base ) ),
    ROW ( "Scenario", "4. Cube [Total Ext Cost IC USD] - UOM = Primary",
        "Value", CALCULATE ( [Total Ext Cost IC USD], Base, UomPrimary ) ),
    ROW ( "Scenario", "5. Cube [Total Ext Cost IC USD] - UOM = Primary, Currency = USD",
        "Value", CALCULATE ( [Total Ext Cost IC USD], Base, UomPrimary, CurUSD ) ),
    ROW ( "Scenario", "6. Cube [Total Ext Cost IC] - UOM = Primary, Currency = EUR",
        "Value", CALCULATE ( [Total Ext Cost IC], Base, UomPrimary, CurEUR ) ),
    ROW ( "Scenario", "7. Cube [Total Ext Cost IC] - UOM = Primary, Currency = USD",
        "Value", CALCULATE ( [Total Ext Cost IC], Base, UomPrimary, CurUSD ) )
)"""

BYBRANCH = """DEFINE
    VAR UomPrimary =
        FILTER ( ALL ( 'Selected UOM Filter' ),
            CONTAINSSTRING ( 'Selected UOM Filter'[Selected UOM Filter], "Primary" ) )
    VAR CurUSD =
        FILTER ( ALL ( 'Selected Currency Filter' ),
            CONTAINSSTRING ( 'Selected Currency Filter'[Selected Currency Filter], "USD" ) )
    VAR Lines =
        SELECTCOLUMNS (
            FILTER (
                'Inventory Snapshot',
                'Inventory Snapshot'[Calendar Date] = DATE ( 2026, 8, 5 )
""" + FILTER + """
            ),
            "Branch Plant", TRIM ( RELATED ( 'Branch'[Branch Plant] ) ),
            "Line",
                'Inventory Snapshot'[AmountValueAtCost]
                    * LOOKUPVALUE ( 'Currency Rates'[ToRateDaily],
                        'Currency Rates'[CurrencySKey], 'Inventory Snapshot'[CurrencyASKey] )
        )
EVALUATE
ADDCOLUMNS (
    GROUPBY ( Lines, [Branch Plant], "Ours", SUMX ( CURRENTGROUP (), [Line] ) ),
    "Cube",
        CALCULATE (
            [Total Ext Cost IC USD],
            'Inventory Snapshot'[Calendar Date] = DATE ( 2026, 8, 5 ),
            TRIM ( 'Inventory Snapshot'[CostMethod] ) = "07",
            'Inventory Snapshot'[QuantityOnHandPrimaryUOM] > 0,
            UomPrimary,
            CurUSD
        )
)
ORDER BY [Branch Plant]"""

DATASETS = [
    ("dsMembers", MEMBERS, ["Selector", "Code", "Label", "IsDefault"]),
    ("dsTotals", TOTALS, ["Scenario", "Value"]),
    ("dsByBranch", BYBRANCH, [("Branch_Plant", "Branch Plant"), "Ours", "Cube"]),
]


def esc(t):
    return html.escape(t, quote=False)


def field(spec):
    name, src = spec if isinstance(spec, tuple) else (spec, spec)
    return ('      <Field Name="%s">\n'
            "        <DataField>[%s]</DataField>\n"
            "        <rd:TypeName>System.String</rd:TypeName>\n"
            "      </Field>" % (name, src))


def dataset(name, command, fields):
    return "\n".join([
        '    <DataSet Name="%s">' % name,
        "      <Query>",
        "        <DataSourceName>DataSource1</DataSourceName>",
        "        <CommandText>%s</CommandText>" % esc(command),
        "        <rd:Aggregates />",
        "      </Query>",
        "      <Fields>",
        "\n".join(field(f) for f in fields),
        "      </Fields>",
        "    </DataSet>",
    ])


def textbox(name, value, *, bold=False, fmt=None, size=None):
    style = ["            <Style>"]
    if bold:
        style.append("              <FontWeight>Bold</FontWeight>")
    if size:
        style.append("              <FontSize>%s</FontSize>" % size)
    if fmt:
        style.append("              <Format>%s</Format>" % fmt)
    style += ["              <PaddingLeft>2pt</PaddingLeft>",
              "              <PaddingRight>2pt</PaddingRight>",
              "            </Style>"]
    return "\n".join([
        '          <Textbox Name="%s">' % name,
        "            <CanGrow>true</CanGrow>",
        "            <KeepTogether>true</KeepTogether>",
        "            <Paragraphs><Paragraph><TextRuns><TextRun>",
        "              <Value>%s</Value>" % esc(value),
        "            </TextRun></TextRuns></Paragraph></Paragraphs>",
        "\n".join(style),
        "          </Textbox>",
    ])


def row(height, cells):
    return ("        <TablixRow><Height>%s</Height><TablixCells>" % height
            + "".join("<TablixCell><CellContents>\n%s\n</CellContents></TablixCell>" % c
                      for c in cells)
            + "</TablixCells></TablixRow>")


def tablix(name, ds_name, cols, top):
    widths = "\n".join("          <TablixColumn><Width>%s</Width></TablixColumn>" % w
                       for _, _, w, _ in cols)
    header = row("0.22in", [textbox("%s_h%d" % (name, i), '="%s"' % label, bold=True)
                            for i, (label, _, _, _) in enumerate(cols)])
    detail = row("0.20in", [textbox("%s_d%d" % (name, i), expr, fmt=fmt)
                            for i, (_, expr, _, fmt) in enumerate(cols)])
    return "\n".join([
        '        <Tablix Name="%s">' % name,
        "          <TablixBody>",
        "          <TablixColumns>", widths, "          </TablixColumns>",
        "          <TablixRows>", header, detail, "          </TablixRows>",
        "          </TablixBody>",
        "          <TablixColumnHierarchy><TablixMembers>"
        + "".join("<TablixMember />" for _ in cols)
        + "</TablixMembers></TablixColumnHierarchy>",
        "          <TablixRowHierarchy><TablixMembers>",
        "            <TablixMember><KeepWithGroup>After</KeepWithGroup></TablixMember>",
        '            <TablixMember><Group Name="%s_Detail" />'
        "<TablixMembers><TablixMember /></TablixMembers></TablixMember>" % name,
        "          </TablixMembers></TablixRowHierarchy>",
        "          <DataSetName>%s</DataSetName>" % ds_name,
        "          <Top>%s</Top><Left>0in</Left>" % top,
        "          <Style><Border><Style>None</Style></Border></Style>",
        "        </Tablix>",
    ])


def heading(name, text, top):
    return "\n".join([
        '        <Textbox Name="%s">' % name,
        "          <CanGrow>true</CanGrow>",
        "          <Paragraphs><Paragraph><TextRuns><TextRun>",
        "            <Value>%s</Value>" % esc(text),
        "            <Style><FontWeight>Bold</FontWeight><FontSize>11pt</FontSize></Style>",
        "          </TextRun></TextRuns></Paragraph></Paragraphs>",
        "          <Top>%s</Top><Left>0in</Left><Height>0.25in</Height><Width>7in</Width>" % top,
        "          <Style />",
        "        </Textbox>",
    ])


body = "\n".join([
    heading("h1", "Selector members", "0in"),
    tablix("tbMembers", "dsMembers",
           [("Selector", "=Fields!Selector.Value", "1.0in", None),
            ("Code", "=Fields!Code.Value", "0.7in", None),
            ("Label", "=Fields!Label.Value", "2.6in", None),
            ("Default", "=Fields!IsDefault.Value", "0.8in", None)], "0.30in"),
    heading("h2", "Totals - 5 Aug 2026, report 14 filter set", "2.60in"),
    tablix("tbTotals", "dsTotals",
           [("Scenario", "=Fields!Scenario.Value", "4.6in", None),
            ("Value", "=CDbl(Fields!Value.Value)", "1.8in", "#,0.00")], "2.90in"),
    heading("h3", "By branch plant - UOM = Primary, Currency = USD", "5.20in"),
    tablix("tbBranch", "dsByBranch",
           [("Branch Plant", "=Fields!Branch_Plant.Value", "1.2in", None),
            ("Ours", "=CDbl(Fields!Ours.Value)", "1.6in", "#,0.00"),
            ("Cube", "=CDbl(Fields!Cube.Value)", "1.6in", "#,0.00"),
            ("Difference", "=CDbl(Fields!Ours.Value) - CDbl(Fields!Cube.Value)",
             "1.6in", "#,0.00")], "5.50in"),
])

rdl = "\n".join([
    '<?xml version="1.0" encoding="utf-8"?>',
    '<Report xmlns="http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition"'
    ' xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner">',
    "  <AutoRefresh>0</AutoRefresh>",
    "  <DataSources>",
    '    <DataSource Name="DataSource1">',
    "      <ConnectionProperties>",
    "        <DataProvider>OLEDB-MD</DataProvider>",
    "        <ConnectString>Data Source=SSASPROD;Initial Catalog=BIQLTabular_ISH</ConnectString>",
    "        <IntegratedSecurity>true</IntegratedSecurity>",
    "      </ConnectionProperties>",
    "      <rd:SecurityType>Integrated</rd:SecurityType>",
    "    </DataSource>",
    "  </DataSources>",
    "  <DataSets>",
    "\n".join(dataset(n, c, f) for n, c, f in DATASETS),
    "  </DataSets>",
    "  <ReportSections><ReportSection>",
    "    <Body>",
    "      <ReportItems>",
    body,
    "      </ReportItems>",
    "      <Height>8.0in</Height>",
    "      <Style />",
    "    </Body>",
    "    <Width>7.5in</Width>",
    "    <Page>",
    "      <PageHeight>11in</PageHeight><PageWidth>8.5in</PageWidth>",
    "      <LeftMargin>1in</LeftMargin><RightMargin>1in</RightMargin>",
    "      <TopMargin>1in</TopMargin><BottomMargin>1in</BottomMargin>",
    "      <Style />",
    "    </Page>",
    "  </ReportSection></ReportSections>",
    "</Report>",
])

OUT.write_text(rdl, encoding="utf-8")
print("wrote", OUT, len(rdl.splitlines()), "lines")
